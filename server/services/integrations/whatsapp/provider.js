'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const db = require('../../../db/database');
const { AGENT_DATA_DIR } = require('../../../../runtime/paths');
const { encryptValue, decryptValue } = require('../secrets');
const { withConnectionAccessMode } = require('../access');
const { normalizeWhatsAppId, toWhatsAppJid } = require('../../../utils/whatsapp');

const WHATSAPP_APP = {
  id: 'personal',
  label: 'Personal WhatsApp',
  description:
    'Link your own WhatsApp account for private read and send tools, isolated from the agent-facing messaging bridge.',
};

const TOOL_DEFINITIONS = [
  {
    appId: 'personal',
    name: 'whatsapp_personal_get_profile',
    access: 'read',
    description:
      'Get metadata about the linked personal WhatsApp account and its current sync state.',
    parameters: {
      type: 'object',
      properties: {},
    },
  },
  {
    appId: 'personal',
    name: 'whatsapp_personal_list_chats',
    access: 'read',
    description:
      'List cached chats synchronized for the linked personal WhatsApp account.',
    parameters: {
      type: 'object',
      properties: {
        limit: {
          type: 'number',
          description: 'Maximum chats to return, default 25.',
        },
      },
    },
  },
  {
    appId: 'personal',
    name: 'whatsapp_personal_get_messages',
    access: 'read',
    description:
      'Read recent cached messages from a linked personal WhatsApp chat.',
    parameters: {
      type: 'object',
      properties: {
        chat_id: {
          type: 'string',
          description: 'WhatsApp JID or phone number for the chat to inspect.',
        },
        limit: {
          type: 'number',
          description: 'Maximum messages to return, default 20.',
        },
      },
      required: ['chat_id'],
    },
  },
  {
    appId: 'personal',
    name: 'whatsapp_personal_send_message',
    access: 'write',
    description:
      'Send a WhatsApp message from the linked personal account.',
    parameters: {
      type: 'object',
      properties: {
        to: {
          type: 'string',
          description: 'Recipient WhatsApp JID or phone number.',
        },
        text: {
          type: 'string',
          description: 'Message body to send.',
        },
      },
      required: ['to', 'text'],
    },
  },
];

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) {
    throw new Error(`${label} is required.`);
  }
  return text;
}

