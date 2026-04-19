const fs = require('fs');
const path = require('path');
const { DATA_DIR } = require('../../../runtime/paths');
const {
  DESKTOP_COMMANDS,
  DesktopCompanionSelectionError,
  DesktopCompanionUnavailableError,
} = require('./protocol');

const SCREENSHOTS_DIR = path.join(DATA_DIR, 'screenshots');
if (!fs.existsSync(SCREENSHOTS_DIR)) fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });

function extractBase64Image(value) {
  const text = String(value || '');
  if (!text) return null;
  const match = text.match(/^data:image\/(?:png|jpeg|jpg);base64,(.+)$/i);
  return match ? match[1] : text;
}

function guessExtension(result = {}) {
  const mime = String(result.contentType || result.mimeType || 'image/png').toLowerCase();
  if (mime.includes('jpeg') || mime.includes('jpg')) return 'jpg';
  return 'png';
}

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

  _writeScreenshotArtifact(base64, result = {}) {
    const buffer = Buffer.from(base64, 'base64');
    const extension = guessExtension(result);
    const contentType = result.contentType || (extension === 'jpg' ? 'image/jpeg' : 'image/png');
    if (this.artifactStore && this.userId != null) {
      const artifact = this.artifactStore.allocateFile(this.userId, {
        kind: 'desktop-screenshot',
        backend: 'desktop-companion',
        extension,
        contentType,
        filenameBase: 'desktop-companion-screenshot',
        metadata: {
          deviceId: result.device?.deviceId || null,
          displayId: result.displayId || result.device?.activeDisplayId || null,
        },
      });
      fs.writeFileSync(artifact.storagePath, buffer);
      this.artifactStore.finalizeFile(artifact.artifactId, artifact.storagePath);
      return {
        screenshotPath: artifact.url,
        artifactId: artifact.artifactId,
        filename: path.basename(artifact.storagePath),
        fullPath: artifact.storagePath,
      };
    }

    const filename = `desktop_${Date.now()}_${Math.random().toString(16).slice(2)}.${extension}`;
    const fullPath = path.join(SCREENSHOTS_DIR, filename);
    fs.writeFileSync(fullPath, buffer);
    return {
      screenshotPath: `/screenshots/${filename}`,
      artifactId: null,
      filename,
      fullPath,
    };
  }

  _materialize(result) {
    if (!result || typeof result !== 'object') return result;
    const raw = result.screenshotDataUrl || result.screenshotData || result.screenshotBase64;
    if (!raw) return result;
    const base64 = extractBase64Image(raw);
    if (!base64) return result;
    const screenshot = this._writeScreenshotArtifact(base64, result);
    const next = { ...result, ...screenshot };
    delete next.screenshotDataUrl;
    delete next.screenshotData;
    delete next.screenshotBase64;
    return next;
  }

  async _dispatch(command, payload = {}, options = {}) {
    this._assertReady();
    try {
      return this._materialize(
        await this.registry.dispatch(this.userId, payload.deviceId || null, command, payload, options),
      );
    } catch (error) {
      if (error instanceof DesktopCompanionSelectionError || error instanceof DesktopCompanionUnavailableError) {
        throw error;
      }
      throw error;
    }
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

  pauseDevice(deviceId, paused = true) {
    this._assertReady();
    return this.registry.pause(this.userId, deviceId, paused);
  }

  screenshot(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.CAPTURE_FRAME, options);
  }

  observe(options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.OBSERVE, options);
  }

  clickPoint(x, y, options = {}) {
    return this._dispatch(DESKTOP_COMMANDS.CLICK, { ...options, x, y });
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
}

module.exports = {
  DesktopProvider,
};
