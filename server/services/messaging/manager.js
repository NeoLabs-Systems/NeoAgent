'use strict';

const EventEmitter = require('events');
const db = require('../../db/database');
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const { AGENT_DATA_DIR, DATA_DIR } = require('../../../runtime/paths');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const { WhatsAppPlatform } = require('./whatsapp');
const { DiscordPlatform } = require('./discord');
const { TelegramPlatform } = require('./telegram');
const { MeshtasticPlatform } = require('./meshtastic');
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
const {
  accessPolicyKey,
  legacyWhitelistKey,
  getPlatformAccessCapabilities,
  normalizeAccessPolicy,
  migrateLegacyWhitelist,
  parseStoredAccessPolicy,
  evaluateAccessPolicy,
  summarizeAccessPolicy,
  classifyRecentTarget,
} = require('./access_policy');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { readMeshtasticEnabled } = require('./meshtastic_env');
const {
  createLinkedAbortController,
  isAbortError,
  throwIfAborted,
} = require('../../utils/abort');
const { waitForAbortableResult, waitForBoundedResult } = require('../network/http');
const { resolveUserFileReference } = require('../files/user_file_access');
const {
  claimInboundJob,
  enqueueInboundMessage,
  listPendingInboundJobs,
  payloadForInboundJob,
  reconcileInterruptedInboundJobs,
  settleInboundJob,
} = require('./inbound_store');

const LEGACY_WHATSAPP_AUTH_DIR = path.join(DATA_DIR, 'whatsapp-auth');
const MESSAGING_OPERATION_TIMEOUT_MS = 60000;

