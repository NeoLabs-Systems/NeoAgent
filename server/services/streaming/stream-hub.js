'use strict';

const MAX_STREAM_FRAME_BYTES = 8 * 1024 * 1024;
const NO_SUBSCRIBER_GRACE_MS = Number(process.env.NEOAGENT_STREAM_NO_SUBSCRIBER_GRACE_MS || 15_000);

function normalizePlatform(platform) {
  const value = String(platform || '').trim().toLowerCase();
  return value || 'desktop';
}

function streamKey(userId, platform, deviceId) {
  return [
    String(userId || '').trim(),
    normalizePlatform(platform),
    String(deviceId || '').trim(),
  ].join(':');
}

class StreamHub {
  constructor(io) {
    this._io = io;
    this._subscribers = new Map();
    this._stats = new Map();
    this._activeStreams = new Map();
  }

  handleFrame(userId, deviceId, frame = {}) {
    const platform = normalizePlatform(frame.platform);
    const key = streamKey(userId, platform, deviceId);
    const subscribers = this._subscribers.get(key);
    if (
      !subscribers?.size
      || !Buffer.isBuffer(frame.jpeg)
      || frame.jpeg.length === 0
      || frame.jpeg.length > MAX_STREAM_FRAME_BYTES
    ) {
      return;
    }

    const now = Date.now();
    const stats = this._stats.get(key) || {
      frameCount: 0,
      bytesTotal: 0,
      lastFrameAt: 0,
      startedAt: now,
      windowFrameCount: 0,
      windowBytesTotal: 0,
      windowStartedAt: now,
      actualFps: 0,
      bytesPerSec: 0,
    };
    stats.frameCount += 1;
    stats.bytesTotal += frame.jpeg.length;
    stats.lastFrameAt = now;
    stats.windowFrameCount += 1;
    stats.windowBytesTotal += frame.jpeg.length;
    const windowMs = Math.max(1, now - stats.windowStartedAt);
    if (windowMs >= 1000) {
      stats.actualFps = Math.round((stats.windowFrameCount * 1000 / windowMs) * 10) / 10;
      stats.bytesPerSec = Math.round(stats.windowBytesTotal * 1000 / windowMs);
      stats.windowStartedAt = now;
      stats.windowFrameCount = 0;
      stats.windowBytesTotal = 0;
    }
    this._stats.set(key, stats);

    const active = this._activeStreams.get(key);
    const meta = {
      deviceId: String(deviceId || ''),
      platform: active?.platform || platform,
      seq: frame.seq ?? null,
      ts: frame.ts ?? null,
      flags: frame.flags ?? 0,
      capturedAt: now,
    };
    for (const socketId of subscribers) {
      this._io.to(socketId).volatile.emit('stream:frame', meta, frame.jpeg);
    }
  }

  subscribe(userId, deviceId, platform, socketId) {
    const key = streamKey(userId, platform, deviceId);
    if (!this._subscribers.has(key)) this._subscribers.set(key, new Set());
    this._subscribers.get(key).add(socketId);
    const active = this._activeStreams.get(key);
    if (active && platform) {
      active.platform = normalizePlatform(platform);
      if (active.noSubscriberTimer) {
        clearTimeout(active.noSubscriberTimer);
        active.noSubscriberTimer = null;
      }
    }
    return this.subscriberCount(userId, platform, deviceId);
  }

  async unsubscribe(userId, platform, deviceId, socketId) {
    const key = streamKey(userId, platform, deviceId);
    const subscribers = this._subscribers.get(key);
    if (!subscribers) return 0;
    subscribers.delete(socketId);
    const count = subscribers.size;
    if (count === 0) {
      this._subscribers.delete(key);
      await this.stopStream(userId, platform, deviceId, 'no_subscribers');
    }
    return count;
  }

  async unsubscribeAll(socketId) {
    const emptyKeys = [];
    for (const [key, subscribers] of this._subscribers.entries()) {
      subscribers.delete(socketId);
      if (subscribers.size === 0) emptyKeys.push(key);
    }
    for (const key of emptyKeys) {
      this._subscribers.delete(key);
      const active = this._activeStreams.get(key);
      if (active) {
        await this.stopStream(active.userId, active.platform, active.deviceId, 'socket_disconnected');
      }
    }
  }

