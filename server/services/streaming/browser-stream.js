'use strict';

const fs = require('fs');
const sharp = require('sharp');

function clampInt(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(parsed)));
}

class BrowserStream {
  constructor({ userId, deviceId = 'browser', controller, streamHub, fps = 15, quality = 80 }) {
    this.userId = String(userId || '');
    this.deviceId = String(deviceId || 'browser');
    this.controller = controller;
    this.streamHub = streamHub;
    this.fps = clampInt(fps, 15, 1, 20);
    this.quality = clampInt(quality, 80, 30, 95);
    this._timer = null;
    this._capturing = false;
    this._seq = 0;
  }

  start() {
    if (this._timer) return;
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
  }

  async _captureOnce() {
    if (this._capturing) return;
    this._capturing = true;
    try {
      const jpeg = await this._captureJpeg();
      if (!jpeg?.length) return;
      this.streamHub.handleFrame(this.userId, this.deviceId, {
        jpeg,
        platform: 'browser',
        seq: this._seq++ >>> 0,
        ts: Date.now() >>> 0,
        flags: 1,
      });
    } catch (error) {
      console.warn('[BrowserStream] frame capture failed', {
        userId: this.userId,
        deviceId: this.deviceId,
        error: String(error?.message || error),
      });
    } finally {
      this._capturing = false;
    }
  }

  async _captureJpeg() {
    if (!this.controller) {
      throw new Error('Browser controller is unavailable.');
    }
    if (typeof this.controller.screenshotJpeg === 'function') {
      return this.controller.screenshotJpeg(this.quality);
    }
    if (typeof this.controller.screenshot !== 'function') {
      throw new Error('Browser streaming requires a screenshot-capable controller.');
    }
    const result = await this.controller.screenshot({ fullPage: false });
    if (!result?.fullPath || !fs.existsSync(result.fullPath)) {
      throw new Error('Browser screenshot did not produce a readable file.');
    }
    const png = fs.readFileSync(result.fullPath);
    return sharp(png).jpeg({ quality: this.quality }).toBuffer();
  }
}

module.exports = {
  BrowserStream,
};
