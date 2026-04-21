const EventEmitter = require('events');
const db = require('../../db/database');
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const { AGENT_DATA_DIR, DATA_DIR } = require('../../../runtime/paths');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const { WhatsAppPlatform } = require('./whatsapp');
const { TelnyxVoicePlatform } = require('./telnyx');
const { DiscordPlatform } = require('./discord');
const { TelegramPlatform } = require('./telegram');
const { WaveshareWearablePlatform } = require('./waveshare_wearable');
const {
  SlackPlatform,
  GoogleChatPlatform,
  TeamsPlatform,
  MatrixPlatform,
  SignalPlatform,
  LinePlatform,
  MattermostPlatform,
  IrcPlatform,
  BlueBubblesPlatform,
  createGenericPlatformClass,
} = require('./http_platforms');
const { normalizeOutgoingMessageForPlatform } = require('./formatting_guides');

const GENERIC_ALLOWLIST_PLATFORMS = new Set([
  'slack',
  'google_chat',
  'teams',
  'matrix',
  'signal',
  'imessage',
  'bluebubbles',
  'irc',
  'feishu',
  'line',
  'mattermost',
  'nextcloud_talk',
  'nostr',
  'synology_chat',
  'tlon',
  'twitch',
  'zalo',
  'zalo_personal',
  'wechat',
  'webchat',
]);

const LEGACY_WHATSAPP_AUTH_DIR = path.join(DATA_DIR, 'whatsapp-auth');

class IrcMessagingPlatform extends IrcPlatform {
  constructor(config = {}) { super('irc', config); }
}

class TwitchMessagingPlatform extends IrcPlatform {
  constructor(config = {}) { super('twitch', config); }
}

class BlueBubblesMessagingPlatform extends BlueBubblesPlatform {
  constructor(config = {}) { super('bluebubbles', config); }
}

class IMessageMessagingPlatform extends BlueBubblesPlatform {
  constructor(config = {}) { super('imessage', config); }
}

class MessagingManager extends EventEmitter {
  constructor(io, options = {}) {
    super();
    this.io = io;
    this.voiceRuntimeManager = options.voiceRuntimeManager || null;
    this.platforms = new Map();
    this.messageHandlers = [];
    this.isShuttingDown = false;
    this.platformTypes = {
      whatsapp: WhatsAppPlatform,
      telnyx:   TelnyxVoicePlatform,
      discord:  DiscordPlatform,
      telegram: TelegramPlatform,
      slack: SlackPlatform,
      google_chat: GoogleChatPlatform,
      teams: TeamsPlatform,
      matrix: MatrixPlatform,
      signal: SignalPlatform,
      imessage: IMessageMessagingPlatform,
      bluebubbles: BlueBubblesMessagingPlatform,
      irc: IrcMessagingPlatform,
      feishu: createGenericPlatformClass('feishu'),
      line: LinePlatform,
      mattermost: MattermostPlatform,
      waveshare_wearable: WaveshareWearablePlatform,
      nextcloud_talk: createGenericPlatformClass('nextcloud_talk'),
      nostr: createGenericPlatformClass('nostr'),
      synology_chat: createGenericPlatformClass('synology_chat'),
      tlon: createGenericPlatformClass('tlon'),
      twitch: TwitchMessagingPlatform,
      zalo: createGenericPlatformClass('zalo'),
      zalo_personal: createGenericPlatformClass('zalo_personal'),
      wechat: createGenericPlatformClass('wechat'),
      webchat: createGenericPlatformClass('webchat'),
    };
  }

  registerHandler(handler) {
    this.messageHandlers.push(handler);
  }

