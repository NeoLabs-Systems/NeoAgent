'use strict';

const fs = require('fs');
const path = require('path');
const db = require('../../db/database');
const { v4: uuidv4 } = require('uuid');

// Load built-in protocols
const builtInProtocols = [
  require('./protocols/heypocket'),
];
const SUPPORTED_PROTOCOL_ID = 'heypocket';
const STREAM_IDLE_TIMEOUT_MS = 60 * 1000;
const STREAM_REAPER_INTERVAL_MS = 5 * 1000;

function normalizeProtocolId(protocolId) {
  const normalized = String(protocolId || '').trim().toLowerCase();
  if (normalized === 'heypocket') {
    return SUPPORTED_PROTOCOL_ID;
  }
  return normalized;
}

class WearableManager {
  constructor(io, services) {
    this.io = io;
    this.recordingManager = services.recordingManager;
    this.protocols = new Map();
    this.activeLiveStreams = new Map();

    for (const protocol of builtInProtocols) {
      this.protocols.set(protocol.id, protocol);
    }

    this._reaperHandle = setInterval(() => {
      this.reapStaleLiveStreams();
    }, STREAM_REAPER_INTERVAL_MS);
    this._reaperHandle.unref?.();

    // Keep runtime deterministic while only HeyPocket is supported.
    db.prepare(`UPDATE wearable_devices SET protocol = ? WHERE LOWER(protocol) <> ?`)
      .run(SUPPORTED_PROTOCOL_ID, SUPPORTED_PROTOCOL_ID);
  }

  getProtocol(id) {
    return this.protocols.get(id);
  }

  getProtocols() {
    return Array.from(this.protocols.values()).map(p => ({
      id: p.id,
      name: p.name,
      mimeType: p.mimeType
    }));
  }

  getDevice(userId, macAddress) {
    return db.prepare(`SELECT * FROM wearable_devices WHERE user_id = ? AND mac_address = ?`).get(userId, macAddress);
  }

  registerDevice(userId, macAddress, protocolId, name) {
    const normalizedProtocolId = normalizeProtocolId(protocolId);
    if (!this.protocols.has(normalizedProtocolId)) {
      throw new Error(`Unsupported wearable protocol: ${protocolId}`);
    }

    const device = this.getDevice(userId, macAddress);
    const now = new Date().toISOString();

    if (device) {
      db.prepare(`
        UPDATE wearable_devices 
        SET protocol = ?, name = ?, status = 'connected', last_seen_at = ?, updated_at = ?
        WHERE id = ?
      `).run(normalizedProtocolId, name || device.name, now, now, device.id);

      this.#emitUpdate(userId, device.id);
      return this.getDevice(userId, macAddress);
    }

    const id = uuidv4();
    db.prepare(`
      INSERT INTO wearable_devices (id, user_id, mac_address, protocol, name, status, last_seen_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, 'connected', ?, ?, ?)
    `).run(id, userId, macAddress, normalizedProtocolId, name || 'Unknown Device', now, now, now);

    this.#emitUpdate(userId, id);
    return this.getDevice(userId, macAddress);
  }

  updateStatus(userId, macAddress, status, batteryLevel = null) {
    const device = this.getDevice(userId, macAddress);
    if (!device) return null;

    const now = new Date().toISOString();

    if (status === 'disconnected') {
      this.endLiveStream(userId, macAddress);
    }

    db.prepare(`
      UPDATE wearable_devices 
      SET status = ?, battery_level = COALESCE(?, battery_level), last_seen_at = ?, updated_at = ?
      WHERE id = ?
    `).run(status, batteryLevel, now, now, device.id);

    this.#emitUpdate(userId, device.id);
    return this.getDevice(userId, macAddress);
  }

