const { BasePlatform } = require('./base');
const path = require('path');
const fs = require('fs');
const { normalizeWhatsAppId, toWhatsAppJid } = require('../../utils/whatsapp');
const { DATA_DIR } = require('../../../runtime/paths');
const { createServiceLogger } = require('../../utils/logger');
const { fileExtensionForMimeType } = require('../voice/liveAudio');

const log = createServiceLogger('WhatsApp');

const AUTH_DIR = path.join(DATA_DIR, 'whatsapp-auth');
const SENT_MESSAGE_MEMORY = 200;

// Baileys reports this as a number, a numeric string, or a protobuf Long,
// depending on how the message reached the socket.
function messageTimestampSeconds(msg) {
  const raw = msg?.messageTimestamp;
  if (typeof raw === 'number') return raw;
  if (typeof raw === 'string') return Number(raw) || 0;
  if (typeof raw?.toNumber === 'function') return raw.toNumber();
  if (typeof raw?.low === 'number') return raw.low;
  return 0;
}

class WhatsAppPlatform extends BasePlatform {
  constructor(config = {}) {
    super('whatsapp', config);
    this.selfChatMode = config.selfChatMode === true || config.selfChatMode === 'true';
    this.supportsGroups = !this.selfChatMode;
    this.supportsMedia = true;
    this.sock = null;
    this.qrCode = null;
    this.reconnectAttempts = 0;
    this.authDir = config.authDir || AUTH_DIR;
    this.artifactStore = config.artifactStore || null;
    this.resolveAgentName = typeof config.resolveAgentName === 'function' ? config.resolveAgentName : null;
    this.userId = config.userId;
    this._manualDisconnect = false;
    this._reconnectTimer = null;
    this._sentMessageIds = new Set();
    // Until a connection reports open there is no point from which a message
    // counts as new, so replayed history stays out.
    this._connectedAt = Infinity;
  }

  _ownIds() {
    return new Set([
      this.sock?.user?.id,
      this.sock?.user?.jid,
      this.sock?.user?.lid,
    ]
      .map(normalizeWhatsAppId)
      .filter(Boolean));
  }

  _contextInfo(message = {}) {
    return message.extendedTextMessage?.contextInfo
      || message.imageMessage?.contextInfo
      || message.videoMessage?.contextInfo
      || message.documentMessage?.contextInfo
      || message.audioMessage?.contextInfo
      || message.conversation?.contextInfo
      || null;
  }

  _isGroupAddressedToBot(message = {}) {
    const ownIds = this._ownIds();
    if (ownIds.size === 0) return false;
    const contextInfo = this._contextInfo(message);
    const mentions = Array.isArray(contextInfo?.mentionedJid) ? contextInfo.mentionedJid : [];
    if (mentions.some((jid) => ownIds.has(normalizeWhatsAppId(jid)))) return true;
    if (ownIds.has(normalizeWhatsAppId(contextInfo?.participant))) return true;
    const text = message.conversation
      || message.extendedTextMessage?.text
      || message.imageMessage?.caption
      || message.videoMessage?.caption
      || '';
    return [...ownIds].some((id) => text.includes(`@${id}`));
  }

  _isSelfChat(chatId) {
    const normalized = normalizeWhatsAppId(chatId);
    if (!normalized) return false;
    return this._ownIds().has(normalized);
  }

  _rememberSentMessage(messageId) {
    if (!messageId) return;
    this._sentMessageIds.add(messageId);
    if (this._sentMessageIds.size > SENT_MESSAGE_MEMORY) {
      this._sentMessageIds.delete(this._sentMessageIds.values().next().value);
    }
  }

  // Every send records its message id here, which is what keeps this agent from
  // reading its own replies back. Self-chat mode relies on it entirely, because
  // there the user's own notes also arrive with fromMe set.
  _shouldProcessInbound(msg, upsertType) {
    if (!this._isLiveUpsert(msg, upsertType)) return false;
    if (this._sentMessageIds.has(msg?.key?.id)) return false;
    if (!this.selfChatMode) return msg?.key?.fromMe !== true;
    if (this._isSelfChat(msg?.key?.remoteJid)) return true;
    // Self-chat mode answers notes in your own chat only. Everyone else is
    // dropped here, which looks exactly like a broken connection.
    log.warn(
      'Ignored a message because self-chat mode is on and it was not sent in your own chat.'
      + ' Turn self-chat mode off to answer other contacts.',
    );
    return false;
  }

