'use strict';

const { getVersionInfo } = require('../../utils/version');
const { clientIpFromRequest, lookupIpLocation } = require('../account/geoip');
const { WEARABLE_WS_PATH } = require('./protocol');
const {
  resolveFirmwareManifest,
  normalizeChannel,
} = require('./firmware_manifest');

function toTrimmedString(value, maxLength = 512) {
  return String(value || '').trim().slice(0, maxLength);
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

function parseTimeZoneOffsetLabel(value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  if (raw === 'GMT' || raw === 'UTC') return 0;
  const match = raw.match(/^(?:GMT|UTC)([+-])(\d{1,2})(?::?(\d{2}))?$/i);
  if (!match) return null;
  const sign = match[1] === '-' ? -1 : 1;
  const hours = Number(match[2] || 0);
  const minutes = Number(match[3] || 0);
  if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return null;
  return sign * ((hours * 60 * 60) + (minutes * 60));
}

function utcOffsetSecondsForTimeZone(timeZone, now = new Date()) {
  const normalized = String(timeZone || '').trim();
  if (!normalized) return null;
  try {
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: normalized,
      timeZoneName: 'shortOffset',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    });
    const zonePart = formatter.formatToParts(now).find((part) => part.type === 'timeZoneName');
    return parseTimeZoneOffsetLabel(zonePart?.value || '');
  } catch {
    return null;
  }
}

class WearableService {
  constructor({ app }) {
    this.app = app;
    this.connectionsByUser = new Map();
  }

  async buildBootstrap(req) {
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
      firmware: await this.buildFirmwareManifest(req),
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

  async buildFirmwareManifest(req) {
    const baseUrl = publicBaseUrlForRequest(req);
    const channel = normalizeChannel(req?.query?.channel || process.env.NEOAGENT_WEARABLE_FIRMWARE_CHANNEL || 'stable');
    const version = getVersionInfo();
    const manifest = await resolveFirmwareManifest({
      channel,
      repositoryOverride: toTrimmedString(process.env.NEOAGENT_WEARABLE_FIRMWARE_GITHUB_REPOSITORY, 256),
      assetNameOverride: toTrimmedString(process.env.NEOAGENT_WEARABLE_FIRMWARE_ASSET_NAME, 128),
    });
    return {
      ...manifest,
      websocketUrl: websocketUrlForBase(baseUrl),
      minimumServerVersion: manifest.minimumServerVersion || version.version,
      rollout: parseOptionalJson(process.env.NEOAGENT_WEARABLE_FIRMWARE_ROLLOUT_JSON, null),
    };
  }

  buildTimeConfig(req) {
    const now = new Date();
    const clientIp = req ? clientIpFromRequest(req) : null;
    const detectedTimeZone = String(lookupIpLocation(clientIp).data?.timezone || '').trim();
    const fallbackTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
    const timeZone = detectedTimeZone || fallbackTimeZone;
    const offsetSeconds =
      utcOffsetSecondsForTimeZone(timeZone, now)
      ?? utcOffsetSecondsForTimeZone(fallbackTimeZone, now)
      ?? (-now.getTimezoneOffset() * 60);
    return {
      timezone: timeZone,
      utcOffsetSeconds: offsetSeconds,
      serverTime: now.toISOString(),
      source: detectedTimeZone ? 'client_ip_geoip' : 'server_fallback',
      ipAddress: clientIp || null,
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
