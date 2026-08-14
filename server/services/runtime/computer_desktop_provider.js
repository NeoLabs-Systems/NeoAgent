'use strict';

const path = require('path');

class ComputerDesktopProvider {
  constructor(options = {}) {
    this.backend = options.backend;
    this.userId = String(options.userId || '').trim();
    this.artifactStore = options.artifactStore || null;
  }

  async #request(pathname, body = {}, options = {}) {
    if (!this.backend || !this.userId) {
      throw new Error('Cloud computer desktop is unavailable.');
    }
    const payload = body && typeof body === 'object' ? { ...body } : body;
    delete payload?.signal;
    return this.backend.requestGuest(this.userId, 'POST', pathname, payload, {
      signal: options.signal || body?.signal,
      timeoutMs: options.timeoutMs,
    });
  }

  async #materializeScreenshot(result, options = {}) {
    const guestPath = String(result?.path || '').trim();
    if (!guestPath || !this.artifactStore) return result;
    const client = await this.backend.getClientForUser(this.userId, options);
    const file = await client.request('POST', '/files/read', {
      path: guestPath,
      encoding: 'base64',
      delete_after_read: true,
    }, {
      signal: options.signal,
      timeoutMs: 30000,
      maxResponseBytes: 24 * 1024 * 1024,
      retryCount: 0,
    });
    const content = Buffer.from(String(file?.content || ''), 'base64');
    const artifact = await this.artifactStore.createBufferArtifact(this.userId, {
      kind: 'desktop-screenshot',
      backend: 'cloud-computer',
      extension: 'png',
      contentType: 'image/png',
      filenameBase: 'computer-screen',
      content,
      signal: options.signal,
    });
    return {
      ...result,
      screenshotPath: artifact.url,
      artifactId: artifact.artifactId,
      filename: path.basename(artifact.storagePath),
      fullPath: artifact.storagePath,
    };
  }

  async getStatus(options = {}) {
    const runtimeStatus = this.backend.vmManager.getStatus(this.userId);
    if (!this.backend.vmManager.hasTrackedVm(this.userId)) return runtimeStatus;
    try {
      const desktop = await this.backend.requestGuest(this.userId, 'GET', '/desktop/status', undefined, options);
      return { ...runtimeStatus, desktop };
    } catch {
      return runtimeStatus;
    }
  }

  async screenshot(options = {}) {
    const result = await this.#request('/desktop/screenshot', {}, options);
    return this.#materializeScreenshot(result, options);
  }

  async observe(options = {}) {
    const [status, screenshot] = await Promise.all([
      this.getStatus(options),
      this.screenshot(options),
    ]);
    return { ...status, ...screenshot };
  }

  clickPoint(x, y, options = {}) {
    return this.#request('/desktop/click', { x, y, button: options.button }, options);
  }

  mouseMove(x, y, options = {}) {
    return this.#request('/desktop/mouse-move', { x, y }, options);
  }

  drag(options = {}) {
    return this.#request('/desktop/drag', {
      startX: options.x1,
      startY: options.y1,
      endX: options.x2,
      endY: options.y2,
      durationMs: options.durationMs,
    }, options);
  }

  scroll(options = {}) {
    return this.#request('/desktop/scroll', {
      deltaX: options.deltaX,
      deltaY: options.deltaY,
    }, options);
  }

  async typeText(text, options = {}) {
    const result = await this.#request('/desktop/type-text', { text }, options);
    if (options.pressEnter) await this.pressKey('Return', options);
    return result;
  }

  pressKey(key, options = {}) {
    return this.#request('/desktop/press-key', { key }, options);
  }

  launchApp(options = {}) {
    return this.#request('/desktop/launch-app', { application: options.app }, options);
  }

  async getAccessibilityTree(options = {}) {
    const status = await this.getStatus(options);
    return {
      available: Boolean(status.desktop?.available),
      activeWindow: status.desktop?.activeWindow || null,
      nodes: [],
    };
  }
}

module.exports = { ComputerDesktopProvider };