  startLiveStream(userId, macAddress) {
    const device = this.getDevice(userId, macAddress);
    if (!device) throw new Error('Device not found');

    const protocol = this.getProtocol(device.protocol);
    if (!protocol) throw new Error('Protocol not found');

    const streamKey = `${userId}:${macAddress}`;
    if (this.activeLiveStreams.has(streamKey)) {
      return this.activeLiveStreams.get(streamKey);
    }

    const session = this.recordingManager.createSession(userId, {
      title: `Wearable Recording: ${device.name}`,
      platform: 'wearable',
      sources: [
        {
          sourceKey: macAddress.toLowerCase(),
          sourceKind: 'wearable-mic',
          mediaKind: 'audio',
          mimeType: protocol.mimeType,
          metadata: { deviceId: device.id, protocol: protocol.id }
        }
      ]
    });

    this.activeLiveStreams.set(streamKey, {
      sessionId: session.id,
      sequenceIndex: 0,
      startTime: Date.now(),
      lastChunkAt: Date.now(),
    });

    return session;
  }

  handleLiveStreamChunk(userId, macAddress, rawBuffer, context = {}) {
    const device = this.getDevice(userId, macAddress);
    if (!device) throw new Error('Device not found');

    const protocol = this.getProtocol(device.protocol);
    if (!protocol) throw new Error('Protocol not found');

    const audioBuffer = protocol.parseAudioPayload(rawBuffer, { characteristicUuid: context?.characteristicUuid });

    const potentialBattery = protocol.extractBatteryLevel(rawBuffer, { characteristicUuid: context?.characteristicUuid });
    if (potentialBattery !== null) {
      this.updateStatus(userId, macAddress, 'connected', potentialBattery);
      this.broadcastBattery(userId, macAddress, potentialBattery);
    }

    if (!audioBuffer) {
      return null;
    }

    const streamKey = `${userId}:${macAddress}`;
    let streamState = this.activeLiveStreams.get(streamKey);
    if (!streamState) {
      this.startLiveStream(userId, macAddress);
      streamState = this.activeLiveStreams.get(streamKey);
    }

    if (!streamState) {
      throw new Error('Failed to create or retrieve live stream');
    }

    const startMs = Date.now() - streamState.startTime;
    const sourceKey = macAddress.toLowerCase();

    const result = this.recordingManager.appendChunk(
      userId,
      streamState.sessionId,
      {
        sourceKey: sourceKey,
        sequenceIndex: streamState.sequenceIndex++,
        startMs: startMs,
        endMs: startMs + 1000,
        mimeType: protocol.mimeType
      },
      audioBuffer
    );

    streamState.lastChunkAt = Date.now();

    db.prepare(`UPDATE wearable_devices SET last_seen_at = ?, status = 'connected' WHERE id = ?`).run(new Date().toISOString(), device.id);

    return result;
  }

  endLiveStream(userId, macAddress, stopReason = 'wearable_disconnected') {
    const streamKey = `${userId}:${macAddress}`;
    const streamState = this.activeLiveStreams.get(streamKey);
    if (!streamState) {
      return this.#finalizeDanglingSession(userId, macAddress, stopReason);
    }

    try {
      this.recordingManager.finalizeSession(userId, streamState.sessionId, { stopReason });
    } catch (err) {
      console.error('[Wearables] Error finalizing session on disconnect', err);
    }
    this.activeLiveStreams.delete(streamKey);
    return true;
  }

  stopLiveStream(userId, macAddress, stopReason = 'wearable_stopped') {
    return this.endLiveStream(userId, macAddress, stopReason);
  }

  #finalizeDanglingSession(userId, macAddress, stopReason) {
    const sourceKey = `${macAddress || ''}`.trim().toLowerCase();
    if (!sourceKey) {
      return false;
    }

    const row = db.prepare(`
      SELECT rs.id AS session_id
      FROM recording_sessions rs
      INNER JOIN recording_sources src ON src.session_id = rs.id
      WHERE rs.user_id = ?
        AND rs.status = 'recording'
        AND LOWER(src.source_key) = LOWER(?)
      ORDER BY datetime(rs.created_at) DESC
      LIMIT 1
    `).get(userId, sourceKey);

