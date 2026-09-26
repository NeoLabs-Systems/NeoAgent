'use strict';

const { BasePlatform } = require('./base');
const {
  Client,
  GatewayIntentBits,
  Partials,
  ChannelType,
  MessageFlags,
} = require('discord.js');
const { fetchResponseBuffer } = require('../network/http');
const { fileExtensionForMimeType } = require('../voice/liveAudio');
const { createServiceLogger } = require('../../utils/logger');

const log = createServiceLogger('Discord');
const MAX_AUDIO_ATTACHMENT_BYTES = 25 * 1024 * 1024;

const FATAL_DISCORD_CLOSE_CODES = new Set([4004, 4010, 4011, 4012, 4013, 4014]);

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
    this.artifactStore = config.artifactStore || null;
    this.userId = config.userId;
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
        GatewayIntentBits.DirectMessageReactions,
      ],
      partials: [Partials.Channel, Partials.Message, Partials.Reaction, Partials.User],
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
        const code = event?.code || null;
        const fatal = FATAL_DISCORD_CLOSE_CODES.has(code);
        this.status = 'disconnected';
        console.warn(`[Discord] Shard ${shardId} disconnected (${code || 'unknown'})`);
        this.emit('disconnected', {
          manual: false,
          willReconnect: !fatal,
          requiresUserAction: fatal,
          shardId,
          code,
          reason: event?.reason || (fatal ? 'authentication_required' : null),
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
      this._client.on('messageReactionAdd', (reaction, user) => {
        this._handleReaction(reaction, user).catch((err) => {
          console.error('[Discord] Reaction handler error:', err.message);
        });
      });

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

  // ── Reaction handler ───────────────────────────────────────────────────────

  // A reaction is feedback on an earlier message, not a request: it is recorded
  // for context and never starts a run. Direct messages only, and access is
  // checked quietly so a stranger's reaction raises nothing.
  async _handleReaction(reaction, user) {
    if (user.bot) return;
    const full = reaction.partial ? await reaction.fetch() : reaction;
    if (full.message.channel?.type !== ChannelType.DM) return;
    const access = this.evaluateAccess({
      platform: 'discord',
      senderId: user.id,
      chatId: `dm_${user.id}`,
      isDirect: true,
      isShared: false,
      groupId: '',
      channelId: '',
      serverId: '',
      roomId: '',
      roleIds: [],
      phoneNumber: '',
      wasMentioned: false,
    });
    if (!access.allowed) return;
    this.emit('reaction', {
      platform: 'discord',
      chatId: `dm_${user.id}`,
      sender: user.id,
      senderName: user.globalName || user.username || user.id,
      targetMessageId: full.message.id,
      emoji: full.emoji.toString(),
      timestamp: new Date().toISOString(),
    });
  }

  // ── Message handler ────────────────────────────────────────────────────────

  async _handleMessage(message) {
    if (message.author.bot) return;

    const isDM = message.channel.type === ChannelType.DM;
    const userId = message.author.id;
    const guildId = message.guildId || null;
    const channelId = message.channelId;
    const chatId = isDM ? `dm_${userId}` : channelId;

    const access = this._checkInboundAccess({
      platform: 'discord',
      senderId: userId,
      chatId,
      isDirect: isDM,
      isShared: !isDM,
      groupId: !isDM ? channelId : '',
      channelId: !isDM ? channelId : '',
      serverId: guildId || '',
      roleIds: !isDM && message.member ? [...message.member.roles.cache.keys()] : [],
      phoneNumber: '',
      wasMentioned: isDM ? false : this._isMentioned(message),
    }, {
      senderName: message.author.username || null,
      meta: message.guild?.name ? `Server: ${message.guild.name}` : '',
      serverLabel: message.guild?.name || '',
      channelLabel: !isDM ? `#${message.channel.name || channelId}` : '',
    });

    if (!access.allowed) {
      return;
    }

    let content = (!isDM && this._isMentioned(message)) ? this._stripMention(message.content) : (message.content || '');
    const attachments = [...message.attachments.values()];
    const audioAttachment = attachments.find((a) => String(a.contentType || '').startsWith('audio/'));
    const audio = audioAttachment ? await this._storeAudioAttachment(message, audioAttachment) : null;
    const otherUrls = attachments
      .filter((a) => !audio || a !== audioAttachment)
      .map((a) => a.url);
    if (otherUrls.length) {
      content += (content ? '\n' : '') + `[Attachment: ${otherUrls.join(', ')}]`;
    }
    if (!content && !audio) return;

    const senderUsername = message.author.username || null;
    const senderTag = message.author.tag || senderUsername || userId;
    const senderDisplayName = isDM
      ? (message.author.globalName || senderUsername || userId)
      : (message.member?.displayName || message.author.globalName || senderUsername || userId);
    const senderName = isDM
      ? senderDisplayName
      : `${senderDisplayName} in #${message.channel.name || channelId}${message.guild ? ` (${message.guild.name})` : ''}`;

    // Fetch recent channel history for context on guild/channel mentions
    const channelContext = !isDM ? await this._fetchContext(message.channel, 20) : null;
    const repliedToAgent = !isDM
      && message.reference?.messageId
      && message.mentions?.repliedUser?.id === this._botUser?.id;

    this.emit('message', {
      platform: 'discord',
      chatId,
      sender: userId,
      senderName,
      senderDisplayName,
      senderUsername,
      senderTag,
      guildId,
      serverId: guildId,
      groupId: isDM ? null : channelId,
      channelId: isDM ? null : channelId,
      roleIds: !isDM && message.member ? [...message.member.roles.cache.keys()] : [],
      wasMentioned: !isDM && this._isMentioned(message),
      repliedToAgent: Boolean(repliedToAgent),
      botUsername: this._botUser?.username || null,
      botDisplayName: this._botUser?.globalName
        || this._botUser?.displayName
        || this._botUser?.username
        || null,
      botTag: this._botUser?.tag || null,
      replyToMessageId: message.reference?.messageId || null,
      content,
      mediaType: audio ? 'audio' : null,
      localMediaPath: audio?.filePath || null,
      voiceNote: audio?.voiceNote || null,
      isGroup: !isDM,
      messageId: message.id,
      timestamp: message.createdAt.toISOString(),
      channelContext,
      channelName: isDM ? null : (message.channel.name || channelId),
      guildName: message.guild?.name || null,
    });
  }

  // Voice messages and uploaded audio files feed the shared voice-note flow,
  // so the clip is downloaded once and kept as inbound media.
  async _storeAudioAttachment(message, attachment) {
    if (!this.artifactStore || !this.userId) return null;
    try {
      const { response, body } = await fetchResponseBuffer(attachment.url, {
        serviceName: 'Discord attachment',
        maxResponseBytes: MAX_AUDIO_ATTACHMENT_BYTES,
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const mimeType = String(attachment.contentType).split(';')[0];
      const artifact = await this.artifactStore.createBufferArtifact(this.userId, {
        kind: 'messaging-inbound-media',
        filenameBase: `${Date.now()}_${attachment.id}`,
        extension: fileExtensionForMimeType(mimeType),
        contentType: mimeType,
        content: body,
        metadata: { platform: 'discord', mediaType: 'audio', messageId: message.id },
      });
      const isVoiceMessage = message.flags?.has(MessageFlags.IsVoiceMessage) === true;
      return {
        filePath: artifact.filePath,
        voiceNote: {
          source: isVoiceMessage ? 'discord_voice_message' : 'discord_audio_file',
          durationSec: Number(attachment.duration) || null,
        },
      };
    } catch (error) {
      log.error('Audio attachment download failed:', error.message);
      return null;
    }
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  /**
   * to: "dm_<userId>" for DMs, or a channel snowflake for guild channels
   */
  async sendMessage(to, content, _options = {}) {
    if (!this._client || this.status !== 'connected') throw new Error('Discord not connected');

    const channel = await this._textChannel(to);
    const sent = await channel.send({ content });
    return { success: true, messageId: sent?.id || null };
  }

  async sendReaction(chatId, messageId, emoji) {
    if (!this._client || this.status !== 'connected') throw new Error('Discord not connected');
    const channel = await this._textChannel(chatId);
    const message = await channel.messages.fetch(messageId);
    await message.react(emoji);
    return { success: true };
  }

  async _textChannel(chatId) {
    if (chatId.startsWith('dm_')) {
      const user = await this._client.users.fetch(chatId.slice(3));
      return user.createDM();
    }
    const channel = await this._client.channels.fetch(chatId);
    if (!channel?.isTextBased()) throw new Error(`Channel ${chatId} is not text-based`);
    return channel;
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

  async listAccessTargets() {
    if (!this._client || this.status !== 'connected') return [];
    const targets = [];
    for (const guild of this._client.guilds.cache.values()) {
      targets.push({
        source: 'live',
        bucket: 'sharedSpaceRules',
        scope: 'server',
        value: guild.id,
        label: guild.name || guild.id,
        subtitle: 'Discord server',
      });
      const channels = guild.channels?.cache?.values?.() || [];
      for (const channel of channels) {
        if (!channel?.isTextBased?.() || channel.type === ChannelType.DM) continue;
        targets.push({
          source: 'live',
          bucket: 'sharedSpaceRules',
          scope: 'channel',
          value: channel.id,
          label: `#${channel.name || channel.id}`,
          subtitle: guild.name || 'Discord channel',
        });
      }
      const roles = guild.roles?.cache?.values?.() || [];
      for (const role of roles) {
        if (!role || role.managed || role.name === '@everyone') continue;
        targets.push({
          source: 'live',
          bucket: 'sharedActorRules',
          scope: 'role',
          value: role.id,
          label: role.name || role.id,
          subtitle: guild.name || 'Discord role',
        });
      }
    }
    const channels = this._client.channels?.cache?.values?.() || [];
    for (const channel of channels) {
      if (channel?.type !== ChannelType.DM) continue;
      const recipient = channel.recipient;
      const userId = String(recipient?.id || '').trim();
      if (!userId) continue;
      targets.push({
        source: 'live',
        bucket: 'directRules',
        scope: 'user',
        value: userId,
        label: recipient.globalName || recipient.username || 'Private chat',
        subtitle: 'Discord private chat',
      });
    }
    return targets;
  }
}

module.exports = { DiscordPlatform };