  async ingestMessage(userId, platformName, msg, options = {}) {
    if (this.isShuttingDown) {
      return null;
    }

    const agentId = this._agentId(userId, {
      ...options,
      agentId: options?.agentId ?? msg?.agentId ?? null,
    });
    const metadata = {
      sender: msg.sender,
      senderName: msg.senderName,
      senderDisplayName: msg.senderDisplayName,
      senderUsername: msg.senderUsername,
      senderTag: msg.senderTag,
      isGroup: msg.isGroup,
      mediaType: msg.mediaType,
      ...(msg.metadata && typeof msg.metadata === 'object' ? msg.metadata : {}),
    };
    db.prepare('INSERT INTO messages (user_id, agent_id, role, content, platform, platform_msg_id, platform_chat_id, metadata, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
      .run(
        userId,
        agentId,
        'user',
        msg.content,
        platformName,
        msg.messageId,
        msg.chatId,
        JSON.stringify(metadata),
        msg.timestamp,
      );

    const enrichedMsg = { ...msg, agentId, platform: platformName };

    if (this.isShuttingDown) {
      return enrichedMsg;
    }

    this.io.to(`user:${userId}`).emit('messaging:message', enrichedMsg);

    for (const handler of this.messageHandlers) {
      if (this.isShuttingDown) {
        break;
      }
      try {
        await handler(userId, enrichedMsg);
      } catch (err) {
        console.error('Message handler error:', err.message);
      }
    }

    return enrichedMsg;
  }

  _agentId(userId, options = {}) {
    return resolveAgentId(userId, options?.agentId || options?.agent_id || null);
  }

  _key(userId, agentId, platformName) {
    return `${userId}:${agentId}:${platformName}`;
  }

  _setting(userId, agentId, key) {
    const agentRow = db.prepare(
      'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?'
    ).get(userId, agentId, key);
    if (agentRow) return agentRow;
    if (!isMainAgent(userId, agentId)) return null;
    return db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
      .get(userId, key);
  }

  _scopedPlatformAuthDir(userId, agentId, platformName) {
    return path.join(
      AGENT_DATA_DIR,
      'messaging-auth',
      String(userId),
      String(agentId || 'main'),
      String(platformName || 'unknown'),
    );
  }

  _maybeMigrateLegacyWhatsAppAuth(scopedAuthDir) {
    if (!fs.existsSync(LEGACY_WHATSAPP_AUTH_DIR) || fs.existsSync(scopedAuthDir)) {
      return;
    }
    try {
      fs.mkdirSync(path.dirname(scopedAuthDir), { recursive: true });
      fs.cpSync(LEGACY_WHATSAPP_AUTH_DIR, scopedAuthDir, {
        recursive: true,
        force: false,
        errorOnExist: false,
      });
    } catch (err) {
      console.warn('[Messaging] Failed to copy legacy WhatsApp auth into agent-scoped storage:', err.message);
    }
  }

  _persistableConfig(value, seen = new WeakSet()) {
    if (value == null) return value;
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'bigint' || typeof value === 'function' || typeof value === 'symbol') {
      return undefined;
    }
    if (value instanceof Date) {
      return value.toISOString();
    }
    if (Array.isArray(value)) {
      return value
        .map((item) => this._persistableConfig(item, seen))
        .filter((item) => item !== undefined);
    }
    if (typeof value === 'object') {
      if (seen.has(value)) {
        return undefined;
      }
      seen.add(value);

      const proto = Object.getPrototypeOf(value);
      const isPlainObject = proto === Object.prototype || proto === null;
      if (!isPlainObject) {
        seen.delete(value);
        return undefined;
      }

      const result = {};
      for (const [key, entryValue] of Object.entries(value)) {
        const normalized = this._persistableConfig(entryValue, seen);
        if (normalized !== undefined) {
          result[key] = normalized;
        }
      }
      seen.delete(value);
      return result;
    }
    return undefined;
  }

