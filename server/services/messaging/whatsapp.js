const { BasePlatform } = require('./base');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const { normalizeWhatsAppId, toWhatsAppJid } = require('../../utils/whatsapp');
const { DATA_DIR } = require('../../../runtime/paths');
const { createServiceLogger, maskSenderId } = require('../../utils/logger');
const { fileExtensionForMimeType } = require('../voice/liveAudio');

const log = createServiceLogger('WhatsApp');

const AUTH_DIR = path.join(DATA_DIR, 'whatsapp-auth');
const SENT_MESSAGE_MEMORY = 200;
const BAD_SESSION_RETRY_LIMIT = 5;
const STABLE_CONNECTION_MS = 2 * 60 * 1000;
const POLL_NAME_LIMIT = 255;
const ALIAS_LOOKUP_MS = 3000;

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

// What a quoted message says, as far as the quote carries it: text and
// captions come along, media only as its kind.
function quotedText(quoted = {}) {
  const text = quoted.conversation
    || quoted.extendedTextMessage?.text
    || quoted.imageMessage?.caption
    || quoted.videoMessage?.caption
    || quoted.documentMessage?.caption;
  if (text) return text;
  if (quoted.imageMessage) return '[Image]';
  if (quoted.videoMessage) return '[Video]';
  if (quoted.audioMessage) return quoted.audioMessage.ptt ? '[Voice message]' : '[Audio]';
  if (quoted.documentMessage) return `[Document${quoted.documentMessage.fileName ? `: ${quoted.documentMessage.fileName}` : ''}]`;
  if (quoted.stickerMessage) return '[Sticker]';
  return '';
}

function isPhoneJid(jid) {
  return /@(s\.whatsapp\.net|hosted)$/.test(String(jid || ''));
}