  // A note typed on the phone reaches this linked device as an 'append' upsert
  // rather than 'notify', so self-chat mode has to accept those or it answers
  // nothing at all. WhatsApp also replays existing chats as appends right after
  // linking, and working through that backlog would bury the user in replies,
  // so appends from before this connection are left alone.
  _isLiveUpsert(msg, upsertType) {
    if (upsertType === 'notify') return true;
    if (upsertType !== 'append' || !this.selfChatMode) return false;
    return messageTimestampSeconds(msg) >= this._connectedAt;
  }

  _accessContext(msg, { chatId, isGroup, sender }) {
    const senderId = normalizeWhatsAppId(sender);
    return {
      platform: 'whatsapp',
      senderId,
      chatId,
      isDirect: !isGroup,
      isShared: isGroup,
      groupId: isGroup ? chatId : '',
      phoneNumber: senderId,
      wasMentioned: isGroup && this._isGroupAddressedToBot(msg.message || {}),
    };
  }

  _checkMessageAccess(msg, { chatId, isGroup, sender, pushName }) {
    // Self-chat mode only ever reaches this point for notes the account owner
    // wrote in their own chat, so the allowlist has nothing left to decide.
    if (this.selfChatMode) return { allowed: true };

    const context = this._accessContext(msg, { chatId, isGroup, sender });
    return this._checkInboundAccess(context, {
      senderName: pushName || context.senderId,
      meta: isGroup ? `Group: ${chatId}` : '',
      groupLabel: chatId,
    });
  }

  // A reaction is feedback on an earlier message, not a request: it is recorded
  // for context and never starts a run. Access is checked quietly, since a
  // stranger's reaction is no reason to suggest allowlisting them.
  _emitReaction(msg, { chatId, sender, pushName }) {
    const reaction = msg.message.reactionMessage;
    const emoji = String(reaction.text || '').trim();
    // Empty text means the reaction was removed.
    if (!emoji || !reaction.key?.id) return;
    if (!this.selfChatMode && !this.evaluateAccess(this._accessContext(msg, { chatId, isGroup: false, sender })).allowed) {
      return;
    }
    this.emit('reaction', {
      platform: 'whatsapp',
      chatId,
      sender,
      senderName: pushName,
      targetMessageId: reaction.key.id,
      emoji,
      timestamp: msg.messageTimestamp ? new Date(msg.messageTimestamp * 1000).toISOString() : new Date().toISOString(),
    });
  }

  async connect() {
    this._manualDisconnect = false;
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = null;
    }
    // Two live sockets on one set of credentials make WhatsApp replace the
    // first, and both then reconnect forever while inbound messages land on
    // whichever socket is currently winning.
    if (this.sock) {
      log.warn('Closing the previous WhatsApp socket before connecting again.');
      this._discardSocket();
    }
    if (!fs.existsSync(this.authDir)) fs.mkdirSync(this.authDir, { recursive: true });

    const {
      default: makeWASocket,
      useMultiFileAuthState,
      DisconnectReason,
      makeCacheableSignalKeyStore,
      fetchLatestBaileysVersion,
      Browsers
    } = require('baileys');
    const pino = require('pino');

    let logger;
    try {
      logger = pino({ level: 'silent' });
    } catch {
      logger = { level: 'silent', info: () => { }, error: () => { }, warn: () => { }, debug: () => { }, trace: () => { }, child: () => logger };
    }

    const { version, isLatest } = await fetchLatestBaileysVersion();
    log.info(`Using WA version ${version.join('.')}, isLatest: ${isLatest}`);

    const { state, saveCreds } = await useMultiFileAuthState(this.authDir);

    this._logger = logger;

    this.sock = makeWASocket({
      version,
      auth: {
        creds: state.creds,
        keys: makeCacheableSignalKeyStore(state.keys, logger)
      },
      logger,
      browser: Browsers.appropriate('Chrome'),
      connectTimeoutMs: 60000,
      defaultQueryTimeoutMs: 60000,
      markOnlineOnConnect: false,
      generateHighQualityLinkPreview: false,
      syncFullHistory: false,
      fireInitQueries: false
    });

    this.sock.ev.on('creds.update', saveCreds);

