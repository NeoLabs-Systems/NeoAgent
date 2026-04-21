'use strict';

const { BasePlatform } = require('./base');
const {
  Client,
  GatewayIntentBits,
  Partials,
  ChannelType,
} = require('discord.js');

/**
 * Whitelist entry format (prefixed strings):
 *   "user:SNOWFLAKE"    → allow DMs; allow guild messages only when @mentioned
 *   "guild:SNOWFLAKE"   → respond in any channel of this server when @mentioned
 *   "channel:SNOWFLAKE" → respond in this channel when @mentioned
 *   "SNOWFLAKE"         → legacy plain ID, treated as "user"
 *
 * chatId emitted on message events:
 *   DMs:    "dm_<userId>"
 *   Guilds: "<channelId>"
 */
class DiscordPlatform extends BasePlatform {
  constructor(config = {}) {
    super('discord', config);
    this.supportsGroups = true;
    this.supportsMedia = false;

    this.token = config.token || '';
    if (Array.isArray(config.allowedIds)) {
      this.setAllowedEntries(config.allowedIds);
    }

    this._client = null;
    this._botUser = null;
    this._manualDisconnect = false;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  async connect() {
    if (!this.token) throw new Error('Discord bot token is required');

    this._manualDisconnect = false;
    if (this._client) { try { this._client.destroy(); } catch { } this._client = null; }

    this._client = new Client({
      intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,  // Privileged — enable in Dev Portal
        GatewayIntentBits.DirectMessages,
      ],
      partials: [Partials.Channel, Partials.Message],
    });

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Discord login timed out after 20 s')), 20000);

      this._client.once('clientReady', async (c) => {
        clearTimeout(timeout);
        this._botUser = this._client.user;
        this.status = 'connected';
        console.log(`[Discord] Logged in as ${this._botUser.tag}`);
        this.emit('connected');
        resolve({ status: 'connected' });
      });

      this._client.once('error', (err) => { clearTimeout(timeout); reject(err); });
      this._client.on('error', (err) => console.error('[Discord] Client error:', err.message));
      this._client.on('shardDisconnect', (event, shardId) => {
        if (this._manualDisconnect) return;
        this.status = 'disconnected';
        console.warn(`[Discord] Shard ${shardId} disconnected (${event?.code || 'unknown'})`);
        this.emit('disconnected', {
          manual: false,
          shardId,
          code: event?.code || null,
          reason: event?.reason || null,
        });
      });
      this._client.on('shardReconnecting', (shardId) => {
        if (this._manualDisconnect) return;
        this.status = 'connecting';
        console.log(`[Discord] Shard ${shardId} reconnecting`);
      });
      this._client.on('shardResume', (_replayedEvents, shardId) => {
        if (this._manualDisconnect) return;
        this.status = 'connected';
        console.log(`[Discord] Shard ${shardId} resumed`);
        this.emit('connected');
      });
      this._client.on('invalidated', () => {
        if (this._manualDisconnect) return;
        this.status = 'logged_out';
        console.warn('[Discord] Session invalidated');
        this.emit('logged_out');
      });
      this._client.on('messageCreate', (msg) => this._handleMessage(msg));

      this._client.login(this.token).catch((err) => { clearTimeout(timeout); reject(err); });
    });
  }

  async disconnect() {
    this._manualDisconnect = true;
    if (this._client) { try { this._client.destroy(); } catch { } this._client = null; }
    this.status = 'disconnected';
    this._botUser = null;
    this.emit('disconnected', { manual: true });
  }

  async logout() { await this.disconnect(); }
  getStatus() { return this.status; }
  getAuthInfo() { return this._botUser ? { tag: this._botUser.tag, id: this._botUser.id } : null; }

  // ── Whitelist ──────────────────────────────────────────────────────────────

  // Inherits setAllowedEntries from BasePlatform

  /** Returns {allowed, requireMention} */
  _checkAccess(message) {
    const isDM = message.channel.type === ChannelType.DM;
    const userId = message.author.id;
    const guildId = message.guildId || null;
    const channelId = message.channelId;
    const userAllowed = super._checkAccess(`user:${userId}`) || super._checkAccess(userId);

    if (isDM) {
      return {
        allowed: this.allowedEntries.size === 0 || userAllowed,
        requireMention: false,
      };
    }

    return {
      allowed: userAllowed
        || (guildId && super._checkAccess(`guild:${guildId}`))
        || super._checkAccess(`channel:${channelId}`),
      requireMention: true,
    };
  }

  _isMentioned(message) {
    return this._botUser ? message.mentions.has(this._botUser.id) : false;
  }

  _stripMention(content) {
    if (!this._botUser) return content.trim();
    return content
      .replace(new RegExp(`<@!?${this._botUser.id}>`, 'g'), '')
      .replace(/\s{2,}/g, ' ')
      .trim();
  }

  // ── Channel context (last N messages) ─────────────────────────────────────

  async _fetchContext(channel, limit = 20) {
    try {
      const fetched = await channel.messages.fetch({ limit });
      return [...fetched.values()]
        .reverse()  // oldest first
        .map((m) => {
          const username = m.author.tag || m.author.username || m.author.id;
          const displayName = m.member?.displayName || m.author.globalName || m.author.username || username;
          const author = displayName && displayName !== username
            ? `${displayName} (${username})`
            : username;
          return {
            author: m.author.bot ? `[bot] ${author}` : author,
            content: m.content || (m.attachments.size ? '[attachment]' : '[empty]'),
            mine: m.author.id === this._botUser?.id,
          };
        });
    } catch { return []; }
  }

  // ── Message handler ────────────────────────────────────────────────────────

  async _handleMessage(message) {
    if (message.author.bot) return;

    const isDM = message.channel.type === ChannelType.DM;
    const userId = message.author.id;
    const guildId = message.guildId || null;
    const channelId = message.channelId;
    const chatId = isDM ? `dm_${userId}` : channelId;

    const { allowed, requireMention } = this._checkAccess(message);

    if (requireMention && !this._isMentioned(message)) return;

    if (!allowed) {
      const suggestions = [
        { label: `Add user (${message.author.username})`, prefixedId: `user:${userId}` },
      ];
      if (guildId) suggestions.push({ label: `Add server (${message.guild?.name || guildId})`, prefixedId: `guild:${guildId}` });
      if (!isDM) suggestions.push({ label: `Add channel (#${message.channel.name || channelId})`, prefixedId: `channel:${channelId}` });

      this.emit('blocked_sender', {
        sender: userId,
        chatId,
        senderName: message.author.username,
        guildName: message.guild?.name || null,
        suggestions,
      });
      return;
    }

    let content = requireMention ? this._stripMention(message.content) : (message.content || '');
    if (message.attachments.size > 0) {
      const urls = [...message.attachments.values()].map(a => a.url).join(', ');
      content += (content ? '\n' : '') + `[Attachment: ${urls}]`;
    }
    if (!content) return;

    const senderUsername = message.author.username || null;
    const senderTag = message.author.tag || senderUsername || userId;
    const senderDisplayName = isDM
      ? (message.author.globalName || senderUsername || userId)
      : (message.member?.displayName || message.author.globalName || senderUsername || userId);
    const senderName = isDM
      ? senderDisplayName
      : `${senderDisplayName} in #${message.channel.name || channelId}${message.guild ? ` (${message.guild.name})` : ''}`;

    // Fetch recent channel history for context on guild/channel mentions
    const channelContext = (requireMention && !isDM) ? await this._fetchContext(message.channel, 20) : null;

    this.emit('message', {
      platform: 'discord',
      chatId,
      sender: userId,
      senderName,
      senderDisplayName,
      senderUsername,
      senderTag,
      guildId,
      content,
      mediaType: null,
      isGroup: !isDM,
      messageId: message.id,
      timestamp: message.createdAt.toISOString(),
      channelContext,
      channelName: isDM ? null : (message.channel.name || channelId),
      guildName: message.guild?.name || null,
    });
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  /**
   * to: "dm_<userId>" for DMs, or a channel snowflake for guild channels
   */
  async sendMessage(to, content, _options = {}) {
    if (!this._client || this.status !== 'connected') throw new Error('Discord not connected');

    if (to.startsWith('dm_')) {
      const user = await this._client.users.fetch(to.slice(3));
      const dm = await user.createDM();
      await dm.send({ content });
    } else {
      const channel = await this._client.channels.fetch(to);
      if (!channel?.isTextBased()) throw new Error(`Channel ${to} is not text-based`);
      await channel.send({ content });
    }
    return { success: true };
  }

  async sendTyping(chatId, isTyping) {
    if (!this._client || this.status !== 'connected') return;
    if (!isTyping) return;
    try {
      if (chatId.startsWith('dm_')) {
        const user = await this._client.users.fetch(chatId.slice(3));
        const dm = await user.createDM();
        await dm.sendTyping();
      } else {
        const ch = await this._client.channels.fetch(chatId);
        if (ch?.isTextBased()) await ch.sendTyping();
      }
    } catch { /* non-fatal */ }
  }
}

module.exports = { DiscordPlatform };