function optionHash(label) {
  return crypto.createHash('sha256').update(label).digest('hex');
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
    /** Approval polls still open, by message id. @type {Map<string, object>} */
    this._approvalPolls = new Map();
    // Until a connection reports open there is no point from which a message
    // counts as new, so replayed history stays out.
    this._connectedAt = Infinity;
  }

  // Baileys copies sock.user once, when it builds the socket, and only adds the
  // LID to the live creds after the connection opens. On a freshly linked
  // session, sock.user has no LID while the phone already addresses the self
  // chat by it, so every note looked like another contact's. Both places are
  // read, since which one carries which id differs between client versions.
  _ownIds() {
    const identities = [this.sock?.user, this.sock?.authState?.creds?.me];
    return new Set(identities
      .flatMap((me) => [me?.id, me?.jid, me?.lid])
      .map(normalizeWhatsAppId)
      .filter(Boolean));
  }

  // Who sent a message, in the two forms WhatsApp may use. Contacts arrive under
  // a LID, but people are listed and linked by number, so the number wins
  // whenever it is known.
  _senderAddresses(key = {}) {
    const isGroup = String(key.remoteJid || '').endsWith('@g.us');
    const primary = isGroup ? key.participant : key.remoteJid;
    const alternate = isGroup ? key.participantAlt : key.remoteJidAlt;
    const phone = [primary, alternate].find(isPhoneJid) || null;
    return { primary, phone, sender: phone || primary };
  }

  // WhatsApp usually sends the number along; otherwise it may be known from
  // earlier traffic.
  async _learnPhoneNumber(key = {}) {
    const { primary, phone } = this._senderAddresses(key);
    if (phone || !String(primary || '').endsWith('@lid')) return;
    const known = await this.sock?.signalRepository?.lidMapping?.getPNForLID?.(primary).catch(() => null);
    if (!known) return;
    if (String(key.remoteJid || '').endsWith('@g.us')) key.participantAlt = known;
    else key.remoteJidAlt = known;
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

  // A direct chat has two addresses, the LID and the number: messages may
  // arrive under one while deliveries go to the other. Both are listed, LID
  // first, so the chat keeps one conversation whichever is used. A mapping
  // WhatsApp has to be asked for is not waited on for long.
  async conversationChatIds(chatId) {
    const { jidNormalizedUser } = require('baileys');
    const jid = String(chatId || '');
    const mapping = this.sock?.signalRepository?.lidMapping;
    const lookup = (promise) => Promise.race([
      Promise.resolve(promise).catch(() => null),
      new Promise((resolve) => { setTimeout(resolve, ALIAS_LOOKUP_MS, null).unref?.(); }),
    ]);
    if (jid.endsWith('@lid')) {
      const pn = await lookup(mapping?.getPNForLID?.(jid));
      return pn ? [jid, jidNormalizedUser(pn)] : [jid];
    }
    if (isPhoneJid(jid)) {
      const lid = await lookup(mapping?.getLIDForPN?.(jid));
      return lid ? [jidNormalizedUser(lid), jid] : [jid];
    }
    return [jid];
  }

  // The message a quote-reply answers. WhatsApp sends the quoted message along,
  // so it is there however old it is.
  _replyTarget(message = {}, { sender = '', pushName = '' } = {}) {
    const contextInfo = this._contextInfo(message);
    if (!contextInfo?.stanzaId) return null;
    const { normalizeMessageContent } = require('baileys');
    const content = quotedText(normalizeMessageContent(contextInfo.quotedMessage) || {});
    const author = normalizeWhatsAppId(contextInfo.participant);
    // In the self chat both sides are the same account; the agent's label on
    // its replies tells them apart.
    const agentName = String(this.resolveAgentName?.() || '').trim();
    const fromAgent = Boolean(author) && this._ownIds().has(author)
      && (!this.selfChatMode || !agentName || content.startsWith(`(${agentName}):`));
    return {
      fromAgent,
      sender: fromAgent ? null : (author && author === normalizeWhatsAppId(sender) ? pushName || null : null),
      content: content || null,
    };
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

  _accessContext(msg, { chatId, isGroup, sender, content = '', pushName = '' }) {
    const senderId = normalizeWhatsAppId(this._senderAddresses(msg.key).phone || sender);
    return {
      platform: 'whatsapp',
      senderId,
      chatId,
      isDirect: !isGroup,
      isShared: isGroup,
      groupId: isGroup ? chatId : '',
      phoneNumber: senderId,
      wasMentioned: isGroup && this._isGroupAddressedToBot(msg.message || {}),
      // A contact can move between a phone-number and a LID address; the phone
      // number is what stays the same person.
      stableSenderId: senderId,
      text: content,
      messageId: msg.key?.id || null,
      senderName: pushName,
    };
  }

  _checkMessageAccess(msg, { chatId, isGroup, sender, pushName, content }) {
    // Self-chat mode only ever reaches this point for notes the account owner
    // wrote in their own chat, so the allowlist has nothing left to decide.
    if (this.selfChatMode) return { allowed: true };

    const context = this._accessContext(msg, { chatId, isGroup, sender, content, pushName });
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

  // Joins and leaves never start a chat run and skip the access policy; they
  // only feed the owner's tasks.
  _emitMembership({ id, participants, action }) {
    const kind = action === 'add' ? 'member_joined' : action === 'remove' ? 'member_left' : null;
    if (!kind) return;
    const ownIds = this._ownIds();
    for (const participant of participants || []) {
      const memberId = typeof participant === 'string' ? participant : participant?.id;
      if (!memberId || ownIds.has(normalizeWhatsAppId(memberId))) continue;
      this.emit(kind, {
        spaceId: id,
        spaceName: null,
        chatId: id,
        memberId,
        memberName: normalizeWhatsAppId(memberId) || memberId,
        dmChatId: memberId,
        occurredAt: new Date().toISOString(),
      });
    }
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
      getMessage: async (key) => this._approvalPolls.get(key.id)?.message,
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
        clearTimeout(this._stableTimer);
        const reasonName = Object.keys(DisconnectReason)
          .find((name) => DisconnectReason[name] === statusCode) || 'unknown';
        // A session WhatsApp keeps rejecting will not heal by reconnecting;
        // every retry is a fresh device login that pings the phone.
        const sessionBroken = statusCode === DisconnectReason.badSession
          && this.reconnectAttempts >= BAD_SESSION_RETRY_LIMIT;
        const shouldReconnect = !this._manualDisconnect
          && statusCode !== DisconnectReason.loggedOut
          && !sessionBroken;
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
          requiresUserAction: sessionBroken,
          reason: sessionBroken ? 'bad_session' : shouldReconnect ? 'connection_lost' : null,
        });

        if (shouldReconnect) {
          this._scheduleReconnect();
        } else if (statusCode === DisconnectReason.loggedOut) {
          // The dead socket goes first so nothing it still writes can put the
          // revoked credentials back; the next connect then pairs from scratch.
          this._discardSocket();
          fs.rmSync(this.authDir, { recursive: true, force: true });
          this.qrCode = null;
          this.emit('logged_out');
        }
      }

      if (connection === 'open') {
        log.info('Connection open; inbound messages will be processed.');
        this._connectedAt = Math.floor(Date.now() / 1000);
        this.status = 'connected';
        this.qrCode = null;
        // Only a link that survives a while earns a fresh backoff; resetting on
        // open made a link that dies right after opening retry every 2 seconds.
        clearTimeout(this._stableTimer);
        this._stableTimer = setTimeout(() => { this.reconnectAttempts = 0; }, STABLE_CONNECTION_MS);
        this._stableTimer.unref?.();
        this.emit('connected');
      }
    });

    this.sock.ev.on('group-participants.update', (update) => this._emitMembership(update));

    this.sock.ev.on('call', (calls) => {
      this._handleCalls(calls).catch((err) => log.error('Call handling failed:', err.message));
    });

    this.sock.ev.on('messages.upsert', async ({ messages, type }) => {
      for (const msg of messages) {
        await this._learnPhoneNumber(msg.key);
        if (msg.message?.pollUpdateMessage) {
          this._handlePollVote(msg);
          continue;
        }
        if (!this._shouldProcessInbound(msg, type)) continue;
        // The phone's own sync traffic (history notices, app-state keys) is
        // addressed to the self chat as well; it is not a note.
        if (msg.message?.protocolMessage) continue;

        const chatId = msg.key.remoteJid;
        const isGroup = chatId?.endsWith('@g.us');
        const { sender } = this._senderAddresses(msg.key);
        const pushName = msg.pushName || '';
        const wasMentioned = isGroup && this._isGroupAddressedToBot(msg.message || {});

        if (msg.message?.reactionMessage) {
          if (!isGroup) this._emitReaction(msg, { chatId, sender, pushName });
          continue;
        }

        let content = '';
        let mediaType = null;
        let voiceNote = null;
        let mediaFileName = null;
        let mediaError = null;
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
          const doc = msg.message.documentMessage;
          mediaFileName = doc.fileName || null;
          // The caption carries the sender's instruction; the file name is
          // only a fallback so the agent still sees what was attached.
          content = doc.caption || doc.fileName || '[Document]';
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
          content,
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
            const nameExt = mediaFileName
              ? path.extname(mediaFileName).slice(1).replace(/[^a-zA-Z0-9]/g, '').toLowerCase()
              : '';
            const ext = audioMimeType
              ? fileExtensionForMimeType(audioMimeType)
              : (mediaType === 'document' && nameExt ? nameExt : (extMap[mediaType] || 'bin'));
            const safeId = (msg.key.id || 'file').replace(/[^a-zA-Z0-9]/g, '');
            // On an instance-wide account the file belongs to the linked sender.
            const mediaOwnerId = access.ownerUserId || this.userId;
            if (!this.artifactStore || !mediaOwnerId) {
              throw new Error('Per-user artifact storage is unavailable.');
            }
            const artifact = await this.artifactStore.createBufferArtifact(mediaOwnerId, {
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
            mediaError = dlErr.message;
          }
        }

        try {
          await this.sock.readMessages([msg.key]);
        } catch { /* non-fatal */ }

        log.info(
          `Accepted ${isGroup ? 'group' : 'direct'} message`
          + `${mediaType ? ` (${mediaType})` : ''} for processing.`,
        );
        const replyTo = this._replyTarget(msg.message || {}, { sender, pushName });
        this.emit('message', {
          platform: 'whatsapp',
          chatId,
          sender,
          senderName: pushName,
          senderDisplayName: pushName || null,
          senderTag: normalizeWhatsAppId(sender) || sender,
          wasMentioned,
          repliedToAgent: replyTo?.fromAgent === true,
          replyToMessageId: this._contextInfo(msg.message || {})?.stanzaId || null,
          replyTo,
          groupId: isGroup ? chatId : null,
          content,
          mediaType,
          localMediaPath,
          mediaFileName,
          mediaError,
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
      previous.ev?.removeAllListeners?.('call');
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

  async sendApprovalPrompt(chatId, { text, options }) {
    if (!this.sock || this.status !== 'connected') {
      throw new Error('WhatsApp not connected');
    }
    const jid = toWhatsAppJid(chatId);
    if (!jid) throw new Error('Invalid WhatsApp chat');
    const sent = await this.sock.sendMessage(jid, {
      poll: { name: text.slice(0, POLL_NAME_LIMIT), values: options.map((option) => option.label), selectableCount: 1 },
    });
    this._rememberSentMessage(sent?.key?.id);
    this._approvalPolls.set(sent.key.id, { key: sent.key, message: sent.message, options });
    return { promptId: sent.key.id };
  }

  async deleteApprovalPrompt(chatId, promptId) {
    const poll = this._approvalPolls.get(promptId);
    this._approvalPolls.delete(promptId);
    if (!poll || !this.sock) return;
    const sent = await this.sock.sendMessage(toWhatsAppJid(chatId), { delete: poll.key });
    this._rememberSentMessage(sent?.key?.id);
  }

  // Votes are encrypted to the poll's secret, the poll's author and the voter,
  // under whichever address each side used, and Baileys no longer decrypts them.
  // Decryption authenticates, so a wrong pairing just fails.
  _decryptVote(update, poll, key) {
    const { decryptPollVote } = require('baileys');
    const own = [...this._ownJids()];
    const { primary, phone } = this._senderAddresses(key);
    const voters = key.fromMe ? own : [primary, phone].filter(Boolean).map(toWhatsAppJid);
    for (const pollCreatorJid of own) {
      for (const voterJid of voters) {
        try {
          return decryptPollVote(update.vote, {
            pollCreatorJid,
            pollMsgId: poll.key.id,
            pollEncKey: poll.message.messageContextInfo.messageSecret,
            voterJid,
          });
        } catch {
          // The next pairing may be the one it was encrypted under.
        }
      }
    }
    return null;
  }

  // In self-chat mode the connected account is the owner's, and their own chat is
  // where they talk to the agent. Otherwise the number may be the agent's own.
  ownerChatId() {
    if (!this.selfChatMode) return null;
    return [...this._ownJids()].find((jid) => jid.endsWith('@s.whatsapp.net')) || [...this._ownJids()][0] || null;
  }

  _ownJids() {
    const identities = [this.sock?.user, this.sock?.authState?.creds?.me];
    return new Set(identities
      .flatMap((me) => [me?.id, me?.lid])
      .map(toWhatsAppJid)
      .filter(Boolean));
  }

  _handlePollVote(msg) {
    const update = msg.message.pollUpdateMessage;
    const poll = this._approvalPolls.get(update.pollCreationMessageKey?.id);
    if (!poll) return;
    const vote = this._decryptVote(update, poll, msg.key);
    if (!vote) {
      log.warn('Could not read a vote on an approval poll.');
      return;
    }
    const selected = (vote.selectedOptions || []).map((hash) => Buffer.from(hash).toString('hex'));
    const option = poll.options.find((item) => selected.includes(optionHash(item.label)));
    // An empty selection means the vote was taken back.
    if (!option) return;

    const chatId = msg.key.remoteJid;
    const isGroup = chatId?.endsWith('@g.us');
    const { sender, phone } = this._senderAddresses(msg.key);
    const fromMe = msg.key.fromMe === true;
    // An instance-wide account's holder is not whoever linked this chat, and
    // self-chat mode only answers in the account's own chat.
    if (fromMe && this.accessGate) return;
    if (this.selfChatMode && !(fromMe && this._isSelfChat(chatId))) return;
    this.emit('approval_response', {
      platform: 'whatsapp',
      chatId,
      promptId: poll.key.id,
      choiceId: option.id,
      actor: {
        sender,
        phoneNumber: normalizeWhatsAppId(phone || sender),
        senderName: msg.pushName || '',
        isGroup,
        groupId: isGroup ? chatId : null,
        metadata: this.selfChatMode ? { selfChat: true } : null,
        isAccountHolder: fromMe,
      },
    });
  }

  // An offer on the owner's own number is a call to the owner, so self-chat mode
  // leaves it ringing. Otherwise the account has no one to answer. Calling back
  // is for people the owner listed: a stranger must not be able to ring their
  // phone by dialling this number.
  async _handleCalls(calls = []) {
    if (this.selfChatMode) return;
    for (const call of calls) {
      if (call.status !== 'offer') continue;
      await this.sock.rejectCall(call.id, call.from);
      log.info(`Rejected an incoming WhatsApp ${call.isVideo ? 'video ' : ''}call.`);
      // Reported while this device was offline, so the call is already over.
      if (call.offline || call.isGroup) {
        log.info('Not calling back: the call was a group call or is already over.');
        continue;
      }

      const phone = [call.from, call.callerPn].find(isPhoneJid)
        || await this.sock.signalRepository?.lidMapping?.getPNForLID?.(call.from).catch(() => null)
        || null;
      const senderId = normalizeWhatsAppId(phone || call.from);
      const access = this.evaluateAccess({
        platform: 'whatsapp',
        senderId,
        stableSenderId: senderId,
        chatId: phone || call.from,
        isDirect: true,
        isShared: false,
        groupId: '',
        phoneNumber: senderId,
        wasMentioned: false,
        text: '',
      });
      if (!access.allowed || (!access.ownerUserId && access.policy?.directPolicy !== 'allowlist')) {
        log.info(
          `Not calling back ${maskSenderId(senderId)}: only someone on the direct-message allowlist gets a call back`
          + `${phone ? '' : ', and this caller only showed a LID'}.`,
        );
        continue;
      }
      this.emit('incoming_call', {
        platform: 'whatsapp',
        callerId: senderId,
        chatId: phone || call.from,
      });
    }
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
    return {
      qrCode: this.qrCode,
      status: this.status,
      number: normalizeWhatsAppId(this.sock?.user?.id) || null,
    };
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
