'use strict';

const { BasePlatform } = require('./base');
const {
  Client,
  GatewayIntentBits,
  Partials,
  ChannelType,
} = require('discord.js');

/**
 * Discord platform — supports guild (server) channels and DMs.
 *
 * chatId convention:
 *   DMs:             "dm_<userId>"
 *   Guild channels:  "<channelId>"   (plain snowflake)
 *
 * sendMessage `to` follows the same convention.
 *
 * Whitelist entries are Discord user snowflakes or guild snowflakes.
 * Anything not in the whitelist fires a `blocked_sender` event (the same
 * "Add to whitelist" banner the user sees for WhatsApp/Telnyx).
 */
class DiscordPlatform extends BasePlatform {
  constructor(config = {}) {
    super('discord', config);
    this.supportsGroups = true;
    this.supportsMedia  = false; // text-only for now

    this.token          = config.token || '';
    this.allowedIds     = Array.isArray(config.allowedIds) ? config.allowedIds : [];

    this._client = null;
    this._botUser = null;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  async connect() {
    if (!this.token) throw new Error('Discord bot token is required');

    // Clean up any previous client instance
    if (this._client) {
      try { this._client.destroy(); } catch {}
      this._client = null;
    }

    this._client = new Client({
      intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,   // Privileged intent — must be enabled in Dev Portal
        GatewayIntentBits.DirectMessages,
      ],
      partials: [
        Partials.Channel,   // Required for DM channels to be received
        Partials.Message,
      ],
    });

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Discord login timed out after 20 s'));
      }, 20000);

      this._client.once('ready', () => {
        clearTimeout(timeout);
        this._botUser = this._client.user;
        this.status = 'connected';
        console.log(`[Discord] Logged in as ${this._botUser.tag}`);
        this.emit('connected');
        resolve({ status: 'connected' });
      });

      this._client.once('error', (err) => {
        clearTimeout(timeout);
        reject(err);
      });

      this._client.on('error', (err) => {
        console.error('[Discord] Client error:', err.message);
      });

      this._client.on('messageCreate', (message) => {
        this._handleMessage(message);
      });

      this._client.login(this.token).catch((err) => {
        clearTimeout(timeout);
        reject(err);
      });
    });
  }

  async disconnect() {
    if (this._client) {
      try { this._client.destroy(); } catch {}
      this._client = null;
    }
    this.status = 'disconnected';
    this._botUser = null;
    this.emit('disconnected', { manual: true });
  }

  async logout() {
    await this.disconnect();
  }

  getStatus() { return this.status; }

  getAuthInfo() {
    return this._botUser ? { tag: this._botUser.tag, id: this._botUser.id } : null;
  }

  // ── Whitelist ──────────────────────────────────────────────────────────────

  setAllowedIds(ids) {
    this.allowedIds = Array.isArray(ids) ? ids : [];
    console.log(`[Discord] Whitelist updated: ${this.allowedIds.length} entry(ies)`);
  }

  _isAllowed(userId, guildId) {
    if (!this.allowedIds || !this.allowedIds.length) return true;
    return this.allowedIds.includes(userId) || !!(guildId && this.allowedIds.includes(guildId));
  }

  // ── Message handler ────────────────────────────────────────────────────────

  _handleMessage(message) {
    // Ignore own messages
    if (message.author.bot) return;

    const isDM    = message.channel.type === ChannelType.DM;
    const isGuild = !isDM;
    const userId  = message.author.id;
    const guildId = message.guildId || null;

    // Whitelist check — fires blocked_sender so the UI shows the "Add" popup
    if (!this._isAllowed(userId, guildId)) {
      const blockId = isDM ? `dm_${userId}` : userId;
      console.log(`[Discord] Blocked message from user=${userId} guild=${guildId}`);
      this.emit('blocked_sender', {
        sender:     blockId,
        chatId:     isDM ? `dm_${userId}` : message.channelId,
        senderName: message.author.username,
        guildName:  message.guild?.name || null,
      });
      return;
    }

    const chatId     = isDM ? `dm_${userId}` : message.channelId;
    const senderName = isGuild
      ? `${message.member?.displayName || message.author.username} (${message.guild?.name})`
      : message.author.username;

    let content = message.content || '';
    // Include any attachments as descriptive text
    if (message.attachments.size > 0) {
      const urls = [...message.attachments.values()].map(a => a.url).join(', ');
      content += (content ? '\n' : '') + `[Attachment: ${urls}]`;
    }
    if (!content) return;

    this.emit('message', {
      platform:   'discord',
      chatId,
      sender:     userId,
      senderName,
      content,
      mediaType:  null,
      isGroup:    isGuild,
      messageId:  message.id,
      timestamp:  message.createdAt.toISOString(),
    });
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  /**
   * `to` is either:
   *   "dm_<userId>"   → send DM to that user
   *   "<channelId>"   → send to that guild channel
   */
  async sendMessage(to, content, _options = {}) {
    if (!this._client || this.status !== 'connected') {
      throw new Error('Discord not connected');
    }

    if (to.startsWith('dm_')) {
      const userId = to.slice(3);
      const user   = await this._client.users.fetch(userId);
      const dm     = await user.createDM();
      await dm.send({ content });
    } else {
      const channel = await this._client.channels.fetch(to);
      if (!channel?.isTextBased()) throw new Error(`Channel ${to} is not text-based`);
      await channel.send({ content });
    }

    return { success: true };
  }

  async sendTyping(chatId, _isTyping) {
    if (!this._client || this.status !== 'connected') return;
    try {
      if (chatId.startsWith('dm_')) {
        const userId = chatId.slice(3);
        const user   = await this._client.users.fetch(userId);
        const dm     = await user.createDM();
        await dm.sendTyping();
      } else {
        const channel = await this._client.channels.fetch(chatId);
        if (channel?.isTextBased()) await channel.sendTyping();
      }
    } catch { /* non-fatal */ }
  }
}

module.exports = { DiscordPlatform };