    this.sock.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        if (this.status !== 'awaiting_qr') {
          log.warn('Waiting for a QR scan; WhatsApp is not linked and will not receive messages.');
        }
        this.qrCode = qr;
        this.status = 'awaiting_qr';
        this.emit('qr', qr);
      }

      if (connection === 'close') {
        const statusCode = lastDisconnect?.error?.output?.statusCode;
        const shouldReconnect = !this._manualDisconnect && statusCode !== DisconnectReason.loggedOut;
        const reasonName = Object.keys(DisconnectReason)
          .find((name) => DisconnectReason[name] === statusCode) || 'unknown';
        log.warn(
          `Connection closed (${reasonName}, status ${statusCode ?? 'none'}).`
          + ` ${this._manualDisconnect ? 'Stopped on request.' : shouldReconnect ? 'Reconnecting.' : 'Not reconnecting.'}`
          + (reasonName === 'connectionReplaced'
            ? ' Another WhatsApp Web session took this one over.'
            : ''),
        );

        this.status = 'disconnected';
        this.emit('disconnected', {
          statusCode,
          shouldReconnect,
          willReconnect: shouldReconnect,
          manual: this._manualDisconnect,
          requiresUserAction: false,
          reason: shouldReconnect ? 'connection_lost' : null,
        });

        if (shouldReconnect) {
          this._scheduleReconnect();
        } else if (statusCode === DisconnectReason.loggedOut) {
          fs.rmSync(this.authDir, { recursive: true, force: true });
          this.emit('logged_out');
        }
      }

      if (connection === 'open') {
        log.info('Connection open; inbound messages will be processed.');
        this._connectedAt = Math.floor(Date.now() / 1000);
        this.status = 'connected';
        this.qrCode = null;
        this.reconnectAttempts = 0;
        this.emit('connected');
      }
    });

    this.sock.ev.on('messages.upsert', async ({ messages, type }) => {
      for (const msg of messages) {
        if (!this._shouldProcessInbound(msg, type)) continue;

        const chatId = msg.key.remoteJid;
        const isGroup = chatId?.endsWith('@g.us');
        const sender = isGroup ? msg.key.participant : chatId;
        const pushName = msg.pushName || '';
        const wasMentioned = isGroup && this._isGroupAddressedToBot(msg.message || {});

        if (msg.message?.reactionMessage) {
          if (!isGroup) this._emitReaction(msg, { chatId, sender, pushName });
          continue;
        }

        let content = '';
        let mediaType = null;
        let voiceNote = null;
        const documentMimeType = String(msg.message?.documentMessage?.mimetype || '');

        if (msg.message?.conversation) {
          content = msg.message.conversation;
        } else if (msg.message?.extendedTextMessage?.text) {
          content = msg.message.extendedTextMessage.text;
        } else if (msg.message?.imageMessage) {
          content = msg.message.imageMessage.caption || '[Image]';
          mediaType = 'image';
        } else if (msg.message?.videoMessage) {
          content = msg.message.videoMessage.caption || '[Video]';
          mediaType = 'video';
        } else if (msg.message?.audioMessage) {
          const audio = msg.message.audioMessage;
          mediaType = 'audio';
          voiceNote = {
            source: audio.ptt ? 'whatsapp_ptt' : 'whatsapp_audio',
            durationSec: Number(audio.seconds) || null,
            forwarded: audio.contextInfo?.isForwarded === true,
          };
        } else if (documentMimeType.startsWith('audio/')) {
          content = msg.message.documentMessage.caption || '';
          mediaType = 'audio';
          voiceNote = { source: 'whatsapp_audio', durationSec: null };
        } else if (msg.message?.documentMessage) {
          content = msg.message.documentMessage.fileName || '[Document]';
          mediaType = 'document';
        } else if (msg.message?.stickerMessage) {
          content = '[Sticker]';
          mediaType = 'sticker';
        }

        if (!content && !mediaType) {
          const kinds = Object.keys(msg.message || {}).join(', ') || 'empty payload';
          log.warn(`Ignored a message with no readable content (${kinds}).`);
          continue;
        }

        const access = this._checkMessageAccess(msg, {
          chatId,
          isGroup,
          sender,
          pushName,
        });

        if (!access.allowed) continue;

        let localMediaPath = null;
        if (mediaType && mediaType !== 'sticker') {
          try {
            const { downloadMediaMessage } = require('baileys');
            const buffer = await downloadMediaMessage(msg, 'buffer', {}, {
              logger: this._logger,
              reuploadRequest: this.sock.updateMediaMessage
            });
            const extMap = { image: 'jpg', video: 'mp4', document: 'bin' };
            const audioMimeType = mediaType === 'audio'
              ? String(msg.message.audioMessage?.mimetype || documentMimeType || 'audio/ogg').split(';')[0]
              : null;
            const ext = audioMimeType ? fileExtensionForMimeType(audioMimeType) : (extMap[mediaType] || 'bin');
            const safeId = (msg.key.id || 'file').replace(/[^a-zA-Z0-9]/g, '');
            if (!this.artifactStore || !this.userId) {
              throw new Error('Per-user artifact storage is unavailable.');
            }
            const artifact = await this.artifactStore.createBufferArtifact(this.userId, {
              kind: 'messaging-inbound-media',
              filenameBase: `${Date.now()}_${safeId}`,
              extension: ext,
              contentType: audioMimeType || {
                image: 'image/jpeg',
                video: 'video/mp4',
              }[mediaType] || 'application/octet-stream',
              content: buffer,
              metadata: {
                platform: 'whatsapp',
                mediaType,
                messageId: msg.key.id || null,
              },
            });
            localMediaPath = artifact.filePath;
          } catch (dlErr) {
            log.error('Media download failed:', dlErr.message);
          }
        }

        try {
          await this.sock.readMessages([msg.key]);
        } catch { /* non-fatal */ }

        log.info(
          `Accepted ${isGroup ? 'group' : 'direct'} message`
          + `${mediaType ? ` (${mediaType})` : ''} for processing.`,
        );
        this.emit('message', {
          platform: 'whatsapp',
          chatId,
          sender,
          senderName: pushName,
          senderDisplayName: pushName || null,
          senderTag: normalizeWhatsAppId(sender) || sender,
          wasMentioned,
          repliedToAgent: Boolean(
            msg.message?.extendedTextMessage?.contextInfo?.stanzaId
            && msg.message?.extendedTextMessage?.contextInfo?.participant
            && this._ownIds().has(normalizeWhatsAppId(
              msg.message.extendedTextMessage.contextInfo.participant
            ))
          ),
          replyToMessageId: msg.message?.extendedTextMessage?.contextInfo?.stanzaId || null,
          groupId: isGroup ? chatId : null,
          content,
          mediaType,
          localMediaPath,
          voiceNote: localMediaPath ? voiceNote : null,
          isGroup,
          messageId: msg.key.id,
          metadata: this.selfChatMode ? { selfChat: true } : null,
          timestamp: msg.messageTimestamp ? new Date(msg.messageTimestamp * 1000).toISOString() : new Date().toISOString(),
          rawMessage: msg
        });
      }
    });

    return { status: this.status };
  }

  _discardSocket() {
    const previous = this.sock;
    this.sock = null;
    if (!previous) return;
    try {
      previous.ev?.removeAllListeners?.('connection.update');
      previous.ev?.removeAllListeners?.('messages.upsert');
      previous.ev?.removeAllListeners?.('creds.update');
      previous.end();
    } catch {
      // The socket is being thrown away either way.
    }
  }

  _scheduleReconnect() {
    if (this._manualDisconnect || this._reconnectTimer) return;
    this.reconnectAttempts++;
    const delay = Math.min(1000 * (2 ** Math.min(this.reconnectAttempts, 10)), 60000);
    log.info(`Reconnecting in ${Math.round(delay / 1000)}s (attempt ${this.reconnectAttempts}).`);
    this._reconnectTimer = setTimeout(() => {
      this._reconnectTimer = null;
      if (this._manualDisconnect) return;
      this.connect().catch((err) => {
        log.error('Reconnect failed:', err.message);
        this._scheduleReconnect();
      });
    }, delay);
    this._reconnectTimer.unref?.();
  }

  async disconnect() {
    this._manualDisconnect = true;
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = null;
    }
    this._discardSocket();
    this.status = 'disconnected';
    this.emit('disconnected', { manual: true });
  }

  // In the self chat both sides are the same account, so replies carry the agent
  // name to keep them apart from the user's own notes.
  _withAgentLabel(content) {
    const text = String(content || '').trim();
    if (!this.selfChatMode || !text) return content;
    const name = String(this.resolveAgentName?.() || '').trim();
    return name ? `(${name}): ${text}` : content;
  }

  _outboundPayload(content, options) {
    const body = this._withAgentLabel(content);
    if (!options.mediaPath) return { text: body };

    const media = fs.readFileSync(options.mediaPath);
    const ext = path.extname(options.mediaPath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext)) {
      return { image: media, caption: body || undefined };
    }
    if (['.mp4', '.avi', '.mov'].includes(ext)) {
      return { video: media, caption: body || undefined };
    }
    if (['.mp3', '.ogg', '.m4a'].includes(ext)) {
      return { audio: media, mimetype: 'audio/mp4' };
    }
    return {
      document: media,
      fileName: path.basename(options.mediaPath),
      caption: body || undefined
    };
  }

  async sendMessage(to, content, options = {}) {
    if (!this.sock || this.status !== 'connected') {
      throw new Error('WhatsApp not connected');
    }

    const jid = toWhatsAppJid(to);
    if (!jid) throw new Error('Invalid WhatsApp recipient');

    const sent = await this.sock.sendMessage(jid, this._outboundPayload(content, options));
    this._rememberSentMessage(sent?.key?.id);
    return { success: true, messageId: sent?.key?.id || null };
  }

  async sendReaction(chatId, messageId, emoji) {
    if (!this.sock || this.status !== 'connected') {
      throw new Error('WhatsApp not connected');
    }
    const jid = toWhatsAppJid(chatId);
    if (!jid) throw new Error('Invalid WhatsApp chat');
    const sent = await this.sock.sendMessage(jid, {
      react: { text: emoji, key: { remoteJid: jid, id: messageId, fromMe: false } },
    });
    // Self-chat echoes our own reaction back; remembering it keeps it from
    // being read as the user's reaction.
    this._rememberSentMessage(sent?.key?.id);
    return { success: true };
  }

  async markRead(chatId, messageId) {
    if (!this.sock || typeof this.sock.readMessages !== 'function' || !messageId) return;
    const jid = toWhatsAppJid(chatId);
    if (!jid) return;
    await this.sock.readMessages([{ remoteJid: jid, id: messageId, fromMe: false }]).catch(() => { });
  }

  async sendTyping(chatId, isTyping) {
    if (!this.sock || this.status !== 'connected') return;
    const jid = toWhatsAppJid(chatId);
    if (!jid) return;
    await this.sock.sendPresenceUpdate(isTyping ? 'composing' : 'paused', jid).catch(() => { });
  }

  async getContacts() {
    if (!this.sock) return [];
    try {
      const contacts = await this.sock.store?.contacts || {};
      return Object.entries(contacts).map(([id, contact]) => ({
        id,
        name: contact.name || contact.notify || id.split('@')[0],
        isGroup: id.endsWith('@g.us')
      }));
    } catch {
      return [];
    }
  }

  async getChats() {
    if (!this.sock) return [];
    try {
      const chats = await this.sock.groupFetchAllParticipating();
      return Object.entries(chats).map(([id, chat]) => ({
        id,
        name: chat.subject || id,
        isGroup: true,
        participants: chat.participants?.length || 0
      }));
    } catch {
      return [];
    }
  }

  async listAccessTargets() {
    const [contacts, chats] = await Promise.all([
      this.getContacts(),
      this.getChats(),
    ]);
    return [
      ...contacts
        .filter((item) => !item.isGroup)
        .map((item) => ({
          source: 'live',
          bucket: 'directRules',
          scope: 'phone_number',
          value: String(item.id || '').split('@')[0],
          label: item.name || String(item.id || '').split('@')[0],
          subtitle: 'WhatsApp contact',
        })),
      ...chats.map((chat) => ({
        source: 'live',
        bucket: 'sharedSpaceRules',
        scope: 'group',
        value: chat.id,
        label: chat.name || chat.id,
        subtitle: 'WhatsApp group',
      })),
    ];
  }

  getAuthInfo() {
    return { qrCode: this.qrCode, status: this.status };
  }

  async logout() {
    this._manualDisconnect = true;
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = null;
    }
    if (this.sock) {
      await this.sock.logout();
      this.sock = null;
    }
    fs.rmSync(this.authDir, { recursive: true, force: true });
    this.status = 'disconnected';
    this.qrCode = null;
  }
}

module.exports = { WhatsAppPlatform };
