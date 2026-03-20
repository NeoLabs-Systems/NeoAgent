'use strict';

const { BasePlatform } = require('./base');
const TelegramBot = require('node-telegram-bot-api');

/**
 * Whitelist entry format (prefixed strings):
 *   "user:ID"   → always respond in DMs, no mention needed
 *   "group:ID"  → respond in this group/supergroup when @mentioned
 *   "ID"        → legacy plain ID, treated as "user"
 *
 * Telegram group/supergroup IDs are negative numbers (e.g. -1001234567890).
 *
 * chatId emitted on message events:
 *   DMs:    "dm_<userId>"
 *   Groups: "<chatId>"  (negative integer as string)
 */
class TelegramPlatform extends BasePlatform {
  constructor(config = {}) {
    super('telegram', config);
    this.supportsGroups = true;
    this.supportsMedia = false;

    this.botToken = config.botToken || '';
    if (Array.isArray(config.allowedIds)) {
      this.setAllowedEntries(config.allowedIds);
    }

    this._bot = null;
    this._botUser = null;
    // In-memory ring buffer of recent messages per raw chatId (Telegram has no fetch history API for bots)
    this._contextBuffers = new Map();
    this._contextMaxSize = 25;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  async connect() {
    if (!this.botToken) throw new Error('Telegram bot token is required');

    if (this._bot) { try { await this._bot.stopPolling(); } catch { } this._bot = null; }

    this._bot = new TelegramBot(this.botToken, { polling: true });

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Telegram login timed out after 20 s')), 20000);

      this._bot.getMe()
        .then((me) => {
          clearTimeout(timeout);
          this._botUser = me;
          this.status = 'connected';
          console.log(`[Telegram] Logged in as @${me.username} (${me.id})`);
          this.emit('connected');
          resolve({ status: 'connected' });
        })
        .catch((err) => { clearTimeout(timeout); reject(err); });

      this._bot.on('message', (msg) => this._handleMessage(msg));
      this._bot.on('polling_error', (err) => {
        console.error('[Telegram] Polling error:', err.message);
        if (err.message && err.message.includes('401')) {
          this.status = 'error';
          this.emit('error', { message: 'Invalid bot token' });
        }
      });
    });
  }

  async disconnect() {
    if (this._bot) { try { await this._bot.stopPolling(); } catch { } this._bot = null; }
    this.status = 'disconnected';
    this._botUser = null;
    this.emit('disconnected', { manual: true });
  }

  async logout() { await this.disconnect(); }
  getStatus() { return this.status; }
  getAuthInfo() { return this._botUser ? { username: this._botUser.username, id: this._botUser.id } : null; }

  // ── Whitelist ──────────────────────────────────────────────────────────────

  // Inherits setAllowedEntries from BasePlatform

  /** Returns {allowed, requireMention} */
  _checkAccess(msg) {
    const userId = String(msg.from.id);
    const chatId = String(msg.chat.id); // negative for groups
    const isPrivate = msg.chat.type === 'private';

    // Default behavior with no allow-list: respond in private chats and require @mention in groups.
    if (this.allowedEntries.size === 0) return { allowed: true, requireMention: !isPrivate };

    if (super._checkAccess(`user:${userId}`)) return { allowed: true, requireMention: false };
    if (super._checkAccess(userId)) return { allowed: true, requireMention: false }; // legacy
    if (super._checkAccess(`group:${chatId}`)) return { allowed: true, requireMention: true };

    return { allowed: false, requireMention: false };
  }

  _isMentioned(msg) {
    if (!this._botUser) return false;
    const text = msg.text || msg.caption || '';
    const entities = msg.entities || msg.caption_entities || [];
    for (const e of entities) {
      if (e.type === 'mention') {
        const mention = text.slice(e.offset, e.offset + e.length);
        if (mention.toLowerCase() === `@${this._botUser.username.toLowerCase()}`) return true;
      }
    }
    return false;
  }

  _stripMention(text) {
    if (!this._botUser) return (text || '').trim();
    return (text || '')
      .replace(new RegExp(`@${this._botUser.username}`, 'gi'), '')
      .replace(/\s{2,}/g, ' ')
      .trim();
  }

  // ── Context buffer (since Telegram bots can't fetch message history) ───────

  _addToContext(rawChatId, entry) {
    if (!this._contextBuffers.has(rawChatId)) this._contextBuffers.set(rawChatId, []);
    const buf = this._contextBuffers.get(rawChatId);
    buf.push(entry);
    if (buf.length > this._contextMaxSize) buf.shift();
  }

  _getContext(rawChatId) {
    return [...(this._contextBuffers.get(rawChatId) || [])];
  }

  // ── Message handler ────────────────────────────────────────────────────────

  async _handleMessage(msg) {
    if (!msg.from || msg.from.is_bot) return;

    const isPrivate = msg.chat.type === 'private';
    const userId = String(msg.from.id);
    const rawChatId = String(msg.chat.id);
    const outputChatId = isPrivate ? `dm_${userId}` : rawChatId;

    const text = msg.text || msg.caption || '';
    const senderName = [msg.from.first_name, msg.from.last_name].filter(Boolean).join(' ')
      || msg.from.username || userId;

    // Always record into context buffer (even blocked messages add context)
    this._addToContext(rawChatId, {
      author: senderName,
      content: text || (msg.photo ? '[photo]' : msg.document ? '[document]' : '[empty]'),
      mine: false,
    });

    const { allowed, requireMention } = this._checkAccess(msg);

    if (!allowed) {
      const suggestions = [
        { label: `Add user (${senderName})`, prefixedId: `user:${userId}` },
      ];
      if (!isPrivate) suggestions.push({
        label: `Add group (${msg.chat.title || rawChatId})`,
        prefixedId: `group:${rawChatId}`,
      });

      this.emit('blocked_sender', {
        sender: userId,
        chatId: outputChatId,
        senderName,
        groupName: msg.chat.title || null,
        suggestions,
      });
      return;
    }

    // Group entries require @mention to activate
    if (requireMention && !this._isMentioned(msg)) return;

    let content = requireMention ? this._stripMention(text) : text;
    if (!content && msg.photo) content = `[photo]`;
    if (!content && msg.document) content = `[document: ${msg.document.file_name || 'file'}]`;
    if (!content) return;

    const fullSenderName = isPrivate
      ? senderName
      : `${senderName} in ${msg.chat.title || rawChatId}`;

    const channelContext = (!isPrivate && requireMention) ? this._getContext(rawChatId) : null;

    this.emit('message', {
      platform: 'telegram',
      chatId: outputChatId,
      sender: userId,
      senderName: fullSenderName,
      content,
      mediaType: null,
      isGroup: !isPrivate,
      messageId: String(msg.message_id),
      timestamp: new Date(msg.date * 1000).toISOString(),
      channelContext,
      channelName: isPrivate ? null : (msg.chat.title || rawChatId),
      groupName: msg.chat.title || null,
    });
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  /**
   * to: "dm_<userId>" for DMs, or a raw chat ID (e.g. "-1001234567890") for groups
   */
  async sendMessage(to, content, _options = {}) {
    if (!this._bot || this.status !== 'connected') throw new Error('Telegram not connected');

    const telegramChatId = to.startsWith('dm_') ? to.slice(3) : to;
    await this._bot.sendMessage(telegramChatId, content);

    // Store outgoing message in context buffer
    if (this._botUser) {
      this._addToContext(telegramChatId, {
        author: `[bot] ${this._botUser.username}`,
        content,
        mine: true,
      });
    }

    return { success: true };
  }

  async sendTyping(chatId, _isTyping) {
    if (!this._bot || this.status !== 'connected') return;
    try {
      const id = chatId.startsWith('dm_') ? chatId.slice(3) : chatId;
      await this._bot.sendChatAction(id, 'typing');
    } catch { /* non-fatal */ }
  }
}

module.exports = { TelegramPlatform };
