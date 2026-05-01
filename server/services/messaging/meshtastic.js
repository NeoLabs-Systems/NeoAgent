'use strict';

const { BasePlatform } = require('./base');
const { readMeshtasticEnabled } = require('./meshtastic_env');
const { MeshtasticTcpTransport } = require('./meshtastic_tcp_transport');
const { BROADCAST_NUM } = require('./meshtastic_protocol');

const DEFAULT_TCP_PORT = 4403;
const DEFAULT_CHANNEL = 0;

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`${label} is required`);
  return text;
}

function parseTcpHost(input) {
  const raw = requireText(input, 'Meshtastic device IP address');
  if (raw.startsWith('[')) {
    const match = raw.match(/^\[([^\]]+)\](?::(\d+))?$/);
    if (!match) {
      throw new Error('Meshtastic device IP address is invalid');
    }
    return {
      host: match[1],
      port: match[2] ? Number(match[2]) : DEFAULT_TCP_PORT,
    };
  }

  const parts = raw.split(':');
  if (parts.length === 2 && /^\d+$/.test(parts[1])) {
    return {
      host: parts[0],
      port: Number(parts[1]),
    };
  }

  return { host: raw, port: DEFAULT_TCP_PORT };
}

function parseChannel(value) {
  const channel = Number(String(value ?? DEFAULT_CHANNEL).trim() || DEFAULT_CHANNEL);
  if (!Number.isInteger(channel) || channel < 0 || channel > 6) {
    throw new Error('Meshtastic channel must be an integer from 0 to 6');
  }
  return channel;
}

function normalizeNodeId(value) {
  const text = String(value || '').trim();
  if (!text) return '';
  return text.startsWith('!') ? text : `!${text}`;
}

function toIsoTimestamp(value) {
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'number' && Number.isFinite(value)) {
    const normalized = value < 1e12 ? value * 1000 : value;
    return new Date(normalized).toISOString();
  }
  return new Date().toISOString();
}

class MeshtasticPlatform extends BasePlatform {
  constructor(config = {}) {
    super('meshtastic', config);
    this.supportsGroups = true;
    this.supportsMedia = false;
    this.supportsVoice = false;
    this.status = 'disconnected';
    this.host = null;
    this.port = DEFAULT_TCP_PORT;
    this.channel = DEFAULT_CHANNEL;
    this.authInfo = null;
    this._transport = null;
    this._connectPromise = null;
    this._disconnecting = false;
    this._reconnectTimer = null;
  }

  async connect() {
    if (!readMeshtasticEnabled()) {
      throw new Error('Meshtastic is disabled by environment configuration');
    }

    if (this._connectPromise) {
      return this._connectPromise;
    }

    this._connectPromise = this._connect();
    try {
      return await this._connectPromise;
    } finally {
      this._connectPromise = null;
    }
  }

  async _connect() {
    const endpoint = parseTcpHost(this.config.host || this.config.ipAddress || this.config.baseUrl);
    this.host = endpoint.host;
    this.port = endpoint.port;
    this.channel = parseChannel(this.config.channel);
    this._disconnecting = false;
    this.status = 'connecting';

    const transport = await MeshtasticTcpTransport.create(this.host, this.port, 60000);
    this._transport = transport;

    const conn = transport.connection;

    conn.on('myNodeInfo', () => {
      this.authInfo = this._buildAuthInfo(conn);
    });

    conn.on('textMessage', (msg) => {
      if (msg.channel !== this.channel) return;

      const localNodeNum = conn.myNodeNum;
      if (msg.from > 0 && localNodeNum > 0 && msg.from === localNodeNum) return;

      const senderUser = conn.nodeUsers.get(msg.from) || null;
      const senderName = senderUser?.longName || senderUser?.shortName || null;
      const senderUsername = normalizeNodeId(senderUser?.id || '');
      const chatId = `channel:${msg.channel}`;

      const access = this._checkInboundAccess({
        platform: this.name,
        senderId: String(msg.from || ''),
        chatId,
        isDirect: false,
        isShared: true,
        groupId: chatId,
        channelId: chatId,
        serverId: '',
        roomId: chatId,
        roleIds: [],
        phoneNumber: '',
        wasMentioned: false,
      }, {
        senderName,
        groupLabel: chatId,
        channelLabel: chatId,
        roomLabel: chatId,
      });

      if (!access.allowed) return;

      this.emit('message', {
        chatId,
        sender: String(msg.from || ''),
        senderName,
        senderUsername: senderUsername || null,
        senderTag: senderUsername || null,
        content: msg.data,
        mediaType: null,
        isGroup: true,
        messageId: String(msg.id || `${Date.now()}`),
        timestamp: toIsoTimestamp(msg.rxTime),
        metadata: {
          channel: msg.channel,
          host: this.host,
          meshNodeId: senderUsername || null,
          meshDestination: msg.type || 'broadcast',
        },
        rawMessage: {
          id: msg.id,
          from: msg.from,
          to: msg.to,
          type: msg.type,
          channel: msg.channel,
        },
      });
    });

    conn.on('disconnected', (info) => {
      if (this._disconnecting) return;
      this.status = 'disconnected';
      this.emit('disconnected', { reason: info?.reason || 'device_disconnected' });
      this._scheduleReconnect();
    });

    this.status = 'connected';
    this.authInfo = this._buildAuthInfo(conn);
    this.emit('connected');
    return { status: this.status };
  }

  _scheduleReconnect() {
    if (this._disconnecting || this._reconnectTimer) return;
    console.log(`[Meshtastic] Connection lost. Reconnecting in 10 seconds...`);
    this._reconnectTimer = setTimeout(() => {
      this._reconnectTimer = null;
      if (this._disconnecting) return;
      this.connect().catch((err) => {
        console.error(`[Meshtastic] Auto-reconnect failed:`, err.message);
        this._scheduleReconnect();
      });
    }, 10000);
  }

  _buildAuthInfo(conn) {
    const nodeNum = conn?.myNodeNum || 0;
    const user = conn?.nodeUsers.get(nodeNum) || {};
    return {
      label: user.longName || user.shortName || normalizeNodeId(user.id) || this.host || 'Meshtastic',
      nodeId: normalizeNodeId(user.id),
      host: this.host,
      channel: this.channel,
    };
  }

  async sendMessage(to, content) {
    if (this.status !== 'connected' || !this._transport) {
      throw new Error('Meshtastic is not connected');
    }

    const chatId = String(to || '').trim();
    if (chatId && chatId !== `channel:${this.channel}` && chatId !== String(this.channel)) {
      throw new Error(`Meshtastic is configured for channel ${this.channel}`);
    }

    await this._transport.connection.sendText(
      String(content || ''),
      this.channel,
      BROADCAST_NUM,
      true,
    );
    return { success: true };
  }

  async disconnect() {
    this._disconnecting = true;
    this.status = 'disconnected';
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = null;
    }

    const transport = this._transport;
    this._transport = null;

    if (transport) {
      await transport.disconnect().catch(() => {});
    }
  }

  async logout() {
    await this.disconnect();
  }

  getAuthInfo() {
    return this.authInfo || this._buildAuthInfo(this._transport?.connection);
  }
}

module.exports = {
  MeshtasticPlatform,
  parseChannel,
  parseTcpHost,
};
