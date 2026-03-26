'use strict';

const fs = require('fs');
const path = require('path');
const db = require('../../db/database');
const { v4: uuidv4 } = require('uuid');

// Load built-in protocols
const builtInProtocols = [
  require('./protocols/heypocket'),
  require('./protocols/omi'),
  require('./protocols/plaud'),
  require('./protocols/friend'),
  require('./protocols/limitless'),
  require('./protocols/bee'),
  require('./protocols/frame'),
];

class WearableManager {
  constructor(io, services) {
    this.io = io;
    this.recordingManager = services.recordingManager;
    this.protocols = new Map();
    this.activeLiveStreams = new Map();

    for (const protocol of builtInProtocols) {
      this.protocols.set(protocol.id, protocol);
    }
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
    if (!this.protocols.has(protocolId)) {
      throw new Error(`Unsupported wearable protocol: ${protocolId}`);
    }

    const device = this.getDevice(userId, macAddress);
    const now = new Date().toISOString();

    if (device) {
      db.prepare(`
        UPDATE wearable_devices 
        SET protocol = ?, name = ?, status = 'connected', last_seen_at = ?, updated_at = ?
        WHERE id = ?
      `).run(protocolId, name || device.name, now, now, device.id);

      this.#emitUpdate(userId, device.id);
      return this.getDevice(userId, macAddress);
    }

    const id = uuidv4();
    db.prepare(`
      INSERT INTO wearable_devices (id, user_id, mac_address, protocol, name, status, last_seen_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, 'connected', ?, ?, ?)
    `).run(id, userId, macAddress, protocolId, name || 'Unknown Device', now, now, now);

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
          sourceKey: macAddress,
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
      startTime: Date.now()
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

    db.prepare(`UPDATE wearable_devices SET last_seen_at = ?, status = 'connected' WHERE id = ?`).run(new Date().toISOString(), device.id);

    return result;
  }

  endLiveStream(userId, macAddress) {
    const streamKey = `${userId}:${macAddress}`;
    const streamState = this.activeLiveStreams.get(streamKey);
    if (streamState) {
      try {
        this.recordingManager.finalizeSession(userId, streamState.sessionId, { stopReason: 'wearable_disconnected' });
      } catch (err) {
        console.error('[Wearables] Error finalizing session on disconnect', err);
      }
      this.activeLiveStreams.delete(streamKey);
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
          sourceKey: macAddress,
          sourceKind: 'wearable-mic',
          mediaKind: 'audio',
          mimeType: protocol.mimeType,
          metadata: { deviceId: device.id, protocol: protocol.id }
        }
      ]
    });

    this.recordingManager.appendChunk(userId, session.id, {
      sourceKey: macAddress.toLowerCase(),
      sequenceIndex: 0,
      startMs: 0,
      endMs: processedBuffer.length,
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
}

module.exports = WearableManager;
