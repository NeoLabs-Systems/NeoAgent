'use strict';

const fs = require('fs');
const path = require('path');
const { DATA_DIR } = require('../../../runtime/paths');
const { writeBufferAtomic } = require('../../utils/files');
const { decodeBase64Image } = require('../../utils/image_payload');
const {
  DESKTOP_COMMANDS,
  DesktopCompanionUnavailableError,
} = require('./protocol');

const SCREENSHOTS_DIR = path.join(DATA_DIR, 'screenshots');
if (!fs.existsSync(SCREENSHOTS_DIR)) fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });

class DesktopProvider {
  constructor(options = {}) {
    this.registry = options.registry;
    this.userId = options.userId != null ? String(options.userId) : null;
    this.artifactStore = options.artifactStore || null;
  }

  _assertReady() {
    if (!this.registry || this.userId == null) {
      throw new DesktopCompanionUnavailableError();
    }
  }

  async _writeScreenshotArtifact(image, result = {}, options = {}) {
    if (this.artifactStore && this.userId != null) {
      const artifact = await this.artifactStore.createBufferArtifact(this.userId, {
        kind: 'desktop-screenshot',
        backend: 'desktop-companion',
        extension: image.extension,
        contentType: image.contentType,
        filenameBase: 'desktop-companion-screenshot',
        content: image.buffer,
        signal: options.signal,
        metadata: {
          deviceId: result.device?.deviceId || null,
          displayId: result.displayId || result.device?.activeDisplayId || null,
        },
      });
      return {
        screenshotPath: artifact.url,
        artifactId: artifact.artifactId,
        filename: path.basename(artifact.storagePath),
        fullPath: artifact.storagePath,
      };
    }

    const filename = `desktop_${Date.now()}_${Math.random().toString(16).slice(2)}.${image.extension}`;
    const fullPath = path.join(SCREENSHOTS_DIR, filename);
    await writeBufferAtomic(fullPath, image.buffer, { signal: options.signal });
    return {
      screenshotPath: `/screenshots/${filename}`,
      artifactId: null,
      filename,
      fullPath,
    };
  }

  async _materialize(result, options = {}) {
    if (!result || typeof result !== 'object') return result;
    const raw = result.screenshotDataUrl || result.screenshotData || result.screenshotBase64;
    if (!raw) return result;
    const image = decodeBase64Image(raw, {
      allowedTypes: ['image/png', 'image/jpeg'],
    });
    const screenshot = await this._writeScreenshotArtifact(image, result, options);
    const next = { ...result, ...screenshot };
    delete next.screenshotDataUrl;
    delete next.screenshotData;
    delete next.screenshotBase64;
    return next;
  }

  async _dispatch(command, payload = {}, options = {}) {
    this._assertReady();
    const safePayload = { ...(payload || {}) };
    const signal = options.signal || safePayload.signal || null;
    const timeoutMs = options.timeoutMs ?? safePayload.timeoutMs;
    delete safePayload.signal;
    delete safePayload.timeoutMs;
    const result = await this.registry.dispatch(
      this.userId,
      safePayload.deviceId || null,
      command,
      safePayload,
      { ...options, signal, timeoutMs },
    );
    return this._materialize(result, { signal });
  }

  getStatus() {
    this._assertReady();
    return this.registry.getStatus(this.userId);
  }

  listDevices() {
    this._assertReady();
    return this.registry.listDevices(this.userId);
  }

  selectDevice(deviceId) {
    this._assertReady();
    return this.registry.setSelectedDeviceId(this.userId, deviceId);
  }

  revokeDevice(deviceId) {
    this._assertReady();
    return this.registry.revoke(this.userId, deviceId);
  }

  pauseDevice(deviceId, paused = true, options = {}) {
    this._assertReady();
    return this.registry.pause(this.userId, deviceId, paused, options);
  }

  screenshot(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.CAPTURE_FRAME, options);
  }

  startStream(options = {}) {
    this._assertReady();
    return this.registry.startStream(this.userId, options.deviceId || null, options);
  }

  stopStream(options = {}) {
    this._assertReady();
    return this.registry.stopStream(this.userId, options.deviceId || null, options);
  }

  observe(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.OBSERVE, options);
  }

  clickPoint(x, y, options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.CLICK, { ...options, x, y });
  }

  mouseMove(x, y, options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.MOUSE_MOVE, { ...options, x, y });
  }

  drag(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.DRAG, options);
  }

  scroll(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.SCROLL, options);
  }

  typeText(text, options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.TYPE_TEXT, { ...options, text });
  }

  pressKey(key, options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.PRESS_KEY, { ...options, key });
  }

  launchApp(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.LAUNCH_APP, options);
  }

  listDisplays(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.LIST_DISPLAYS, options);
  }

  selectDisplay(displayId, options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.SELECT_DISPLAY, { ...options, displayId });
  }

  getAccessibilityTree(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.GET_TREE, options);
  }

  executeCommand(command, options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.EXECUTE_COMMAND, {
      command,
      cwd: options.cwd || null,
      timeout: options.timeout || null,
      stdin_input: options.stdinInput || null,
      pty: options.pty === true,
      inputs: options.inputs || [],
      signal: options.signal,
    }, {
      signal: options.signal,
      timeoutMs: Number(options.timeout || 0) > 0
        ? Number(options.timeout) + 10_000
        : undefined,
    });
  }
}

module.exports = {
  DesktopProvider,
};