function safeJsonParse(value, fallback = {}) {
  try {
    const parsed = JSON.parse(String(value || ''));
    return parsed && typeof parsed === 'object' ? parsed : fallback;
  } catch {
    return fallback;
  }
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function createSilentLogger() {
  try {
    const pino = require('pino');
    return pino({ level: 'silent' });
  } catch {
    return {
      level: 'silent',
      child() {
        return this;
      },
      trace() {},
      debug() {},
      info() {},
      warn() {},
      error() {},
    };
  }
}

function summarizeAccountRow(row, envStatus) {
  if (!envStatus.configured) {
    return {
      id: row?.id || null,
      status: 'env_not_configured',
      connected: false,
      accountEmail: row?.account_email || null,
      lastConnectedAt: row?.last_connected_at || null,
      accessMode: 'read_write',
    };
  }

  if (!row) {
    return {
      id: null,
      status: 'not_connected',
      connected: false,
      accountEmail: null,
      lastConnectedAt: null,
      accessMode: 'read_write',
    };
  }

  const metadata = safeJsonParse(row.metadata_json, {});
  return {
    id: row.id || null,
    status: row.status || 'not_connected',
    connected: row.status === 'connected',
    accountEmail: row.account_email || null,
    lastConnectedAt: row.last_connected_at || null,
    accessMode: metadata.access_mode || 'read_write',
  };
}

function extractMessageText(message = {}) {
  return (
    message.conversation ||
    message.extendedTextMessage?.text ||
    message.imageMessage?.caption ||
    message.videoMessage?.caption ||
    message.documentMessage?.caption ||
    message.pollCreationMessage?.name ||
    ''
  );
}

function simplifyMessage(msg = {}, fallbackChatId = '') {
  const key = msg.key || {};
  const chatId = key.remoteJid || fallbackChatId || '';
  const sender = key.participant || key.remoteJid || '';
  const text = extractMessageText(msg.message || {});
  let kind = 'text';
  if (msg.message?.imageMessage) kind = 'image';
  else if (msg.message?.videoMessage) kind = 'video';
  else if (msg.message?.audioMessage) kind = 'audio';
  else if (msg.message?.documentMessage) kind = 'document';
  else if (msg.message?.stickerMessage) kind = 'sticker';

  return {
    id: key.id || null,
    chatId,
    sender,
    senderTag: normalizeWhatsAppId(sender) || sender,
    fromMe: key.fromMe === true,
    kind,
    text: text || (kind === 'text' ? '' : `[${kind}]`),
    timestamp: msg.messageTimestamp
      ? new Date(Number(msg.messageTimestamp) * 1000).toISOString()
      : new Date().toISOString(),
  };
}

class WhatsAppPersonalProvider {
  constructor(options = {}) {
    this.key = 'whatsapp_personal';
    this.label = 'WhatsApp';
    this.description =
      'Official personal WhatsApp integration with explicit per-account read-only or read/write access.';
    this.icon = 'whatsapp';
    this.apps = [{ ...WHATSAPP_APP }];
    this.connectPrompt =
      'Link your personal WhatsApp account here to give the AI private read tools, send tools, or both. This connection is isolated from the separate messaging-platform WhatsApp bridge.';
    this.sessions = new Map();
    this.clients = new Map();
    this.io = options.io || null;
  }

  getApp(appId) {
    return String(appId || '').trim() === WHATSAPP_APP.id ? { ...WHATSAPP_APP } : null;
  }

  getToolAppId(toolName) {
    const name = String(toolName || '').trim();
    return TOOL_DEFINITIONS.some((tool) => tool.name === name) ? WHATSAPP_APP.id : null;
  }

  getEnvStatus() {
    try {
      require.resolve('baileys');
      return {
        configured: true,
        missing: [],
        summary: 'WhatsApp personal linking is ready for account connections.',
      };
    } catch {
      return {
        configured: false,
        missing: ['baileys'],
        summary: 'WhatsApp personal linking is unavailable because the Baileys dependency is missing.',
      };
    }
  }

  buildSnapshot(connectionRows) {
    const env = this.getEnvStatus();
    const accounts = (Array.isArray(connectionRows) ? connectionRows : [])
      .slice()
      .sort((left, right) =>
        String(right.updated_at || '').localeCompare(String(left.updated_at || '')),
      )
      .map((row) => summarizeAccountRow(row, env));
    const connectedAccounts = accounts.filter((account) => account.connected);
    const latestConnectedAt =
      connectedAccounts
        .map((account) => account.lastConnectedAt)
        .filter(Boolean)
        .sort()
        .reverse()[0] || null;
    const appSnapshot = {
      id: WHATSAPP_APP.id,
      label: WHATSAPP_APP.label,
      description: WHATSAPP_APP.description,
      accounts,
      connection: {
        status: !env.configured
          ? 'env_not_configured'
          : connectedAccounts.length > 0
          ? 'connected'
          : 'not_connected',
        connected: connectedAccounts.length > 0,
        accountCount: connectedAccounts.length,
        accountEmail:
          connectedAccounts.length === 1
            ? connectedAccounts[0].accountEmail
            : null,
        lastConnectedAt: latestConnectedAt,
      },
      availableToolCount:
        env.configured && connectedAccounts.length > 0 ? TOOL_DEFINITIONS.length : 0,
    };

    return {
      id: this.key,
      label: this.label,
      description: this.description,
      icon: this.icon,
      apps: [appSnapshot],
      env,
      connection: {
        status: appSnapshot.connection.status,
        connected: appSnapshot.connection.connected,
        accountCount: connectedAccounts.length,
        appCount: connectedAccounts.length > 0 ? 1 : 0,
        accountEmail: appSnapshot.connection.accountEmail,
        lastConnectedAt: latestConnectedAt,
      },
      availableToolCount: appSnapshot.availableToolCount,
      connectPrompt: this.connectPrompt,
    };
  }

  summarizeForModel(snapshot) {
    if (!snapshot?.env?.configured) {
      return `${this.label}: available but not configured on the server yet.`;
    }
    if (!snapshot?.connection?.connected) {
      return `${this.label}: personal integration is available, but no account is connected. The separate messaging-platform WhatsApp bridge does not count as this official integration.`;
    }
    const accounts = snapshot.apps
      ?.flatMap((app) => app.accounts || [])
      .filter((account) => account.connected)
      .map((account) => `${account.accountEmail || `connection ${account.id}`} (${account.accessMode === 'read_only' ? 'read-only' : 'read/write'})`)
      .join(', ');
    return `${this.label}: personal official integration connected for ${accounts}. Keep it separate from messaging-platform WhatsApp usage.`;
  }

  getToolDefinitions({ connectedAppIds } = {}) {
    const appIds = new Set(Array.isArray(connectedAppIds) ? connectedAppIds : []);
    if (!appIds.has(WHATSAPP_APP.id)) {
      return [];
    }
    return TOOL_DEFINITIONS.map((tool) => ({
      ...tool,
      description:
        `${tool.description} When multiple personal WhatsApp accounts are connected, set connection_id or account_email to choose which one to use.`,
      parameters: {
        ...(tool.parameters || { type: 'object', properties: {} }),
        type: 'object',
        properties: {
          ...((tool.parameters && tool.parameters.properties) || {}),
          connection_id: {
            type: 'number',
            description: 'Optional connected personal WhatsApp account ID.',
          },
          account_email: {
            type: 'string',
            description: 'Optional connected personal WhatsApp phone number identifier.',
          },
        },
        required: Array.isArray(tool.parameters?.required)
          ? tool.parameters.required.slice()
          : [],
      },
    }));
  }

  supportsTool(toolName) {
    return TOOL_DEFINITIONS.some((tool) => tool.name === String(toolName || '').trim());
  }

  _authDir(userId, agentId, sessionId) {
    return path.join(
      AGENT_DATA_DIR,
      'integrations',
      'whatsapp-personal',
      String(userId),
      String(agentId || 'main'),
      String(sessionId),
    );
  }

  _serializeSession(session) {
    return {
      id: session.id,
      provider: this.key,
      appId: session.appKey,
      status: session.status,
      qr: session.qr || null,
      connectionId: session.connectionId || null,
      accountEmail: session.accountEmail || null,
      error: session.error || null,
    };
  }

  async beginConnection({ userId, agentId, appKey }) {
    if (!this.getApp(appKey)) {
      throw new Error(`Unknown ${this.label} app: ${appKey || 'missing app key'}`);
    }
    const sessionId = crypto.randomBytes(18).toString('hex');
    const session = {
      id: sessionId,
      userId,
      agentId,
      appKey,
      status: 'connecting',
      qr: null,
      connectionId: null,
      accountEmail: null,
      error: null,
      authDir: this._authDir(userId, agentId, sessionId),
      socket: null,
      chats: new Map(),
      messages: new Map(),
      logger: createSilentLogger(),
    };
    this.sessions.set(sessionId, session);
    this._startSessionSocket(session).catch((err) => {
      session.status = 'failed';
      session.error = err?.message || 'connection_failed';
    });

    return {
      provider: this.key,
      appId: appKey,
      status: 'interactive_connect',
      sessionId,
      url: `/api/integrations/${this.key}/connect/${sessionId}`,
    };
  }

  getConnectionSession(userId, providerKey, sessionId, agentId = null) {
    if (providerKey !== this.key) {
      return null;
    }
    const session = this.sessions.get(String(sessionId || '').trim());
    if (!session) {
      return null;
    }
    if (session.userId !== userId || String(session.agentId || '') !== String(agentId || '')) {
      return null;
    }
    return this._serializeSession(session);
  }

  async disconnect(connection) {
    const credentials = safeJsonParse(
      decryptValue(connection?.credentials_json || '{}') || '{}',
      {},
    );
    const authDir = String(credentials.authDir || '').trim();
    const client = this.clients.get(connection.id);
    if (client?.socket) {
      try {
        await client.socket.logout();
      } catch {}
      try {
        client.socket.end(new Error('manual_disconnect'));
      } catch {}
    }
    this.clients.delete(connection.id);
    if (authDir) {
      fs.rmSync(authDir, { recursive: true, force: true });
    }
  }

  async executeTool(toolName, args, connection) {
    const client = await this._ensureClient(connection);

    switch (toolName) {
      case 'whatsapp_personal_get_profile':
        return {
          result: {
            account: client.accountEmail || connection.account_email || null,
            connected: client.status === 'connected',
            chatCount: client.chats.size,
            cachedMessageChats: client.messages.size,
            syncNote:
              'Read tools only expose chats and messages synchronized through this personal integration session.',
          },
        };
      case 'whatsapp_personal_list_chats': {
        const limit = Math.max(1, Math.min(Number(args.limit) || 25, 100));
        const chats = Array.from(client.chats.values())
          .sort((left, right) =>
            String(right.lastMessageAt || '').localeCompare(String(left.lastMessageAt || '')),
          )
          .slice(0, limit);
        return {
          result: {
            chats,
            count: chats.length,
            syncNote:
              'Only chats synchronized after linking this personal integration are available here.',
          },
        };
      }
      case 'whatsapp_personal_get_messages': {
        const jid = this._normalizeChatId(requireText(args.chat_id, 'chat_id'));
        const limit = Math.max(1, Math.min(Number(args.limit) || 20, 100));
        const messages = (client.messages.get(jid) || []).slice(-limit).reverse();
        return {
          result: {
            chatId: jid,
            messages,
            count: messages.length,
            syncNote:
              'Only messages synchronized through this personal integration session are readable here.',
          },
        };
      }
      case 'whatsapp_personal_send_message': {
        const jid = this._normalizeChatId(requireText(args.to, 'to'));
        await client.socket.sendMessage(jid, {
          text: requireText(args.text, 'text'),
        });
        return {
          result: {
            sent: true,
            to: jid,
          },
        };
      }
      default:
        return null;
    }
  }

  async _startSessionSocket(session) {
    ensureDir(session.authDir);
    const {
      default: makeWASocket,
      useMultiFileAuthState,
      makeCacheableSignalKeyStore,
      fetchLatestBaileysVersion,
      Browsers,
      DisconnectReason,
    } = require('baileys');

    const { version } = await fetchLatestBaileysVersion();
    const { state, saveCreds } = await useMultiFileAuthState(session.authDir);

    const sock = makeWASocket({
      version,
      auth: {
        creds: state.creds,
        keys: makeCacheableSignalKeyStore(state.keys, session.logger),
      },
      logger: session.logger,
      browser: Browsers.appropriate('Chrome'),
      connectTimeoutMs: 60000,
      defaultQueryTimeoutMs: 60000,
      markOnlineOnConnect: false,
      syncFullHistory: true,
    });

    session.socket = sock;
    sock.ev.on('creds.update', saveCreds);

    this._bindCacheEvents(session, sock);

    sock.ev.on('connection.update', async (update) => {
      const { connection, qr, lastDisconnect } = update;
      if (qr) {
        session.qr = qr;
        session.status = 'awaiting_qr';
      }

      if (connection === 'open') {
        session.status = 'connected';
        session.qr = null;
        session.accountEmail = normalizeWhatsAppId(sock.user?.id) || sock.user?.id || null;
        const connectionId = this._upsertConnectedAccount(session);
        session.connectionId = connectionId;
        this.clients.set(connectionId, {
          connectionId,
          authDir: session.authDir,
          socket: sock,
          chats: session.chats,
          messages: session.messages,
          status: 'connected',
          accountEmail: session.accountEmail,
          logger: session.logger,
          connectPromise: null,
        });
      }

      if (connection === 'close') {
        const statusCode = lastDisconnect?.error?.output?.statusCode;
        const loggedOut = statusCode === DisconnectReason.loggedOut;
        if (loggedOut) {
          session.status = 'logged_out';
          const connectionId = session.connectionId;
          if (connectionId) {
            this.clients.delete(connectionId);
          }
          fs.rmSync(session.authDir, { recursive: true, force: true });
          return;
        }

        if (session.connectionId) {
          const client = this.clients.get(session.connectionId);
          if (client) {
            client.status = 'disconnected';
          }
          session.status = 'disconnected';
        } else if (session.status !== 'failed') {
          session.status = 'disconnected';
        }
      }
    });
  }

  _bindCacheEvents(target, sock) {
    sock.ev.on('messaging-history.set', (payload) => {
      for (const chat of payload?.chats || []) {
        this._upsertChat(target, chat);
      }
      for (const msg of payload?.messages || []) {
        this._recordMessage(target, msg);
      }
    });

    sock.ev.on('chats.upsert', (chats) => {
      for (const chat of chats || []) {
        this._upsertChat(target, chat);
      }
    });

    sock.ev.on('chats.update', (updates) => {
      for (const update of updates || []) {
        this._upsertChat(target, update);
      }
    });

    sock.ev.on('messages.upsert', ({ messages }) => {
      for (const msg of messages || []) {
        this._recordMessage(target, msg);
      }
    });
  }

  _upsertChat(target, chat = {}) {
    const chats = target.chats;
    if (!chats || !chat.id) {
      return;
    }
    const existing = chats.get(chat.id) || {};
    const name =
      chat.name ||
      chat.conversationName ||
      chat.subject ||
      existing.name ||
      chat.id;
    const item = {
      id: chat.id,
      name,
      isGroup: String(chat.id).endsWith('@g.us'),
      unreadCount: Number(chat.unreadCount || existing.unreadCount || 0),
      archived: chat.archived === true || existing.archived === true,
      muteEndTime: chat.muteEndTime || existing.muteEndTime || null,
      lastMessageAt:
        chat.conversationTimestamp
          ? new Date(Number(chat.conversationTimestamp) * 1000).toISOString()
          : existing.lastMessageAt || null,
    };
    chats.set(chat.id, item);
  }

  _recordMessage(target, msg = {}) {
    const simplified = simplifyMessage(msg);
    if (!simplified.chatId) {
      return;
    }
    const messages = target.messages;
    const chats = target.chats;
    const list = messages.get(simplified.chatId) || [];
    list.push(simplified);
    if (list.length > 200) {
      list.splice(0, list.length - 200);
    }
    messages.set(simplified.chatId, list);

    const existingChat = chats.get(simplified.chatId) || {
      id: simplified.chatId,
      name: simplified.chatId,
      isGroup: String(simplified.chatId).endsWith('@g.us'),
      unreadCount: 0,
      archived: false,
      muteEndTime: null,
      lastMessageAt: null,
    };
    chats.set(simplified.chatId, {
      ...existingChat,
      lastMessageAt: simplified.timestamp,
    });
  }

  _normalizeChatId(value) {
    const raw = String(value || '').trim();
    if (!raw) {
      throw new Error('chat_id is required.');
    }
    if (raw.includes('@')) {
      return raw;
    }
    return toWhatsAppJid(raw);
  }

  _upsertConnectedAccount(session) {
    const existing = db
      .prepare(
        `SELECT * FROM integration_connections
         WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND app_key = ? AND account_email = ?`,
      )
      .get(
        session.userId,
        session.agentId,
        this.key,
        session.appKey,
        session.accountEmail,
      );

    const credentials = {
      authDir: session.authDir,
      linkedAt: new Date().toISOString(),
    };
    const metadata = withConnectionAccessMode(
      existing?.metadata_json || '{}',
      existing
        ? safeJsonParse(existing.metadata_json, {}).access_mode || 'read_write'
        : 'read_write',
    );

    db.prepare(
      `INSERT INTO integration_connections (
         user_id,
         agent_id,
         provider_key,
         app_key,
         status,
         account_email,
         scopes_json,
         credentials_json,
         metadata_json,
         last_connected_at,
         updated_at
       ) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
       ON CONFLICT(user_id, agent_id, provider_key, app_key, account_email) DO UPDATE SET
         status = 'connected',
         scopes_json = excluded.scopes_json,
         credentials_json = excluded.credentials_json,
         metadata_json = excluded.metadata_json,
         last_connected_at = excluded.last_connected_at,
         updated_at = excluded.updated_at`,
    ).run(
      session.userId,
      session.agentId,
      this.key,
      session.appKey,
      session.accountEmail,
      JSON.stringify(['personal_whatsapp']),
      encryptValue(JSON.stringify(credentials)),
      JSON.stringify(metadata),
    );

    const row = db
      .prepare(
        `SELECT * FROM integration_connections
         WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND app_key = ? AND account_email = ?`,
      )
      .get(
        session.userId,
        session.agentId,
        this.key,
        session.appKey,
        session.accountEmail,
      );

    if (existing?.credentials_json) {
      const previous = safeJsonParse(
        decryptValue(existing.credentials_json || '{}') || '{}',
        {},
      );
      const previousAuthDir = String(previous.authDir || '').trim();
      if (previousAuthDir && previousAuthDir !== session.authDir) {
        fs.rmSync(previousAuthDir, { recursive: true, force: true });
      }
    }

    return row?.id;
  }

  async _ensureClient(connection) {
    const existing = this.clients.get(connection.id);
    if (existing?.status === 'connected' && existing.socket) {
      return existing;
    }
    if (existing?.connectPromise) {
      await existing.connectPromise;
      const ready = this.clients.get(connection.id);
      if (ready?.status === 'connected' && ready.socket) {
        return ready;
      }
    }

    const credentials = safeJsonParse(
      decryptValue(connection?.credentials_json || '{}') || '{}',
      {},
    );
    const authDir = String(credentials.authDir || '').trim();
    if (!authDir) {
      throw new Error('WhatsApp account credentials are missing.');
    }

    const client = existing || {
      connectionId: connection.id,
      authDir,
      socket: null,
      chats: new Map(),
      messages: new Map(),
      status: 'connecting',
      accountEmail: connection.account_email || null,
      logger: createSilentLogger(),
      connectPromise: null,
    };
    client.connectPromise = this._connectClient(client);
    this.clients.set(connection.id, client);
    await client.connectPromise;
    const ready = this.clients.get(connection.id);
    if (!ready?.socket || ready.status !== 'connected') {
      throw new Error('WhatsApp personal account is not connected.');
    }
    return ready;
  }

  async _connectClient(client) {
    ensureDir(client.authDir);
    const {
      default: makeWASocket,
      useMultiFileAuthState,
      makeCacheableSignalKeyStore,
      fetchLatestBaileysVersion,
      Browsers,
    } = require('baileys');

    const { version } = await fetchLatestBaileysVersion();
    const { state, saveCreds } = await useMultiFileAuthState(client.authDir);
    const sock = makeWASocket({
      version,
      auth: {
        creds: state.creds,
        keys: makeCacheableSignalKeyStore(state.keys, client.logger),
      },
      logger: client.logger,
      browser: Browsers.appropriate('Chrome'),
      connectTimeoutMs: 60000,
      defaultQueryTimeoutMs: 60000,
      markOnlineOnConnect: false,
      syncFullHistory: true,
    });

    client.socket = sock;
    sock.ev.on('creds.update', saveCreds);
    this._bindCacheEvents(client, sock);

    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('WhatsApp connection timed out.'));
      }, 60000);

      sock.ev.on('connection.update', (update) => {
        if (update.connection === 'open') {
          clearTimeout(timeout);
          client.status = 'connected';
          client.accountEmail = normalizeWhatsAppId(sock.user?.id) || client.accountEmail;
          resolve();
        } else if (update.connection === 'close') {
          clearTimeout(timeout);
          client.status = 'disconnected';
          reject(new Error('WhatsApp personal account is disconnected.'));
        }
      });
    });
  }
}

function createWhatsAppPersonalProvider(options = {}) {
  return new WhatsAppPersonalProvider(options);
}

module.exports = {
  createWhatsAppPersonalProvider,
};
