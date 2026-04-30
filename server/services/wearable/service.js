'use strict';

const { getVersionInfo } = require('../../utils/version');
const { WEARABLE_WS_PATH } = require('./protocol');

function toTrimmedString(value, maxLength = 512) {
  return String(value || '').trim().slice(0, maxLength);
}

function toBoolean(value, fallback = false) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function parseOptionalJson(value, fallback = null) {
  if (!value) return fallback;
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : fallback;
  } catch {
    return fallback;
  }
}

function publicBaseUrlForRequest(req) {
  const configured = req.app?.locals?.httpRuntimeConfig?.publicUrl || process.env.PUBLIC_URL || '';
  if (configured) {
    return String(configured).replace(/\/+$/, '');
  }
  const forwardedProto = String(req.get?.('x-forwarded-proto') || '').trim();
  const protocol = forwardedProto || req.protocol || 'http';
  return `${protocol}://${req.get('host')}`;
}

function websocketUrlForBase(baseUrl) {
  const parsed = new URL(baseUrl);
  parsed.protocol = parsed.protocol === 'https:' ? 'wss:' : 'ws:';
  parsed.pathname = WEARABLE_WS_PATH;
  parsed.search = '';
  parsed.hash = '';
  return parsed.toString();
}

class WearableService {
  constructor({ app }) {
    this.app = app;
    this.connectionsByUser = new Map();
  }

  buildBootstrap(req) {
    const baseUrl = publicBaseUrlForRequest(req);
    const version = getVersionInfo();
    return {
      server: {
        baseUrl,
        websocketUrl: websocketUrlForBase(baseUrl),
        serverTime: new Date().toISOString(),
      },
      auth: {
        qrLoginChallengePath: '/api/auth/qr-login/challenge',
        qrLoginStatusPathTemplate: '/api/auth/qr-login/challenge/{challengeId}/status',
        qrLoginClaimPathTemplate: '/api/auth/qr-login/challenge/{challengeId}/claim',
        qrLoginResolvePath: '/api/account/qr-login/resolve',
        qrLoginApprovePath: '/api/account/qr-login/approve',
      },
      widgets: {
        snapshotsPath: '/api/widgets/snapshots',
      },
      voice: {
        websocketPath: WEARABLE_WS_PATH,
        supportsAudioStreaming: true,
        events: [
          'voice:session_ready',
          'voice:assistant_state',
          'voice:transcript_partial',
          'voice:transcript_final',
          'voice:assistant_text',
          'voice:audio_chunk',
          'voice:audio_done',
          'voice:error',
        ],
      },
      recordings: {
        basePath: '/api/recordings',
        voiceAssistantRespondPath: '/api/voice-assistant/respond',
      },
      firmware: this.buildFirmwareManifest(req),
      version,
      user: {
        id: req.session.userId,
        username: req.session.username || null,
      },
      features: {
        qrPairing: true,
        widgets: true,
        voice: true,
        recordings: true,
        otaManifest: true,
      },
    };
  }

  buildFirmwareManifest(req) {
    const baseUrl = publicBaseUrlForRequest(req);
    const version = getVersionInfo();
    const configuredVersion = toTrimmedString(process.env.NEOAGENT_WEARABLE_FIRMWARE_VERSION, 120);
    const downloadUrl = toTrimmedString(process.env.NEOAGENT_WEARABLE_FIRMWARE_DOWNLOAD_URL, 2000);
    const releaseNotesUrl = toTrimmedString(process.env.NEOAGENT_WEARABLE_FIRMWARE_RELEASE_NOTES_URL, 2000);
    const sha256 = toTrimmedString(process.env.NEOAGENT_WEARABLE_FIRMWARE_SHA256, 256).toLowerCase() || null;
    const channel = toTrimmedString(process.env.NEOAGENT_WEARABLE_FIRMWARE_CHANNEL, 64) || 'stable';
    const minAppVersion = toTrimmedString(process.env.NEOAGENT_WEARABLE_MIN_SERVER_VERSION, 120) || version.version;
    const rollout = parseOptionalJson(process.env.NEOAGENT_WEARABLE_FIRMWARE_ROLLOUT_JSON, null);
    return {
      configured: Boolean(downloadUrl),
      channel,
      manifestVersion: 1,
      currentVersion: configuredVersion || version.version,
      minimumServerVersion: minAppVersion,
      downloadUrl: downloadUrl || null,
      releaseNotesUrl: releaseNotesUrl || null,
      sha256,
      websocketUrl: websocketUrlForBase(baseUrl),
      generatedAt: new Date().toISOString(),
      rollout,
      mandatory: toBoolean(process.env.NEOAGENT_WEARABLE_FIRMWARE_MANDATORY, false),
    };
  }

  registerConnection({
    userId,
    ws,
    remoteAddress = null,
    userAgent = null,
    hello = {},
  }) {
    const key = Number(userId);
    const userSet = this.connectionsByUser.get(key) || new Map();
    const deviceId = [
      toTrimmedString(hello.device?.deviceId, 160),
      toTrimmedString(hello.device?.macAddress, 64),
      toTrimmedString(ws?._socket?.remoteAddress, 120),
    ].find(Boolean) || `wearable-${Date.now()}`;
    const connection = {
      deviceId,
      ws,
      connectedAt: new Date().toISOString(),
      remoteAddress: toTrimmedString(remoteAddress, 120) || null,
      userAgent: toTrimmedString(userAgent, 500) || null,
      hello: {
        platform: toTrimmedString(hello.device?.platform, 40) || 'esp32s3',
        firmwareVersion: toTrimmedString(hello.device?.firmwareVersion, 120) || null,
        deviceLabel: toTrimmedString(hello.device?.deviceLabel, 120) || null,
      },
      lastSeenAt: new Date().toISOString(),
    };
    userSet.set(deviceId, connection);
    this.connectionsByUser.set(key, userSet);
    return connection;
  }

  touchConnection(userId, deviceId) {
    const userSet = this.connectionsByUser.get(Number(userId));
    const connection = userSet?.get(String(deviceId || '').trim());
    if (connection) {
      connection.lastSeenAt = new Date().toISOString();
    }
  }

  unregisterConnection(userId, deviceId) {
    const userSet = this.connectionsByUser.get(Number(userId));
    if (!userSet) return;
    userSet.delete(String(deviceId || '').trim());
    if (userSet.size === 0) {
      this.connectionsByUser.delete(Number(userId));
    }
  }

  listConnections(userId) {
    const userSet = this.connectionsByUser.get(Number(userId));
    if (!userSet) return [];
    return Array.from(userSet.values()).map((entry) => ({
      deviceId: entry.deviceId,
      connectedAt: entry.connectedAt,
      lastSeenAt: entry.lastSeenAt,
      remoteAddress: entry.remoteAddress,
      userAgent: entry.userAgent,
      hello: entry.hello,
    }));
  }
}

module.exports = {
  WEARABLE_WS_PATH,
  WearableService,
  publicBaseUrlForRequest,
  websocketUrlForBase,
};