  async connectPlatform(userId, platformName, config = {}, options = {}) {
    const agentId = this._agentId(userId, options);
    config = { ...(config || {}) };
    config.userId = userId;
    config.agentId = agentId;
    const PlatformClass = this.platformTypes[platformName];
    if (!PlatformClass) throw new Error(`Unknown platform: ${platformName}`);

    if (platformName === 'whatsapp' && !config.authDir) {
      config.authDir = this._scopedPlatformAuthDir(userId, agentId, platformName);
      this._maybeMigrateLegacyWhatsAppAuth(config.authDir);
    }

    // For Telnyx, inject saved whitelist and voice secret into config before constructing
    if (platformName === 'telnyx') {
      const parseSetting = (row, fallback = null) => {
        if (!row || typeof row.value !== 'string') return fallback;
        try {
          return JSON.parse(row.value);
        } catch {
          return row.value;
        }
      };

      const wlRow = this._setting(userId, agentId, 'platform_whitelist_telnyx');
      if (wlRow) {
        try { config.allowedNumbers = JSON.parse(wlRow.value); } catch { /* ignore */ }
      }
      const secretRow = this._setting(userId, agentId, 'platform_voice_secret_telnyx');
      if (secretRow) {
        try { config.voiceSecret = JSON.parse(secretRow.value); } catch { config.voiceSecret = secretRow.value; }
      }

      const voiceSttProvider = parseSetting(this._setting(userId, agentId, 'voice_stt_provider'));
      const voiceSttModel = parseSetting(this._setting(userId, agentId, 'voice_stt_model'));
      const voiceTtsProvider = parseSetting(this._setting(userId, agentId, 'voice_tts_provider'));
      const voiceTtsModel = parseSetting(this._setting(userId, agentId, 'voice_tts_model'));
      const voiceTtsVoice = parseSetting(this._setting(userId, agentId, 'voice_tts_voice'));

      if (typeof voiceSttProvider === 'string' && voiceSttProvider.trim()) {
        config.sttProvider = voiceSttProvider.trim();
      }
      if (typeof voiceSttModel === 'string' && voiceSttModel.trim()) {
        config.sttModel = voiceSttModel.trim();
      }
      if (typeof voiceTtsProvider === 'string' && voiceTtsProvider.trim()) {
        config.ttsProvider = voiceTtsProvider.trim();
      }
      if (typeof voiceTtsModel === 'string' && voiceTtsModel.trim()) {
        config.ttsModel = voiceTtsModel.trim();
      }
      if (typeof voiceTtsVoice === 'string' && voiceTtsVoice.trim()) {
        config.ttsVoice = voiceTtsVoice.trim();
      }
      config.voiceRuntimeManager = this.voiceRuntimeManager || null;
    }

    // Inject saved allowlists for platforms that enforce access in the adapter.
    if (platformName === 'discord') {
      const wlRow = this._setting(userId, agentId, 'platform_whitelist_discord');
      if (wlRow) {
        try { config.allowedIds = JSON.parse(wlRow.value); } catch { /* ignore */ }
      }
    }

    // For Telegram, inject saved allowedIds whitelist
    if (platformName === 'telegram') {
      const wlRow = this._setting(userId, agentId, 'platform_whitelist_telegram');
      if (wlRow) {
        try { config.allowedIds = JSON.parse(wlRow.value); } catch { /* ignore */ }
      }
    }

    if (GENERIC_ALLOWLIST_PLATFORMS.has(platformName)) {
      const wlRow = this._setting(userId, agentId, `platform_whitelist_${platformName}`);
      if (wlRow) {
        try {
          const parsed = JSON.parse(wlRow.value);
          if (Array.isArray(parsed)) config.allowedIds = parsed;
        } catch { /* ignore */ }
      }
    }

    const storedConfig = JSON.stringify(this._persistableConfig(config) || {});

    const key = this._key(userId, agentId, platformName);
    let platform = this.platforms.get(key);

    if (platform) {
      await platform.disconnect().catch(() => {});
    }

    platform = new PlatformClass(config);
    this.platforms.set(key, platform);
    const currentPlatform = () => this.platforms.get(key) === platform;

    platform.on('qr', (qr) => {
      if (!currentPlatform() || this.isShuttingDown) return;
      this.io.to(`user:${userId}`).emit('messaging:qr', { agentId, platform: platformName, qr });
      db.prepare('UPDATE platform_connections SET status = ?, config = ? WHERE user_id = ? AND agent_id = ? AND platform = ?')
        .run('awaiting_qr', storedConfig, userId, agentId, platformName);
    });

    platform.on('connected', () => {
      if (!currentPlatform() || this.isShuttingDown) return;
      this.io.to(`user:${userId}`).emit('messaging:connected', { agentId, platform: platformName });
      db.prepare('UPDATE platform_connections SET status = ?, last_connected = datetime(\'now\') WHERE user_id = ? AND agent_id = ? AND platform = ?')
        .run('connected', userId, agentId, platformName);
    });

    platform.on('disconnected', (info) => {
      if (!currentPlatform()) return;
      this.io.to(`user:${userId}`).emit('messaging:disconnected', { agentId, platform: platformName, ...info });
      if (!this.isShuttingDown) {
        db.prepare('UPDATE platform_connections SET status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?')
          .run('disconnected', userId, agentId, platformName);
      }
    });

    platform.on('logged_out', () => {
      if (!currentPlatform() || this.isShuttingDown) return;
      this.io.to(`user:${userId}`).emit('messaging:logged_out', { agentId, platform: platformName });
      db.prepare('UPDATE platform_connections SET status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?')
        .run('logged_out', userId, agentId, platformName);
      this.platforms.delete(key);
    });

    // Telnyx-specific: blocked inbound caller notification
    platform.on('blocked_caller', (info) => {
      this.io.to(`user:${userId}`).emit('messaging:blocked_sender', {
        platform: platformName,
        sender: info.caller,
        chatId: info.ccId,
        senderName: null
      });
    });

    // Discord / Telegram: blocked sender notification with suggestions
    platform.on('blocked_sender', (info) => {
      this.io.to(`user:${userId}`).emit('messaging:blocked_sender', {
        platform: platformName,
        sender: info.sender,
        chatId: info.chatId,
        senderName: info.senderName || null,
        meta: info.guildName ? `Server: ${info.guildName}` : (info.groupName ? `Group: ${info.groupName}` : null),
        suggestions: info.suggestions || null,
      });
    });

    platform.on('message', async (msg) => {
      if (this.isShuttingDown) return;
      await this.ingestMessage(userId, platformName, msg, { agentId });
    });

    const existing = db.prepare('SELECT id FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?').get(userId, agentId, platformName);
    if (!existing) {
      db.prepare('INSERT INTO platform_connections (user_id, agent_id, platform, config, status) VALUES (?, ?, ?, ?, ?)')
        .run(userId, agentId, platformName, storedConfig, 'connecting');
    } else {
      db.prepare('UPDATE platform_connections SET config = ?, status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?')
        .run(storedConfig, 'connecting', userId, agentId, platformName);
    }

    await platform.connect();
    return { status: platform.getStatus() };
  }

