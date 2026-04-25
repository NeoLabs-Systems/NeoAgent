'use strict';

const { BasePlatform } = require('./base');
const { Telegraf } = require('telegraf');

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
    this._contextBuffers = new Map();
    this._contextMaxSize = 25;
    this._contextMaxChats = 200;
    this._seenUsers = new Map();
    this._seenGroups = new Map();
  }

  async connect() {
    if (!this.botToken) throw new Error('Telegram bot token is required');

    if (this._bot) {
      try {
        await Promise.resolve(this._bot.stop('reconnect'));
      } catch {}
      this._bot = null;
    }

    this._bot = new Telegraf(this.botToken);
    this.status = 'connecting';
    this._bot.on('message', (ctx) => {
      this._handleMessage(ctx).catch((err) => {
        console.error('[Telegram] Message handler error:', err.message);
      });
    });
    this._bot.catch((err) => {
      console.error('[Telegram] Polling error:', err.message);
      if (err.message && err.message.includes('401')) {
        this.status = 'error';
        this.emit('error', { message: 'Invalid bot token' });
      }
    });

    const withTimeout = (promise, label) => new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error(`${label} timed out after 20 s`)), 20000);
      promise
        .then((value) => {
          clearTimeout(timeout);
          resolve(value);
        })
        .catch((err) => {
          clearTimeout(timeout);
          reject(err);
        });
    });

    try {
      const me = await withTimeout(this._bot.telegram.getMe(), 'Telegram login');
      this._botUser = me;
      this.status = 'connected';
      console.log(`[Telegram] Logged in as @${me.username} (${me.id})`);
      this.emit('connected');
      this._bot.launch({ dropPendingUpdates: false }).catch((err) => {
        this.status = 'error';
        this.emit('error', { message: err.message || 'Telegram polling failed' });
        console.error('[Telegram] Launch failed:', err.message);
      });
      return { status: 'connected' };
    } catch (err) {
      this.status = 'error';
      try {
        await Promise.resolve(this._bot.stop('connect_failed'));
      } catch {}
      this._bot = null;
      throw err;
    }
  }

  async disconnect() {
    if (this._bot) {
      try {
        await Promise.resolve(this._bot.stop('manual'));
      } catch {}
      this._bot = null;
    }
    this.status = 'disconnected';
    this._botUser = null;
    this._contextBuffers.clear();
    this._seenUsers.clear();
    this._seenGroups.clear();
    this.emit('disconnected', { manual: true });
  }

  async logout() { await this.disconnect(); }
  getStatus() { return this.status; }
  getAuthInfo() { return this._botUser ? { username: this._botUser.username, id: this._botUser.id } : null; }

  _isMentioned(msg) {
    if (!this._botUser) return false;
    const text = msg.text || msg.caption || '';
    const entities = msg.entities || msg.caption_entities || [];
    const botId = String(this._botUser.id || '');
    const botUsername = String(this._botUser.username || '').toLowerCase();
    const botMention = `@${botUsername}`;
    for (const e of entities) {
      const value = text.slice(e.offset, e.offset + e.length).toLowerCase();
      if (e.type === 'mention') {
        if (value === botMention) return true;
      }
      if (e.type === 'bot_command') {
        if (value.endsWith(botMention)) return true;
      }
      if (e.type === 'text_mention' && String(e.user?.id || '') === botId) {
        return true;
      }
    }
    if (msg.reply_to_message?.from && String(msg.reply_to_message.from.id || '') === botId) {
      return true;
    }
    if (botUsername) {
      const escaped = botUsername.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      if (new RegExp(`(^|\\s)@${escaped}\\b`, 'i').test(text)) return true;
    }
    return false;
  }

  _stripMention(text) {
    if (!this._botUser) return (text || '').trim();
    const username = String(this._botUser.username || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return (text || '')
      .replace(new RegExp(`@${username}`, 'gi'), '')
      .replace(/\s{2,}/g, ' ')
      .trim();
  }

  _addToContext(rawChatId, entry) {
    if (!this._contextBuffers.has(rawChatId)) this._contextBuffers.set(rawChatId, []);
    const buf = this._contextBuffers.get(rawChatId);
    buf.push(entry);
    if (buf.length > this._contextMaxSize) buf.shift();

    // Keep only the most recently active chat contexts so memory usage does not
    // grow forever as the bot encounters new chats/groups over time.
    this._contextBuffers.delete(rawChatId);
    this._contextBuffers.set(rawChatId, buf);
    while (this._contextBuffers.size > this._contextMaxChats) {
      const oldestKey = this._contextBuffers.keys().next().value;
      if (oldestKey == null) break;
      this._contextBuffers.delete(oldestKey);
    }
  }

  _getContext(rawChatId) {
    return [...(this._contextBuffers.get(rawChatId) || [])];
  }

  async _handleMessage(ctx) {
    const msg = ctx?.message;
    if (!msg) return;
    if (!msg.from || msg.from.is_bot) return;
    if (this._bot && this.status === 'connecting') {
      this.status = 'connected';
      this.emit('connected');
    }

    const isPrivate = msg.chat.type === 'private';
    const userId = String(msg.from.id);
    const rawChatId = String(msg.chat.id);
    const outputChatId = isPrivate ? `dm_${userId}` : rawChatId;

    const text = msg.text || msg.caption || '';
    const senderUsername = msg.from.username ? `@${msg.from.username}` : null;
    const senderDisplayName = [msg.from.first_name, msg.from.last_name].filter(Boolean).join(' ')
      || senderUsername || userId;
    const senderName = senderDisplayName;
    this._seenUsers.set(userId, senderDisplayName);
    if (!isPrivate) {
      this._seenGroups.set(rawChatId, msg.chat.title || rawChatId);
    }

    this._addToContext(rawChatId, {
      author: senderName,
      content: text || (msg.photo ? '[photo]' : msg.document ? '[document]' : '[empty]'),
      mine: false,
    });

    const access = this._checkInboundAccess({
      platform: 'telegram',
      senderId: userId,
      chatId: outputChatId,
      isDirect: isPrivate,
      isShared: !isPrivate,
      groupId: !isPrivate ? rawChatId : '',
      channelId: '',
      serverId: '',
      roomId: '',
      roleIds: [],
      phoneNumber: '',
      wasMentioned: isPrivate ? false : this._isMentioned(msg),
    }, {
      senderName,
      meta: msg.chat.title ? `Group: ${msg.chat.title}` : '',
      groupLabel: msg.chat.title || rawChatId,
    });

    if (!access.allowed) {
      return;
    }

    let content = (!isPrivate && this._isMentioned(msg)) ? this._stripMention(text) : text;
    if (!content && msg.photo) content = `[photo]`;
    if (!content && msg.document) content = `[document: ${msg.document.file_name || 'file'}]`;
    if (!content) return;

    const fullSenderName = isPrivate
      ? senderName
      : `${senderName} in ${msg.chat.title || rawChatId}`;

    const channelContext = (!isPrivate && this._isMentioned(msg)) ? this._getContext(rawChatId) : null;

    this.emit('message', {
      platform: 'telegram',
      chatId: outputChatId,
      sender: userId,
      senderName: fullSenderName,
      senderDisplayName,
      senderUsername,
      senderTag: senderUsername,
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

  async sendMessage(to, content, _options = {}) {
    if (!this._bot || this.status === 'disconnected' || this.status === 'error') {
      throw new Error('Telegram not connected');
    }

    const telegramChatId = to.startsWith('dm_') ? to.slice(3) : to;
    await this._bot.telegram.sendMessage(telegramChatId, content);

    if (this._botUser) {
      this._addToContext(telegramChatId, {
        author: `[bot] ${this._botUser.username}`,
        content,
        mine: true,
      });
    }

    return { success: true };
  }

  async sendTyping(chatId, isTyping) {
    if (!this._bot || this.status !== 'connected') return;
    if (!isTyping) return;
    try {
      const id = chatId.startsWith('dm_') ? chatId.slice(3) : chatId;
      await this._bot.telegram.sendChatAction(id, 'typing');
    } catch {}
  }

  async listAccessTargets() {
    const targets = [];
    for (const [userId, label] of this._seenUsers.entries()) {
      targets.push({
        source: 'live',
        bucket: 'directRules',
        scope: 'user',
        value: userId,
        label,
        subtitle: 'Telegram user',
      });
    }
    for (const [groupId, label] of this._seenGroups.entries()) {
      targets.push({
        source: 'live',
        bucket: 'sharedSpaceRules',
        scope: 'group',
        value: groupId,
        label,
        subtitle: 'Telegram group',
      });
    }
    return targets;
  }
}

module.exports = { TelegramPlatform };
