const fs = require('fs');
const path = require('path');
const { DATA_DIR } = require('../../../../runtime/paths');
const { EXTENSION_COMMANDS, ExtensionBrowserUnavailableError } = require('./protocol');

const SCREENSHOTS_DIR = path.join(DATA_DIR, 'screenshots');
if (!fs.existsSync(SCREENSHOTS_DIR)) fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });

function extractBase64Png(value) {
  const text = String(value || '');
  if (!text) return null;
  const match = text.match(/^data:image\/png;base64,(.+)$/);
  return match ? match[1] : text;
}

class ExtensionBrowserProvider {
  constructor(options = {}) {
    this.registry = options.registry;
    this.userId = options.userId != null ? String(options.userId) : null;
    this.tokenId = options.tokenId ? String(options.tokenId) : null;
    this.artifactStore = options.artifactStore || null;
    this.headless = false;
    this.providerType = 'extension';
  }

  #assertReady() {
    if (!this.registry || this.userId == null) {
      throw new ExtensionBrowserUnavailableError();
    }
  }

  async #dispatch(command, payload = {}, options = {}) {
    this.#assertReady();
    const result = await this.registry.dispatch(this.userId, command, payload, {
      ...options,
      tokenId: options.tokenId || this.tokenId,
    });
    return this.#materialize(result);
  }

  #disconnect() {
    if (!this.registry || this.userId == null) return;
    const connection = this.registry.getConnection(this.userId, this.tokenId);
    if (connection) {
      connection.close('browser extension provider closed');
    }
  }

  #writeScreenshotArtifact(base64) {
    const buffer = Buffer.from(base64, 'base64');
    if (this.artifactStore && this.userId != null) {
      const artifact = this.artifactStore.allocateFile(this.userId, {
        kind: 'browser-screenshot',
        backend: 'extension',
        extension: 'png',
        contentType: 'image/png',
        filenameBase: 'browser-extension-screenshot',
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

    const filename = `browser_extension_${Date.now()}_${Math.random().toString(16).slice(2)}.png`;
    const fullPath = path.join(SCREENSHOTS_DIR, filename);
    fs.writeFileSync(fullPath, buffer);
    return {
      screenshotPath: `/screenshots/${filename}`,
      artifactId: null,
      filename,
      fullPath,
    };
  }

  #materialize(result) {
    if (!result || typeof result !== 'object') return result;
    const raw = result.screenshotDataUrl || result.screenshotData || result.screenshotBase64;
    if (!raw) return result;
    const base64 = extractBase64Png(raw);
    if (!base64) return result;
    const screenshot = this.#writeScreenshotArtifact(base64);
    const next = { ...result, ...screenshot };
    delete next.screenshotDataUrl;
    delete next.screenshotData;
    delete next.screenshotBase64;
    return next;
  }

  navigate(url, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.NAVIGATE, { url, ...options });
  }

  click(selector, text, screenshot = true) {
    return this.#dispatch(EXTENSION_COMMANDS.CLICK, { selector, text, screenshot });
  }

  clickPoint(x, y, screenshot = true) {
    return this.#dispatch(EXTENSION_COMMANDS.CLICK_POINT, { x, y, screenshot });
  }

  type(selector, text, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.TYPE, { selector, text, ...options });
  }

  typeText(text, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.TYPE_TEXT, { text, ...options });
  }

  pressKey(key, screenshot = true) {
    return this.#dispatch(EXTENSION_COMMANDS.PRESS_KEY, { key, screenshot });
  }

  scroll(deltaX = 0, deltaY = 0, screenshot = true) {
    return this.#dispatch(EXTENSION_COMMANDS.SCROLL, { deltaX, deltaY, screenshot });
  }

  extract(selector, attribute, all = false) {
    return this.#dispatch(EXTENSION_COMMANDS.EXTRACT, { selector, attribute, all });
  }

  evaluate(script) {
    return this.#dispatch(EXTENSION_COMMANDS.EVALUATE, { script });
  }

  screenshot(options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.SCREENSHOT, options);
  }

  launch(options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.LAUNCH, options);
  }

  async closeBrowser() {
    if (!this.registry || this.userId == null || !this.registry.isConnected(this.userId, this.tokenId)) {
      return { success: true, extensionConnected: false };
    }
    const result = await this.#dispatch(EXTENSION_COMMANDS.CLOSE, {});
    this.#disconnect();
    return { ...result, success: result?.success !== false, extensionConnected: false };
  }

  fill(selector, value) {
    return this.type(selector, String(value));
  }

  extractContent(options = {}) {
    return this.extract(options.selector, options.attribute, options.all);
  }

  executeJS(code) {
    return this.evaluate(code);
  }

  async getPageInfo() {
    if (!this.registry || this.userId == null || !this.registry.isConnected(this.userId, this.tokenId)) {
      return { url: null, title: null, extensionConnected: false };
    }
    return this.registry.dispatch(this.userId, EXTENSION_COMMANDS.GET_PAGE_INFO, {}, {
      tokenId: this.tokenId,
    });
  }

  isLaunched() {
    return Boolean(this.registry && this.userId != null && this.registry.isConnected(this.userId, this.tokenId));
  }

  getPageCount() {
    return this.isLaunched() ? 1 : 0;
  }

  setHeadless() {
    this.headless = false;
    return Promise.resolve({ success: false, unsupported: true });
  }
}

module.exports = {
  ExtensionBrowserProvider,
  extractBase64Png,
};