function messagingShutdownError() {
  const error = new Error('Messaging is shutting down and cannot accept new work.');
  error.name = 'AbortError';
  error.code = 'MESSAGING_SHUTTING_DOWN';
  return error;
}

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
    this.artifactStore = options.artifactStore || null;
    this.workspaceManager = options.workspaceManager || null;
    this.platforms = new Map();
    this.accessSuggestions = new Map();
    this.messageHandlers = [];
    this.isShuttingDown = false;
    this.shutdownPromise = null;
    this.lifecycleAbortController = new AbortController();
    this.activeOperations = new Set();
    this.activeInboundJobs = new Set();
    this.activeInboundRecoveries = new Map();
    this.inboundJobsReconciled = false;
    this.platformTypes = {
      whatsapp: WhatsAppPlatform,
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
      meshtastic: MeshtasticPlatform,
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
    if (this.isShuttingDown) return false;
    if (!this.messageHandlers.includes(handler)) {
      this.messageHandlers.push(handler);
    }
    return true;
  }

  _assertRunning() {
    if (this.isShuttingDown || this.lifecycleAbortController.signal.aborted) {
      throw messagingShutdownError();
    }
  }

  async _runOperation(options, serviceName, operation, timeoutMs = MESSAGING_OPERATION_TIMEOUT_MS) {
    this._assertRunning();
    const timeoutController = new AbortController();
    const linked = createLinkedAbortController([
      options?.signal,
      this.lifecycleAbortController.signal,
      timeoutController.signal,
    ]);
    throwIfAborted(linked.signal, `${serviceName} aborted.`);
    const timer = setTimeout(() => {
      const error = new Error(`${serviceName} timed out after ${timeoutMs}ms.`);
      error.code = 'MESSAGING_TIMEOUT';
      timeoutController.abort(error);
    }, timeoutMs);

    const operationPromise = waitForAbortableResult(
      Promise.resolve().then(() => operation(linked.signal)),
      linked.signal,
      `${serviceName} aborted.`,
    );
    this.activeOperations.add(operationPromise);
    const cleanupOperation = () => this.activeOperations.delete(operationPromise);
    operationPromise.then(cleanupOperation, cleanupOperation);
    try {
      return await operationPromise;
    } finally {
      clearTimeout(timer);
      linked.cleanup();
    }
  }

  async ingestMessage(userId, platformName, msg, options = {}) {
    if (this.isShuttingDown) {
      return null;
    }

    const normalizedIncomingContent = normalizeOutgoingMessageForPlatform(platformName, msg?.content, {
      stripNoResponseMarker: false
    });
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
      wasMentioned: msg.wasMentioned === true,
      repliedToAgent: msg.repliedToAgent === true,
      groupId: msg.groupId || null,
      groupName: msg.groupName || null,
      channelId: msg.channelId || null,
      channelName: msg.channelName || null,
      serverId: msg.serverId || msg.guildId || null,
      serverName: msg.serverName || msg.guildName || null,
      roomId: msg.roomId || null,
      roomName: msg.roomName || null,
      roleIds: Array.isArray(msg.roleIds) ? msg.roleIds.map(String) : [],
      mediaType: msg.mediaType,
      localMediaPath: msg.localMediaPath || null,
      ...(msg.metadata && typeof msg.metadata === 'object' ? msg.metadata : {}),
    };
    const enrichedMsg = {
      agentId,
      platform: platformName,
      chatId: msg.chatId,
      messageId: msg.messageId || null,
      sender: msg.sender,
      senderName: msg.senderName || null,
      senderDisplayName: msg.senderDisplayName || null,
      senderUsername: msg.senderUsername || null,
      senderTag: msg.senderTag || null,
      wasMentioned: msg.wasMentioned === true,
      repliedToAgent: msg.repliedToAgent === true,
      content: normalizedIncomingContent,
      mediaType: msg.mediaType || null,
      localMediaPath: msg.localMediaPath || null,
      isGroup: msg.isGroup === true,
      timestamp: msg.timestamp || new Date().toISOString(),
      channelContext: Array.isArray(msg.channelContext) ? msg.channelContext.slice(-20) : null,
      channelName: msg.channelName || null,
      groupName: msg.groupName || null,
      guildName: msg.guildName || null,
      roomName: msg.roomName || null,
      groupId: msg.groupId || null,
      channelId: msg.channelId || null,
      serverId: msg.serverId || msg.guildId || null,
      guildId: msg.guildId || msg.serverId || null,
      roomId: msg.roomId || null,
      roleIds: Array.isArray(msg.roleIds) ? msg.roleIds.map(String) : [],
      replyToMessageId: msg.replyToMessageId || null,
      threadId: msg.threadId || msg.threadTs || null,
      eventType: msg.eventType || 'message',
      metadata: msg.metadata && typeof msg.metadata === 'object' ? msg.metadata : null,
    };
    const queued = enqueueInboundMessage({
      userId,
      agentId,
      platform: platformName,
      platformMessageId: msg.messageId || null,
      chatId: msg.chatId,
      content: normalizedIncomingContent,
      metadata,
      createdAt: enrichedMsg.timestamp,
      payload: enrichedMsg,
    });
    const durableMessage = queued.payload || payloadForInboundJob(queued.job) || enrichedMsg;

    if (this.isShuttingDown) {
      return durableMessage;
    }

    if (queued.created) {
      this.io.to(`user:${userId}`).emit('messaging:message', durableMessage);
    } else if (!queued.job) {
      console.warn(
        `[Messaging] Duplicate ${platformName} message for user ${userId} predates durable processing state; skipping replay`,
      );
      return durableMessage;
    } else if (queued.job.status !== 'pending') {
      console.warn(
        `[Messaging] Duplicate ${platformName} message for user ${userId} has durable status ${queued.job.status}; skipping replay`,
      );
      return durableMessage;
    }

    await this._processInboundJob(queued.job, durableMessage);
    return durableMessage;
  }

  async _processInboundJob(job, payload) {
    if (this.isShuttingDown || !job || this.messageHandlers.length === 0) return false;
    if (!claimInboundJob(job.id)) return false;
    let finishTracking;
    const tracked = new Promise((resolve) => {
      finishTracking = resolve;
    });
    this.activeInboundJobs.add(tracked);

    let status = 'completed';
    let failure = null;
    let runId = null;
    try {
      for (const handler of this.messageHandlers) {
        if (this.isShuttingDown) {
          status = 'pending';
          break;
        }
        let handlerResult = await handler(job.user_id, payload);
        if (handlerResult?.completion) handlerResult = await handlerResult.completion;
        const outcome = handlerResult?.outcome || handlerResult || {};
        runId = outcome.runId || runId;
        if (outcome.cancelled === true) {
          status = runId ? 'failed' : 'pending';
          failure = runId
            ? 'The server stopped after this inbound agent run began; it will not be replayed automatically.'
            : null;
          break;
        }
        if (outcome.error) {
          status = 'failed';
          failure = outcome.error;
          break;
        }
      }
    } catch (error) {
      const cancelled = this.isShuttingDown
        || isAbortError(error, this.lifecycleAbortController.signal);
      status = cancelled && !runId ? 'pending' : 'failed';
      failure = status === 'failed' ? error : null;
      if (!cancelled) {
        console.error('[Messaging] Inbound message handler failed:', error?.message || error);
      }
    }

    try {
      settleInboundJob(job.id, status, failure?.message || failure || null);
      return status === 'completed';
    } finally {
      finishTracking();
      this.activeInboundJobs.delete(tracked);
    }
  }

  _platformReadyForInboundJob(job) {
    const platform = this.platforms.get(this._key(job.user_id, job.agent_id, job.platform));
    if (!platform) return false;
    try {
      return String(platform.getStatus?.() || platform.status || '').toLowerCase() === 'connected';
    } catch {
      return false;
    }
  }

  recoverPendingInbound(filters = {}) {
    if (this.isShuttingDown || this.messageHandlers.length === 0) {
      return Promise.resolve({ recovered: 0, skipped: 0 });
    }
    const key = JSON.stringify({
      userId: filters.userId,
      agentId: filters.agentId,
      platform: filters.platform,
    });
    if (this.activeInboundRecoveries.has(key)) return this.activeInboundRecoveries.get(key);

    const recovery = Promise.resolve().then(async () => {
      if (!this.inboundJobsReconciled) {
        reconcileInterruptedInboundJobs();
        this.inboundJobsReconciled = true;
      }
      let recovered = 0;
      let skipped = 0;
      for (const job of listPendingInboundJobs(filters)) {
        if (this.isShuttingDown) break;
        if (!this._platformReadyForInboundJob(job)) {
          skipped += 1;
          continue;
        }
        const payload = payloadForInboundJob(job);
        if (!payload) {
          settleInboundJob(job.id, 'failed', 'Stored inbound message payload is invalid.');
          continue;
        }
        if (await this._processInboundJob(job, payload)) recovered += 1;
      }
      return { recovered, skipped };
    }).finally(() => {
      if (this.activeInboundRecoveries.get(key) === recovery) {
        this.activeInboundRecoveries.delete(key);
      }
    });
    this.activeInboundRecoveries.set(key, recovery);
    return recovery;
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

  _upsertSetting(userId, agentId, key, value) {
    db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
    ).run(userId, agentId, key, JSON.stringify(value));
  }

  _accessSuggestionKey(userId, agentId, platformName) {
    return `${userId}:${agentId}:${platformName}:access-suggestions`;
  }

  _rememberAccessSuggestions(userId, agentId, platformName, suggestions = []) {
    if (!Array.isArray(suggestions) || suggestions.length === 0) return;
    const key = this._accessSuggestionKey(userId, agentId, platformName);
    const existing = this.accessSuggestions.get(key) || [];
    const merged = [...suggestions, ...existing].filter((item) => item && item.rule && item.bucket);
    const unique = [];
    const seen = new Set();
    for (const item of merged) {
      const id = [
        item.bucket,
        item.rule.scope,
        item.rule.value,
        item.rule.spaceScope || '',
        item.rule.spaceValue || '',
      ].join(':');
      if (seen.has(id)) continue;
      seen.add(id);
      unique.push(item);
      if (unique.length >= 24) break;
    }
    this.accessSuggestions.set(key, unique);
  }

  _loadAccessPolicy(userId, agentId, platformName) {
    const policyRow = this._setting(userId, agentId, accessPolicyKey(platformName));
    const legacyRow = this._setting(userId, agentId, legacyWhitelistKey(platformName));
    return parseStoredAccessPolicy(platformName, policyRow?.value, legacyRow?.value);
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

  _encodeStoredConfig(config) {
    const serialized = JSON.stringify(this._persistableConfig(config) || {});
    if (!serialized) return '{}';
    try {
      return encryptValue(serialized);
    } catch {
      return serialized;
    }
  }

  _decodeStoredConfig(value) {
    const raw = String(value || '').trim();
    if (!raw) return {};
    try {
      const decoded = decryptValue(raw);
      return decoded ? JSON.parse(decoded) : {};
    } catch {
      try {
        return JSON.parse(raw);
      } catch {
        return {};
      }
    }
  }

  async connectPlatform(userId, platformName, config = {}, options = {}) {
    this._assertRunning();
    throwIfAborted(options.signal, 'Messaging platform connection aborted.');
    const agentId = this._agentId(userId, options);
    config = { ...(config || {}) };
    config.userId = userId;
    config.agentId = agentId;
    config.accessPolicy = this._loadAccessPolicy(userId, agentId, platformName);
    if (platformName === 'whatsapp') {
      config.artifactStore = this.artifactStore;
    }
    const existingConnection = db
      .prepare('SELECT id, status FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?')
      .get(userId, agentId, platformName);
    const PlatformClass = this.platformTypes[platformName];
    if (!PlatformClass) throw new Error(`Unknown platform: ${platformName}`);
    if (platformName === 'meshtastic' && !readMeshtasticEnabled()) {
      throw new Error('Meshtastic is disabled by environment configuration');
    }

    if (platformName === 'whatsapp' && !config.authDir) {
      config.authDir = this._scopedPlatformAuthDir(userId, agentId, platformName);
      let shouldMigrateLegacyAuth = true;
      if (
        existingConnection &&
        existingConnection.status !== 'connected' &&
        existingConnection.status !== 'awaiting_qr'
      ) {
        fs.rmSync(config.authDir, { recursive: true, force: true });
        shouldMigrateLegacyAuth = false;
      }
      if (shouldMigrateLegacyAuth) {
        this._maybeMigrateLegacyWhatsAppAuth(config.authDir);
      }
    }

    const storedConfig = this._encodeStoredConfig(config);

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
      this.emit('platform_connected', { userId, agentId, platform: platformName });
      void this.recoverPendingInbound({
        userId,
        agentId,
        platform: platformName,
      }).catch((error) => {
        if (!this.isShuttingDown) {
          console.error('[Messaging] Inbound recovery failed:', error?.message || error);
        }
      });
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

    // Adapter-level blocked sender notification with suggestions
    platform.on('blocked_sender', (info) => {
      this._rememberAccessSuggestions(userId, agentId, platformName, info?.suggestions || []);
      this.io.to(`user:${userId}`).emit('messaging:blocked_sender', {
        platform: platformName,
        sender: info.sender,
        chatId: info.chatId,
        senderName: info.senderName || null,
        meta: info.meta || (info.guildName ? `Server: ${info.guildName}` : (info.groupName ? `Group: ${info.groupName}` : null)),
        suggestions: info.suggestions || null,
      });
    });

    platform.on('message', (msg) => {
      if (this.isShuttingDown) return;
      void this.ingestMessage(userId, platformName, msg, { agentId }).catch((error) => {
        if (!this.isShuttingDown) {
          console.error('[Messaging] Failed to persist or dispatch inbound message:', error?.message || error);
        }
      });
    });

    if (!existingConnection) {
      db.prepare('INSERT INTO platform_connections (user_id, agent_id, platform, config, status) VALUES (?, ?, ?, ?, ?)')
        .run(userId, agentId, platformName, storedConfig, 'connecting');
    } else {
      db.prepare('UPDATE platform_connections SET config = ?, status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?')
        .run(storedConfig, 'connecting', userId, agentId, platformName);
    }

    try {
      await this._runOperation(
        options,
        `${platformName} connection`,
        () => platform.connect(),
      );
    } catch (error) {
      if (currentPlatform()) {
        this.platforms.delete(key);
      }
      await Promise.resolve(platform.disconnect?.()).catch(() => {});
      throw error;
    }
    return { status: platform.getStatus() };
  }

  async disconnectPlatform(userId, platformName, options = {}) {
    const agentId = this._agentId(userId, options);
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);

    if (platform) {
      await platform.disconnect();
      this.platforms.delete(key);
    }

    db.prepare('UPDATE platform_connections SET status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?')
      .run('disconnected', userId, agentId, platformName);

    return { status: 'disconnected' };
  }

  async sendMessage(userId, platformName, to, content, mediaPathOrOptions) {
    this._assertRunning();
    const agentId = this._agentId(userId, mediaPathOrOptions || {});
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    if (!platform) throw new Error(`Platform ${platformName} not connected`);

    const sendOptions =
      mediaPathOrOptions && typeof mediaPathOrOptions === 'object' && !Array.isArray(mediaPathOrOptions)
        ? mediaPathOrOptions
        : { mediaPath: mediaPathOrOptions };
    const mediaReference = sendOptions.mediaPath || null;
    const mediaPath = mediaReference
      ? resolveUserFileReference({
          userId,
          reference: mediaReference,
          artifactStore: this.artifactStore,
          workspaceManager: this.workspaceManager,
          label: 'Message attachment',
        })
      : null;
    const platformSendOptions = {
      ...sendOptions,
      mediaPath,
    };
    const runId = sendOptions.runId || null;
    const persistConversation = sendOptions.persistConversation === true;
    const metadata = sendOptions.metadata && typeof sendOptions.metadata === 'object'
      ? sendOptions.metadata
      : null;
    const deliveryKind = sendOptions.deliveryKind || 'final';
    throwIfAborted(sendOptions.signal, 'Message delivery aborted.');
    const normalizedContent = normalizeOutgoingMessageForPlatform(platformName, content, {
      stripNoResponseMarker: false
    });

    // Sentinel: agent can choose not to reply by sending [NO RESPONSE]
    if (!mediaPath && typeof normalizedContent === 'string' && normalizedContent.toUpperCase() === '[NO RESPONSE]') {
      return { success: true, suppressed: true };
    }

    const result = await this._runOperation(
      sendOptions,
      `${platformName} message delivery`,
      (signal) => platform.sendMessage(to, normalizedContent, { ...platformSendOptions, signal }),
    );
    this._assertRunning();
    throwIfAborted(sendOptions.signal, 'Message delivery aborted.');
    if (result?.success === false) {
      const reason = result.error || result.reason || 'platform rejected the message';
      const error = new Error(`Platform ${platformName} delivery failed: ${reason}`);
      error.code = 'MESSAGING_DELIVERY_FAILED';
      error.deliveryResult = result;
      throw error;
    }

    db.prepare('INSERT INTO messages (user_id, agent_id, run_id, role, content, platform, platform_chat_id, media_path, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
      .run(userId, agentId, runId, 'assistant', normalizedContent, platformName, to, mediaReference, metadata ? JSON.stringify(metadata) : null);

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
      mediaPath: mediaReference,
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
      mediaPath: mediaReference,
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
    if (!this.platformTypes[platformName]) {
      return { status: 'not_supported' };
    }
    if (platformName === 'meshtastic' && !readMeshtasticEnabled()) {
      return {
        status: 'disabled',
        authInfo: {
          label: 'Disabled in env',
        },
      };
    }
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

    if (!readMeshtasticEnabled()) {
      statuses.meshtastic = {
        status: 'disabled',
        agentId,
        lastConnected: null,
        authInfo: {
          label: 'Disabled in env',
        },
      };
    }

    for (const conn of connections) {
      if (!this.platformTypes[conn.platform]) {
        continue;
      }
      if (conn.platform === 'meshtastic' && !readMeshtasticEnabled()) {
        continue;
      }
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
        reconnectConfig = this._decodeStoredConfig(row.config);
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
    this._assertRunning();
    const rows = db.prepare(
      "SELECT user_id, agent_id, platform, config FROM platform_connections WHERE status IN ('connected', 'awaiting_qr')"
    ).all();
    for (const row of rows) {
      try {
        if (!this.platformTypes[row.platform]) {
          db.prepare("UPDATE platform_connections SET status = 'disabled' WHERE user_id = ? AND agent_id = ? AND platform = ?")
            .run(row.user_id, row.agent_id, row.platform);
          continue;
        }
        if (row.platform === 'meshtastic' && !readMeshtasticEnabled()) {
          db.prepare("UPDATE platform_connections SET status = 'disabled' WHERE user_id = ? AND agent_id = ? AND platform = ?")
            .run(row.user_id, row.agent_id, row.platform);
          continue;
        }
        const config = this._decodeStoredConfig(row.config);
        console.log(`[Messaging] Restoring ${row.platform} for user ${row.user_id} agent ${row.agent_id || 'main'}`);
        await this.connectPlatform(row.user_id, row.platform, config, { agentId: row.agent_id });
      } catch (err) {
        console.error(`[Messaging] Failed to restore ${row.platform} for user ${row.user_id}:`, err.message);
        db.prepare("UPDATE platform_connections SET status = 'disconnected' WHERE user_id = ? AND agent_id = ? AND platform = ?")
          .run(row.user_id, row.agent_id, row.platform);
      }
    }
  }

  async updateMeshtasticEnabled(enabled) {
    if (enabled) return;
    const disconnects = [];
    for (const [key, platform] of this.platforms.entries()) {
      if (!key.endsWith(':meshtastic')) continue;
      disconnects.push(
        Promise.resolve(platform.disconnect()).catch(() => {}).then(() => {
          this.platforms.delete(key);
        })
      );
    }
    await Promise.all(disconnects);
    db.prepare("UPDATE platform_connections SET status = 'disabled' WHERE platform = 'meshtastic'")
      .run();
  }

  async shutdown() {
    if (this.shutdownPromise) return this.shutdownPromise;
    this.isShuttingDown = true;
    this.lifecycleAbortController.abort(messagingShutdownError());

    this.shutdownPromise = (async () => {
      const activeOperationTasks = Array.from(this.activeOperations, (operation) =>
        waitForBoundedResult(operation, {
          serviceName: 'Messaging operation shutdown',
          timeoutMs: 10000,
        }));
      activeOperationTasks.push(...Array.from(this.activeInboundJobs, (job) =>
        waitForBoundedResult(job, {
          serviceName: 'Messaging inbound job shutdown',
          timeoutMs: 10000,
        })));
      activeOperationTasks.push(...Array.from(this.activeInboundRecoveries.values(), (recovery) =>
        waitForBoundedResult(recovery, {
          serviceName: 'Messaging inbound recovery shutdown',
          timeoutMs: 10000,
        })));
      const disconnectTasks = [];
      for (const platform of this.platforms.values()) {
        if (typeof platform.disconnect === 'function') {
          disconnectTasks.push(waitForBoundedResult(
            Promise.resolve().then(() => platform.disconnect()),
            {
              serviceName: `${platform.name || 'Messaging platform'} disconnect`,
              timeoutMs: 10000,
            },
          ));
        }
      }

      const [operationResults, disconnectResults] = await Promise.all([
        Promise.allSettled(activeOperationTasks),
        Promise.allSettled(disconnectTasks),
      ]);
      this.platforms.clear();
      return {
        state: 'stopped',
        cancelledOperationCount: operationResults.filter(
          (result) => result.status === 'rejected',
        ).length,
        failedDisconnectCount: disconnectResults.filter(
          (result) => result.status === 'rejected',
        ).length,
      };
    })();
    return this.shutdownPromise;
  }

  async markRead(userId, platformName, chatId, messageId, options = {}) {
    this._assertRunning();
    const key = this._key(userId, this._agentId(userId, options), platformName);
    const platform = this.platforms.get(key);
    if (!platform?.markRead) return;
    return this._runOperation(
      options,
      `${platformName} read receipt`,
      (signal) => platform.markRead(chatId, messageId, { ...options, signal }),
      15000,
    );
  }

  async sendTyping(userId, platformName, chatId, isTyping, options = {}) {
    this._assertRunning();
    const key = this._key(userId, this._agentId(userId, options), platformName);
    const platform = this.platforms.get(key);
    if (!platform?.sendTyping) return;
    return this._runOperation(
      options,
      `${platformName} typing indicator`,
      (signal) => platform.sendTyping(chatId, isTyping, { ...options, signal }),
      15000,
    );
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

  getAccessPolicy(userId, platformName, options = {}) {
    const agentId = this._agentId(userId, options);
    return this._loadAccessPolicy(userId, agentId, platformName);
  }

  setAccessPolicy(userId, platformName, policy, options = {}) {
    const agentId = this._agentId(userId, options);
    const normalized = normalizeAccessPolicy(platformName, policy);
    this._upsertSetting(userId, agentId, accessPolicyKey(platformName), normalized);
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    if (platform?.setAccessPolicy) {
      platform.setAccessPolicy(normalized);
    }
    return normalized;
  }

  evaluateAccess(userId, platformName, context, options = {}) {
    const agentId = this._agentId(userId, options);
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    if (platform?.evaluateAccess) {
      return platform.evaluateAccess(context);
    }
    return evaluateAccessPolicy(
      this._loadAccessPolicy(userId, agentId, platformName),
      context,
      platformName,
    );
  }

  async listAccessTargets(userId, platformName, options = {}) {
    const agentId = this._agentId(userId, options);
    const key = this._key(userId, agentId, platformName);
    const platform = this.platforms.get(key);
    if (!platform || typeof platform.listAccessTargets !== 'function') {
      return [];
    }
    return Promise.resolve(platform.listAccessTargets()).catch(() => []);
  }

  async getAccessCatalog(userId, platformName, options = {}) {
    const agentId = this._agentId(userId, options);
    const capabilities = getPlatformAccessCapabilities(platformName);
    const normalizeTargetBucket = (target) => (
      target?.bucket === 'directRules'
      && capabilities.supportsSharedPolicy
      && capabilities.sharedActorRuleScopes.includes(target.scope)
        ? { ...target, bucket: 'sharedActorRules' }
        : target
    );
    const listedTargets = await this.listAccessTargets(
      userId,
      platformName,
      { agentId },
    );
    const discoveredTargets = (
      Array.isArray(listedTargets) ? listedTargets : []
    ).map(normalizeTargetBucket);

    const recentRows = db.prepare(
      `SELECT platform_chat_id, metadata
       FROM messages
       WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id IS NOT NULL
       ORDER BY id DESC
       LIMIT 40`
    ).all(userId, agentId, platformName);
    const recentTargets = recentRows
      .map((row) => {
        let metadata = {};
        try {
          metadata = row.metadata ? JSON.parse(row.metadata) : {};
        } catch {
          metadata = {};
        }
        return normalizeTargetBucket(
          classifyRecentTarget(platformName, { ...row, metadata }),
        );
      })
      .filter(Boolean);

    const seen = new Set();
    const unique = (items) => items.filter((item) => {
      const rule = item?.rule || item || {};
      const keyValue = [
        item?.bucket,
        rule.scope,
        rule.value,
        rule.spaceScope || '',
        rule.spaceValue || '',
      ].join(':');
      if (seen.has(keyValue)) return false;
      seen.add(keyValue);
      return true;
    });

    return {
      capabilities,
      discoveredTargets: unique([...(Array.isArray(discoveredTargets) ? discoveredTargets : []), ...recentTargets]),
      suggestedTargets: unique(this.accessSuggestions.get(this._accessSuggestionKey(userId, agentId, platformName)) || []),
      policy: this._loadAccessPolicy(userId, agentId, platformName),
      summary: summarizeAccessPolicy(platformName, this._loadAccessPolicy(userId, agentId, platformName)),
    };
  }

  /**
   * Update the allowed-entries list on a live Discord platform instance.
   * Accepts prefixed strings: "user:ID", "guild:ID", "channel:ID"
   */
  updateDiscordAllowedIds(userId, ids, options = {}) {
    return this.setAccessPolicy(userId, 'discord', migrateLegacyWhitelist('discord', ids), options);
  }

  /**
   * Update the allowed-entries list on a live Telegram platform instance.
   * Accepts prefixed strings: "user:ID", "group:ID"
   */
  updateTelegramAllowedIds(userId, ids, options = {}) {
    return this.setAccessPolicy(userId, 'telegram', migrateLegacyWhitelist('telegram', ids), options);
  }

  updateAllowedEntries(userId, platformName, ids, options = {}) {
    return this.setAccessPolicy(userId, platformName, migrateLegacyWhitelist(platformName, ids), options);
  }
}

module.exports = { MessagingManager };