    if (!row?.session_id) {
      return false;
    }

    try {
      this.recordingManager.finalizeSession(userId, row.session_id, { stopReason });
      return true;
    } catch (err) {
      console.error('[Wearables] Error finalizing dangling session', err);
      return false;
    }
  }

  reapStaleLiveStreams() {
    const now = Date.now();
    for (const [streamKey, streamState] of this.activeLiveStreams.entries()) {
      if (!streamState || typeof streamState.lastChunkAt !== 'number') {
        continue;
      }
      if (now - streamState.lastChunkAt < STREAM_IDLE_TIMEOUT_MS) {
        continue;
      }

      const separatorIndex = streamKey.indexOf(':');
      if (separatorIndex <= 0 || separatorIndex >= streamKey.length - 1) {
        continue;
      }
      const userId = streamKey.slice(0, separatorIndex);
      const macAddress = streamKey.slice(separatorIndex + 1);
      try {
        this.endLiveStream(userId, macAddress, 'wearable_idle_timeout');
      } catch (err) {
        console.error('[Wearables] Error finalizing stale live stream', err);
      }
    }
  }

  async syncOfflineAudio(userId, macAddress, fileBuffer) {
    const device = this.getDevice(userId, macAddress);
    if (!device) throw new Error('Device not found');

    const protocol = this.getProtocol(device.protocol);
    if (!protocol) throw new Error('Protocol not found');

    const processedBuffer = await protocol.processOfflineSync(fileBuffer);

    const session = this.recordingManager.createSession(userId, {
      title: `Wearable Sync: ${device.name}`,
      platform: 'wearable',
      sources: [
        {
          sourceKey: macAddress.toLowerCase(),
          sourceKind: 'wearable-mic',
          mediaKind: 'audio',
          mimeType: protocol.mimeType,
          metadata: { deviceId: device.id, protocol: protocol.id }
        }
      ]
    });

    const durationMs = this.#estimateOfflineDurationMs(protocol, processedBuffer);

    this.recordingManager.appendChunk(userId, session.id, {
      sourceKey: macAddress.toLowerCase(),
      sequenceIndex: 0,
      startMs: 0,
      endMs: durationMs,
      mimeType: protocol.mimeType
    }, processedBuffer);

    this.recordingManager.finalizeSession(userId, session.id);

    return session;
  }

  listDevices(userId) {
    return db.prepare(`SELECT * FROM wearable_devices WHERE user_id = ? ORDER BY last_seen_at DESC`).all(userId);
  }

  #emitUpdate(userId, deviceId) {
    if (this.io) {
      this.io.to(`user:${userId}`).emit('wearable:update', { deviceId });
    }
  }

  broadcastBattery(userId, macAddress, level) {
    if (this.io) {
      this.io.to(`user:${userId}`).emit('wearable:battery', { macAddress, level });
    }
  }

  #estimateOfflineDurationMs(protocol, processedBuffer) {
    const byteLength = Buffer.isBuffer(processedBuffer) ? processedBuffer.length : 0;
    if (byteLength <= 0) {
      return 0;
    }

    const sampleRate = Number(protocol?.sampleRate);
    const channels = Number(protocol?.channels || 1);
    const bytesPerSample = Number(protocol?.bytesPerSample || 2);
    if (sampleRate > 0 && channels > 0 && bytesPerSample > 0) {
      const bytesPerSecond = sampleRate * channels * bytesPerSample;
      return Math.max(1, Math.round((byteLength / bytesPerSecond) * 1000));
    }

    if (protocol?.mimeType === 'audio/mpeg') {
      const bitrateKbps = Number(protocol?.bitrateKbps || 32);
      const bytesPerSecond = (bitrateKbps * 1000) / 8;
      return Math.max(1, Math.round((byteLength / bytesPerSecond) * 1000));
    }

    return 0;
  }
}

module.exports = WearableManager;
