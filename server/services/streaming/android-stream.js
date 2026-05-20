'use strict';

const sharp = require('sharp');

function clampInt(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(parsed)));
}

class AndroidStream {
  constructor({ userId, deviceId, controller, streamHub, fps = 10, quality = 75 }) {
    this.userId = String(userId || '');
    this.deviceId = String(deviceId || '');
    this.controller = controller;
    this.streamHub = streamHub;
    this.fps = clampInt(fps, 10, 1, 15);
    this.quality = clampInt(quality, 75, 30, 95);
    this._timer = null;
    this._capturing = false;
    this._seq = 0;
    this._lastErrorLogAt = 0;
    this._stopped = true;
  }

  start() {
    if (this._timer) return;
    this._stopped = false;
    const interval = Math.max(1, Math.floor(1000 / this.fps));
    this._timer = setInterval(() => {
      void this._captureOnce();
    }, interval);
    this._timer.unref?.();
    void this._captureOnce();
  }

  stop() {
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
    this._stopped = true;
  }

  async _captureOnce() {
    if (this._capturing) return;
    this._capturing = true;
    try {
      if (!this.controller || typeof this.controller.capturePng !== 'function') {
        throw new Error('Android streaming requires a controller with capturePng().');
      }
      const png = await this.controller.capturePng({ deviceId: this.deviceId });
      if (this._stopped || !png?.length) return;
      const jpeg = await sharp(png)
        .jpeg({ quality: this.quality, mozjpeg: false })
        .toBuffer();
      if (this._stopped) return;
      this.streamHub.handleFrame(this.userId, this.deviceId, {
        jpeg,
        platform: 'android',
        seq: this._seq++ >>> 0,
        ts: Date.now() >>> 0,
        flags: 1,
      });
    } catch (error) {
      const now = Date.now();
      if (now - this._lastErrorLogAt > 10_000) {
        this._lastErrorLogAt = now;
        console.warn('[AndroidStream] frame capture failed', {
          userId: this.userId,
          deviceId: this.deviceId,
          error: String(error?.message || error),
        });
      }
    } finally {
      this._capturing = false;
    }
  }
}

module.exports = {
  AndroidStream,
};
