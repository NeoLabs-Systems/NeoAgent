const { BasePlatform } = require('./base');
const path = require('path');
const fs = require('fs');

const AUTH_DIR = path.join(__dirname, '..', '..', 'data', 'whatsapp-auth');

class WhatsAppPlatform extends BasePlatform {
  constructor(config = {}) {
    super('whatsapp', config);
    this.supportsGroups = true;
    this.supportsMedia = true;
    this.sock = null;
    this.qrCode = null;
    this.reconnectAttempts = 0;
    this.maxReconnect = 5;
    this.authDir = config.authDir || AUTH_DIR;
  }

  async connect() {
    if (!fs.existsSync(this.authDir)) fs.mkdirSync(this.authDir, { recursive: true });

    const {
      default: makeWASocket,
      useMultiFileAuthState,
      DisconnectReason,
      makeCacheableSignalKeyStore,
      fetchLatestBaileysVersion
    } = require('@whiskeysockets/baileys');
    const pino = require('pino');

    let logger;
    try {
      logger = pino({ level: 'silent' });
    } catch {
      logger = { level: 'silent', info: () => {}, error: () => {}, warn: () => {}, debug: () => {}, trace: () => {}, child: () => logger };
    }

    const { version, isLatest } = await fetchLatestBaileysVersion();
    console.log(`[WhatsApp] Using WA version ${version.join('.')}, isLatest: ${isLatest}`);

    const { state, saveCreds } = await useMultiFileAuthState(this.authDir);

    this._logger = logger;

    this.sock = makeWASocket({
      version,
      auth: {
        creds: state.creds,
        keys: makeCacheableSignalKeyStore(state.keys, logger)
      },
      logger,
      browser: ['Ubuntu', 'Chrome', '131.0.0.0'],
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
        this.qrCode = qr;
        this.status = 'awaiting_qr';
        this.emit('qr', qr);
      }

      if (connection === 'close') {
        const statusCode = lastDisconnect?.error?.output?.statusCode;
        const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

        this.status = 'disconnected';
        this.emit('disconnected', { statusCode, shouldReconnect });

        if (shouldReconnect && this.reconnectAttempts < this.maxReconnect) {
          this.reconnectAttempts++;
          const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
          setTimeout(() => this.connect(), delay);
        } else if (statusCode === DisconnectReason.loggedOut) {
          fs.rmSync(this.authDir, { recursive: true, force: true });
          this.emit('logged_out');
        }
      }

      if (connection === 'open') {
        this.status = 'connected';
        this.qrCode = null;
        this.reconnectAttempts = 0;
        this.emit('connected');
      }
    });

    this.sock.ev.on('messages.upsert', async ({ messages, type }) => {
      if (type !== 'notify') return;

      for (const msg of messages) {
        if (msg.key.fromMe) continue;

        const chatId = msg.key.remoteJid;
        const isGroup = chatId?.endsWith('@g.us');
        const sender = isGroup ? msg.key.participant : chatId;
        const pushName = msg.pushName || '';

        let content = '';
        let mediaType = null;

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
          content = '[Voice Note]';
          mediaType = 'audio';
        } else if (msg.message?.documentMessage) {
          content = msg.message.documentMessage.fileName || '[Document]';
          mediaType = 'document';
        } else if (msg.message?.stickerMessage) {
          content = '[Sticker]';
          mediaType = 'sticker';
        }

        if (!content && !mediaType) continue;

        let localMediaPath = null;
        if (mediaType && mediaType !== 'sticker' && mediaType !== 'audio') {
          try {
            const { downloadMediaMessage } = require('@whiskeysockets/baileys');
            const MEDIA_DIR = path.join(__dirname, '..', '..', 'data', 'media');
            if (!fs.existsSync(MEDIA_DIR)) fs.mkdirSync(MEDIA_DIR, { recursive: true });
            const buffer = await downloadMediaMessage(msg, 'buffer', {}, {
              logger: this._logger,
              reuploadRequest: this.sock.updateMediaMessage
            });
            const extMap = { image: 'jpg', video: 'mp4', document: 'bin' };
            const ext = extMap[mediaType] || 'bin';
            const safeId = (msg.key.id || 'file').replace(/[^a-zA-Z0-9]/g, '');
            const fname = `${Date.now()}_${safeId}.${ext}`;
            localMediaPath = path.join(MEDIA_DIR, fname);
            fs.writeFileSync(localMediaPath, buffer);
          } catch (dlErr) {
            console.error('[WhatsApp] Media download failed:', dlErr.message);
          }
        }

        try {
          await this.sock.readMessages([msg.key]);
        } catch { /* non-fatal */ }

        this.emit('message', {
          platform: 'whatsapp',
          chatId,
          sender,
          senderName: pushName,
          content,
          mediaType,
          localMediaPath,
          isGroup,
          messageId: msg.key.id,
          timestamp: msg.messageTimestamp ? new Date(msg.messageTimestamp * 1000).toISOString() : new Date().toISOString(),
          rawMessage: msg
        });
      }
    });

    return { status: this.status };
  }

  async disconnect() {
    if (this.sock) {
      this.sock.end();
      this.sock = null;
    }
    this.status = 'disconnected';
    this.emit('disconnected', { manual: true });
  }

  async sendMessage(to, content, options = {}) {
    if (!this.sock || this.status !== 'connected') {
      throw new Error('WhatsApp not connected');
    }

    let jid = to;
    if (!jid.includes('@')) {
      jid = jid.replace(/[^0-9]/g, '') + '@s.whatsapp.net';
    }

    if (options.mediaPath) {
      const ext = path.extname(options.mediaPath).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext)) {
        return await this.sock.sendMessage(jid, {
          image: fs.readFileSync(options.mediaPath),
          caption: content || undefined
        });
      } else if (['.mp4', '.avi', '.mov'].includes(ext)) {
        return await this.sock.sendMessage(jid, {
          video: fs.readFileSync(options.mediaPath),
          caption: content || undefined
        });
      } else if (['.mp3', '.ogg', '.m4a'].includes(ext)) {
        return await this.sock.sendMessage(jid, {
          audio: fs.readFileSync(options.mediaPath),
          mimetype: 'audio/mp4'
        });
      } else {
        return await this.sock.sendMessage(jid, {
          document: fs.readFileSync(options.mediaPath),
          fileName: path.basename(options.mediaPath),
          caption: content || undefined
        });
      }
    }

    return await this.sock.sendMessage(jid, { text: content });
  }

  async markRead(chatId, messageId) {
    if (!this.sock) return;
    let jid = chatId;
    if (!jid.includes('@')) jid = jid + '@s.whatsapp.net';
    // readMessages expects full message keys; we do a best-effort read
    await this.sock.sendReadReceipt(jid, null, [messageId]).catch(() => {});
  }

  async sendTyping(chatId, isTyping) {
    if (!this.sock || this.status !== 'connected') return;
    let jid = chatId;
    if (!jid.includes('@')) jid = jid + '@s.whatsapp.net';
    await this.sock.sendPresenceUpdate(isTyping ? 'composing' : 'paused', jid).catch(() => {});
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

  getAuthInfo() {
    return { qrCode: this.qrCode, status: this.status };
  }

  async logout() {
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
