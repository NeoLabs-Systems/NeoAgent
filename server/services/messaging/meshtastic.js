'use strict';

const { BasePlatform } = require('./base');
const { readMeshtasticEnabled } = require('./meshtastic_env');
const { MeshtasticTcpTransport } = require('./meshtastic_tcp_transport');

const DEFAULT_TCP_PORT = 4403;
const DEFAULT_CHANNEL = 0;

let meshtasticModulesPromise = null;

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

async function loadMeshtasticModules() {
  if (!meshtasticModulesPromise) {
    meshtasticModulesPromise = import('@meshtastic/core').then((core) => ({
      MeshDevice: core.MeshDevice,
      Types: core.Types,
      createTransport: (hostname, port, timeout) =>
        MeshtasticTcpTransport.create(core, hostname, port, timeout),
    })).catch((error) => {
      meshtasticModulesPromise = null;
      const message = String(error?.message || error || '');
      if (
        error?.code === 'ERR_MODULE_NOT_FOUND'
        || /Cannot find package '@meshtastic\/core'/.test(message)
        || /Cannot find module '@meshtastic\/core'/.test(message)
      ) {
        throw new Error(
          'Meshtastic support is not installed. Install @meshtastic/core or disable the Meshtastic integration.'
        );
      }
      throw error;
    });
  }
  return meshtasticModulesPromise;
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
    this._device = null;
    this._modules = null;
    this._connectPromise = null;
    this._disconnecting = false;
    this._configured = false;
    this._lastMyNodeInfo = null;
    this._lastNodeUsers = new Map();
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
    this._configured = false;
    this._lastMyNodeInfo = null;
    this._lastNodeUsers.clear();
    this.status = 'connecting';

    const modules = await loadMeshtasticModules();
    this._modules = modules;

    const transport = await modules.createTransport(this.host, this.port, 60000);
    this._transport = transport;

    const device = new modules.MeshDevice(transport);
    this._device = device;
    this._wireDeviceEvents(device, modules.Types);

    const ready = new Promise((resolve, reject) => {
      let settled = false;
      const resolveOnce = () => {
        if (settled) return;
        settled = true;
        resolve({ status: this.status });
      };
      const rejectOnce = (error) => {
        if (settled) return;
        settled = true;
        reject(error);
      };

      device.events.onDeviceStatus.subscribe((status) => {
        if (status === modules.Types.DeviceStatusEnum.DeviceConnected) {
          device.configure().catch((error) => {
            if (!this._disconnecting) {
              rejectOnce(error);
            }
          });
          return;
        }

        if (status === modules.Types.DeviceStatusEnum.DeviceConfigured) {
          this._configured = true;
          this.status = 'connected';
          this.authInfo = this._buildAuthInfo();
          this.emit('connected');
          resolveOnce();
          return;
        }

        if (status === modules.Types.DeviceStatusEnum.DeviceDisconnected) {
          this.status = 'disconnected';
          if (!this._disconnecting) {
            const error = new Error('Meshtastic device disconnected');
            rejectOnce(error);
            this.emit('disconnected', { reason: 'device_disconnected' });
          }
        }
      });
    });

    await ready;
    return { status: this.status };
  }

  _wireDeviceEvents(device, Types) {
    device.events.onMyNodeInfo.subscribe((info) => {
      this._lastMyNodeInfo = info;
      this.authInfo = this._buildAuthInfo();
    });

    device.events.onUserPacket.subscribe((packet) => {
      const user = packet?.data;
      const from = Number(packet?.from || 0);
      if (!user || !Number.isFinite(from) || from <= 0) return;
      this._lastNodeUsers.set(from, user);
    });

    device.events.onMessagePacket.subscribe((packet) => {
      if (!packet) return;
      const channel = Number(packet.channel);
      if (channel !== this.channel) return;

      const senderNum = Number(packet.from || 0);
      const localNodeNum = Number(this._lastMyNodeInfo?.myNodeNum || 0);
      if (senderNum > 0 && localNodeNum > 0 && senderNum === localNodeNum) {
        return;
      }
      const senderUser = this._lastNodeUsers.get(senderNum) || null;
      const senderName = senderUser?.longName || senderUser?.shortName || null;
      const senderUsername = normalizeNodeId(senderUser?.id || '');
      const chatId = `channel:${channel}`;

      const access = this._checkInboundAccess({
        platform: this.name,
        senderId: String(senderNum || ''),
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
        sender: String(senderNum || ''),
        senderName,
        senderUsername: senderUsername || null,
        senderTag: senderUsername || null,
        content: String(packet.data || ''),
        mediaType: null,
        isGroup: true,
        messageId: String(packet.id || `${Date.now()}`),
        timestamp: toIsoTimestamp(packet.rxTime),
        metadata: {
          channel,
          host: this.host,
          meshNodeId: senderUsername || null,
          meshDestination: packet.type || 'broadcast',
        },
        rawMessage: {
          id: packet.id,
          from: packet.from,
          to: packet.to,
          type: packet.type,
          channel: packet.channel,
        },
      });
    });
  }

  _buildAuthInfo() {
    const info = this._lastMyNodeInfo || {};
    const user = info.user || {};
    return {
      label: user.longName || user.shortName || normalizeNodeId(user.id) || this.host || 'Meshtastic',
      nodeId: normalizeNodeId(user.id),
      host: this.host,
      channel: this.channel,
    };
  }

  async sendMessage(to, content) {
    if (this.status !== 'connected' || !this._device || !this._modules) {
      throw new Error('Meshtastic is not connected');
    }

    const chatId = String(to || '').trim();
    if (chatId && chatId !== `channel:${this.channel}` && chatId !== String(this.channel)) {
      throw new Error(`Meshtastic is configured for channel ${this.channel}`);
    }

    await this._device.sendText(
      String(content || ''),
      'broadcast',
      true,
      this.channel,
    );
    return { success: true };
  }

  async disconnect() {
    this._disconnecting = true;
    this.status = 'disconnected';

    const device = this._device;
    const transport = this._transport;
    this._device = null;
    this._transport = null;
    this._configured = false;

    if (device && typeof device.disconnect === 'function') {
      await device.disconnect().catch(() => {});
    } else if (transport && typeof transport.disconnect === 'function') {
      await transport.disconnect().catch(() => {});
    }
  }

  async logout() {
    await this.disconnect();
  }

  getAuthInfo() {
    return this.authInfo || this._buildAuthInfo();
  }
}

module.exports = {
  MeshtasticPlatform,
  parseChannel,
  parseTcpHost,
};