  subscriberCount(userId, platform, deviceId) {
    return this._subscribers.get(streamKey(userId, platform, deviceId))?.size || 0;
  }

  markStarted(userId, deviceId, platform, options = {}, stop) {
    const normalizedPlatform = normalizePlatform(platform);
    const key = streamKey(userId, normalizedPlatform, deviceId);
    const active = {
      userId: String(userId || ''),
      deviceId: String(deviceId || ''),
      platform: normalizedPlatform,
      fps: Number(options.fps) || null,
      quality: Number(options.quality) || null,
      startedAt: Date.now(),
      noSubscriberTimer: null,
      stop: typeof stop === 'function' ? stop : null,
    };
    this._activeStreams.set(key, active);
    if (NO_SUBSCRIBER_GRACE_MS > 0 && this.subscriberCount(userId, normalizedPlatform, deviceId) === 0) {
      active.noSubscriberTimer = setTimeout(() => {
        void this.stopStream(userId, normalizedPlatform, deviceId, 'no_subscribers_initial');
      }, NO_SUBSCRIBER_GRACE_MS);
      active.noSubscriberTimer.unref?.();
    }
    if (!this._stats.has(key)) {
      this._stats.set(key, {
        frameCount: 0,
        bytesTotal: 0,
        lastFrameAt: 0,
        startedAt: Date.now(),
        windowFrameCount: 0,
        windowBytesTotal: 0,
        windowStartedAt: Date.now(),
        actualFps: 0,
        bytesPerSec: 0,
      });
    }
  }

  async stopStream(userId, platform, deviceId, reason = 'stopped') {
    const key = streamKey(userId, platform, deviceId);
    const active = this._activeStreams.get(key);
    if (!active) return false;
    this._activeStreams.delete(key);
    if (active.noSubscriberTimer) {
      clearTimeout(active.noSubscriberTimer);
      active.noSubscriberTimer = null;
    }
    if (active.stop) {
      await Promise.resolve(active.stop(reason)).catch((error) => {
        console.warn('[StreamHub] stream stop failed', {
          userId: active.userId,
          deviceId: active.deviceId,
          platform: active.platform,
          reason,
          error: String(error?.message || error),
        });
      });
    }
    return true;
  }

  status(userId, platform, deviceId) {
    const key = streamKey(userId, platform, deviceId);
    const active = this._activeStreams.get(key) || null;
    const stats = this._stats.get(key) || {};
    const normalizedPlatform = normalizePlatform(platform);
    return {
      streaming: Boolean(active),
      platform: active?.platform || normalizedPlatform,
      deviceId: active?.deviceId || String(deviceId || ''),
      fps: active?.fps || null,
      quality: active?.quality || null,
      subscriberCount: this.subscriberCount(userId, normalizedPlatform, deviceId),
      frameCount: stats.frameCount || 0,
      bytesTotal: stats.bytesTotal || 0,
      lastFrameAt: stats.lastFrameAt || null,
      actualFps: stats.actualFps || 0,
      bytesPerSec: stats.bytesPerSec || 0,
    };
  }

  listStatus(userId) {
    return Array.from(this._activeStreams.values())
      .filter((stream) => stream.userId === String(userId || '').trim())
      .map((stream) => this.status(userId, stream.platform, stream.deviceId))
      .filter((status) => status.deviceId || status.streaming || status.subscriberCount > 0);
  }

  async shutdown() {
    const streams = Array.from(this._activeStreams.values());
    this._activeStreams.clear();
    this._subscribers.clear();
    await Promise.allSettled(streams.map((stream) => {
      if (stream.noSubscriberTimer) clearTimeout(stream.noSubscriberTimer);
      if (!stream.stop) return null;
      return Promise.resolve(stream.stop('shutdown'));
    }));
  }
}

module.exports = {
  StreamHub,
  MAX_STREAM_FRAME_BYTES,
  NO_SUBSCRIBER_GRACE_MS,
  normalizePlatform,
  streamKey,
};