  async disconnectPlatform(userId, platformName, options = {}) {
    const agentId = this._agentId(userId, options);
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    if (!platform) return { status: 'not_connected' };

    await platform.disconnect();
    this.platforms.delete(key);

    db.prepare('UPDATE platform_connections SET status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?')
      .run('disconnected', userId, agentId, platformName);

    return { status: 'disconnected' };
  }

  async sendMessage(userId, platformName, to, content, mediaPathOrOptions) {
    const agentId = this._agentId(userId, mediaPathOrOptions || {});
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    if (!platform) throw new Error(`Platform ${platformName} not connected`);

    const sendOptions =
      mediaPathOrOptions && typeof mediaPathOrOptions === 'object' && !Array.isArray(mediaPathOrOptions)
        ? mediaPathOrOptions
        : { mediaPath: mediaPathOrOptions };
    const mediaPath = sendOptions.mediaPath || null;
    const runId = sendOptions.runId || null;
    const persistConversation = sendOptions.persistConversation === true;
    const metadata = sendOptions.metadata && typeof sendOptions.metadata === 'object'
      ? sendOptions.metadata
      : null;
    const deliveryKind = sendOptions.deliveryKind || 'final';
    const normalizedContent = normalizeOutgoingMessageForPlatform(platformName, content, {
      stripNoResponseMarker: false
    });

    // Sentinel: agent can choose not to reply by sending [NO RESPONSE]
    if (!mediaPath && typeof normalizedContent === 'string' && normalizedContent.toUpperCase() === '[NO RESPONSE]') {
      return { success: true, suppressed: true };
    }

    const result = await platform.sendMessage(to, normalizedContent, sendOptions);

    db.prepare('INSERT INTO messages (user_id, agent_id, run_id, role, content, platform, platform_chat_id, media_path, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
      .run(userId, agentId, runId, 'assistant', normalizedContent, platformName, to, mediaPath, metadata ? JSON.stringify(metadata) : null);

    if (persistConversation) {
      const conversationId = this.getOrCreateConversation(userId, platformName, to, { agentId });
      db.prepare('INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)')
        .run(conversationId, 'assistant', normalizedContent);
      db.prepare("UPDATE conversations SET updated_at = datetime('now') WHERE id = ?")
        .run(conversationId);
    }

    // Notify the web UI so the sent message appears in chat
    this.io.to(`user:${userId}`).emit('messaging:sent', {
      platform: platformName,
      agentId,
      to,
      content: normalizedContent,
      mediaPath,
      runId,
      deliveryKind,
      metadata,
    });

    this.emit('message_sent', {
      userId,
      agentId,
      platform: platformName,
      to,
      content: normalizedContent,
      mediaPath,
      runId,
      deliveryKind,
      metadata,
      result
    });

    return { success: true, result };
  }

  getOrCreateConversation(userId, platformName, chatId, options = {}) {
    const agentId = this._agentId(userId, options);
    let conversation = db
      .prepare('SELECT id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id = ?')
      .get(userId, agentId, platformName, chatId);

    if (conversation) {
      return conversation.id;
    }

    const conversationId = randomUUID();
    db.prepare(
      'INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(
      conversationId,
      userId,
      agentId,
      platformName,
      chatId,
      `${platformName} — ${chatId}`
    );

    return conversationId;
  }

  getPlatformStatus(userId, platformName, options = {}) {
    const agentId = this._agentId(userId, options);
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    if (!platform) {
      const conn = db.prepare('SELECT status FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?').get(userId, agentId, platformName);
      return { status: conn?.status || 'not_configured' };
    }
    return {
      status: platform.getStatus(),
      authInfo: platform.getAuthInfo()
    };
  }

  getAllStatuses(userId, options = {}) {
    const agentId = this._agentId(userId, options);
    const connections = db.prepare('SELECT platform, status, last_connected, agent_id FROM platform_connections WHERE user_id = ? AND agent_id = ?').all(userId, agentId);
    const statuses = {};

    for (const conn of connections) {
      const key = this._key(userId, agentId, conn.platform);
      const platform = this.platforms.get(key);
      statuses[conn.platform] = {
        status: platform ? platform.getStatus() : conn.status,
        agentId,
        lastConnected: conn.last_connected,
        authInfo: platform?.getAuthInfo() || null
      };
    }

    return statuses;
  }

  getPlatformDevices(userId, platformName, options = {}) {
    const agentId = this._agentId(userId, options);
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    if (!platform || typeof platform.listDevices !== 'function') return [];
    return platform.listDevices(userId, { agentId });
  }

  async logoutPlatform(userId, platformName, options = {}) {
    const agentId = this._agentId(userId, options);
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    const row = db.prepare(
      'SELECT config FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?'
    ).get(userId, agentId, platformName);
    let reconnectConfig = null;
    if (platformName === 'whatsapp') {
      reconnectConfig = platform?.config || {};
      if ((!reconnectConfig || Object.keys(reconnectConfig).length === 0) && row?.config) {
        try {
          reconnectConfig = JSON.parse(row.config);
        } catch {
          reconnectConfig = {};
        }
      }
    }
    if (platform && platform.logout) {
      await platform.logout();
    }
    this.platforms.delete(key);
    db.prepare('DELETE FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?').run(userId, agentId, platformName);
    if (platformName === 'whatsapp') {
      return this.connectPlatform(userId, platformName, reconnectConfig || {}, { agentId });
    }
    return { status: 'logged_out' };
  }

  async restoreConnections() {
    this.isShuttingDown = false;
    const rows = db.prepare(
      "SELECT user_id, agent_id, platform, config FROM platform_connections WHERE status IN ('connected', 'awaiting_qr')"
    ).all();
    for (const row of rows) {
      try {
        const config = row.config ? JSON.parse(row.config) : {};
        console.log(`[Messaging] Restoring ${row.platform} for user ${row.user_id} agent ${row.agent_id || 'main'}`);
        await this.connectPlatform(row.user_id, row.platform, config, { agentId: row.agent_id });
      } catch (err) {
        console.error(`[Messaging] Failed to restore ${row.platform} for user ${row.user_id}:`, err.message);
        db.prepare("UPDATE platform_connections SET status = 'disconnected' WHERE user_id = ? AND agent_id = ? AND platform = ?")
          .run(row.user_id, row.agent_id, row.platform);
      }
    }
  }

  async shutdown() {
    this.isShuttingDown = true;

    const tasks = [];
    for (const platform of this.platforms.values()) {
      if (typeof platform.disconnect === 'function') {
        tasks.push(platform.disconnect().catch(() => {}));
      }
    }

    await Promise.allSettled(tasks);
    this.platforms.clear();
  }

  async makeCall(userId, to, greeting, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), 'telnyx');
    const platform = this.platforms.get(key);
    if (!platform) throw new Error('Telnyx Voice is not connected');
    if (!platform.initiateCall) throw new Error('Telnyx platform does not support outbound calls');
    const result = await platform.initiateCall(to, greeting);
    this.io.to(`user:${userId}`).emit('messaging:call_initiated', { platform: 'telnyx', to, callControlId: result.callControlId });
    return { success: true, ...result };
  }

  async markRead(userId, platformName, chatId, messageId, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), platformName);
    const platform = this.platforms.get(key);
    if (!platform?.markRead) return;
    return platform.markRead(chatId, messageId);
  }

  async sendTyping(userId, platformName, chatId, isTyping, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), platformName);
    const platform = this.platforms.get(key);
    if (!platform?.sendTyping) return;
    return platform.sendTyping(chatId, isTyping);
  }

  /**
   * Route a raw Telnyx webhook event to the correct user's platform instance.
   * We find the Telnyx platform instance that owns this call_control_id, or fall
   * back to the first connected Telnyx instance.
   */
  async handleTelnyxWebhook(event) {
    for (const [, platform] of this.platforms.entries()) {
      if (platform.name === 'telnyx' && typeof platform.matchesWebhookEvent === 'function' && platform.matchesWebhookEvent(event)) {
        await platform.handleWebhook(event);
        return true;
      }
    }
    return false;
  }

  /**
   * Route generic platform webhooks to the connected instance that can verify
   * the request. This backs Slack Events, Google Chat app callbacks, Teams
   * outgoing webhooks, and configurable webhook channels.
   */
  async handlePlatformWebhook(platformName, req) {
    let forbidden = false;
    for (const [, platform] of this.platforms.entries()) {
      if (platform.name !== platformName || typeof platform.handleWebhook !== 'function') continue;
      const result = await platform.handleWebhook(req);
      if (result?.handled) return result;
      if (result?.status === 403) forbidden = true;
    }
    return {
      handled: false,
      status: forbidden ? 403 : 404,
      body: forbidden ? 'Forbidden' : 'No connected platform handled this webhook',
    };
  }

  /**
   * Update the allowed-numbers list on a live Telnyx platform instance.
   */
  updateTelnyxAllowedNumbers(userId, numbers, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), 'telnyx');
    const platform = this.platforms.get(key);
    if (platform?.setAllowedNumbers) platform.setAllowedNumbers(numbers);
  }

  /**
   * Update the voice secret code on a live Telnyx platform instance.
   */
  updateTelnyxVoiceSecret(userId, secret, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), 'telnyx');
    const platform = this.platforms.get(key);
    if (platform?.setVoiceSecret) platform.setVoiceSecret(secret);
  }

  updateVoiceSettings(userId, voiceSettings = {}, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), 'telnyx');
    const platform = this.platforms.get(key);
    if (platform?.setVoiceConfig) {
      platform.setVoiceConfig(voiceSettings);
    }
  }

  /**
   * Update the allowed-entries list on a live Discord platform instance.
   * Accepts prefixed strings: "user:ID", "guild:ID", "channel:ID"
   */
  updateDiscordAllowedIds(userId, ids, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), 'discord');
    const platform = this.platforms.get(key);
    if (platform?.setAllowedEntries) platform.setAllowedEntries(ids);
    else if (platform?.setAllowedIds) platform.setAllowedIds(ids); // legacy fallback
  }

  /**
   * Update the allowed-entries list on a live Telegram platform instance.
   * Accepts prefixed strings: "user:ID", "group:ID"
   */
  updateTelegramAllowedIds(userId, ids, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), 'telegram');
    const platform = this.platforms.get(key);
    if (platform?.setAllowedEntries) platform.setAllowedEntries(ids);
  }

  updateAllowedEntries(userId, platformName, ids, options = {}) {
    const key = this._key(userId, this._agentId(userId, options), platformName);
    const platform = this.platforms.get(key);
    if (platform?.setAllowedEntries) platform.setAllowedEntries(ids);
  }
}

module.exports = { MessagingManager };
