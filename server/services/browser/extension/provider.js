'use strict';

const fs = require('fs');
const path = require('path');
const { DATA_DIR } = require('../../../../runtime/paths');
const { writeBufferAtomic } = require('../../../utils/files');
const { decodeBase64Image } = require('../../../utils/image_payload');
const { EXTENSION_COMMANDS, ExtensionBrowserUnavailableError } = require('./protocol');

const SCREENSHOTS_DIR = path.join(DATA_DIR, 'screenshots');
if (!fs.existsSync(SCREENSHOTS_DIR)) fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });

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
    const safePayload = { ...(payload || {}) };
    const signal = options.signal || safePayload.signal || null;
    const timeoutMs = options.timeoutMs ?? safePayload.timeoutMs;
    delete safePayload.signal;
    delete safePayload.timeoutMs;
    const result = await this.registry.dispatch(this.userId, command, safePayload, {
      ...options,
      signal,
      timeoutMs,
      tokenId: options.tokenId || this.tokenId,
    });
    return this.#materialize(result, { signal });
  }

  #disconnect() {
    if (!this.registry || this.userId == null) return;
    const connection = this.registry.getConnection(this.userId, this.tokenId);
    if (connection) {
      connection.close('browser extension provider closed');
    }
  }

  async #writeScreenshotArtifact(image, options = {}) {
    if (this.artifactStore && this.userId != null) {
      const artifact = await this.artifactStore.createBufferArtifact(this.userId, {
        kind: 'browser-screenshot',
        backend: 'extension',
        extension: image.extension,
        contentType: image.contentType,
        filenameBase: 'browser-extension-screenshot',
        content: image.buffer,
        signal: options.signal,
      });
      return {
        screenshotPath: artifact.url,
        artifactId: artifact.artifactId,
        filename: path.basename(artifact.storagePath),
        fullPath: artifact.storagePath,
      };
    }

    const filename = `browser_extension_${Date.now()}_${Math.random().toString(16).slice(2)}.png`;
    const fullPath = path.join(SCREENSHOTS_DIR, filename);
    await writeBufferAtomic(fullPath, image.buffer, { signal: options.signal });
    return {
      screenshotPath: `/screenshots/${filename}`,
      artifactId: null,
      filename,
      fullPath,
    };
  }

  async #materialize(result, options = {}) {
    if (!result || typeof result !== 'object') return result;
    const raw = result.screenshotDataUrl || result.screenshotData || result.screenshotBase64;
    if (!raw) return result;
    const image = decodeBase64Image(raw, { allowedTypes: ['image/png'] });
    const screenshot = await this.#writeScreenshotArtifact(image, options);
    const next = { ...result, ...screenshot };
    delete next.screenshotDataUrl;
    delete next.screenshotData;
    delete next.screenshotBase64;
    return next;
  }

  navigate(url, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.NAVIGATE, { url, ...options }, options);
  }

  click(selector, text, screenshot = true, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.CLICK, { selector, text, screenshot }, options);
  }

  clickPoint(x, y, screenshot = true, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.CLICK_POINT, { x, y, screenshot }, options);
  }

  type(selector, text, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.TYPE, { selector, text, ...options }, options);
  }

  typeText(text, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.TYPE_TEXT, { text, ...options }, options);
  }

  pressKey(key, screenshot = true, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.PRESS_KEY, { key, screenshot }, options);
  }

  scroll(deltaX = 0, deltaY = 0, screenshot = true, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.SCROLL, { deltaX, deltaY, screenshot }, options);
  }

  extract(selector, attribute, all = false, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.EXTRACT, { selector, attribute, all }, options);
  }

  evaluate(script, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.EVALUATE, { script }, options);
  }

  screenshot(options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.SCREENSHOT, options, options);
  }

  launch(options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.LAUNCH, options, options);
  }

  async closeBrowser(options = {}) {
    if (!this.registry || this.userId == null || !this.registry.isConnected(this.userId, this.tokenId)) {
      return { success: true, extensionConnected: false };
    }
    const result = await this.#dispatch(EXTENSION_COMMANDS.CLOSE, {}, options);
    this.#disconnect();
    return { ...result, success: result?.success !== false, extensionConnected: false };
  }

  fill(selector, value, options = {}) {
    return this.type(selector, String(value), options);
  }

  fillCredential(input, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.FILL_CREDENTIAL, input, options);
  }

  submitProtectedCredential(protectedFillId, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.SUBMIT_CREDENTIAL, { protectedFillId }, options);
  }

  cancelProtectedCredential(protectedFillId, options = {}) {
    return this.#dispatch(EXTENSION_COMMANDS.CANCEL_CREDENTIAL, { protectedFillId }, options);
  }

  extractContent(options = {}) {
    return this.extract(options.selector, options.attribute, options.all, options);
  }

  executeJS(code, options = {}) {
    return this.evaluate(code, options);
  }

  async getPageInfo(options = {}) {
    if (!this.registry || this.userId == null || !this.registry.isConnected(this.userId, this.tokenId)) {
      return { url: null, title: null, extensionConnected: false };
    }
    return this.registry.dispatch(this.userId, EXTENSION_COMMANDS.GET_PAGE_INFO, {}, {
      tokenId: this.tokenId,
      signal: options.signal,
    });
  }

  async getCookies(options = {}) {
    const pageInfo = await this.getPageInfo(options);
    let hostname = '';
    try { hostname = new URL(String(pageInfo?.url || '')).hostname; } catch {}
    if (!hostname) return { cookies: [], domains: [] };
    return this.#dispatch(EXTENSION_COMMANDS.GET_COOKIES, {
      domains: [hostname],
    }, options);
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
};
