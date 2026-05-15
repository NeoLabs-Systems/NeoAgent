const fs = require('fs');
const path = require('path');
const { DATA_DIR } = require('../../../../runtime/paths');

const APK_UPLOAD_ROOT = path.resolve(
  process.env.NEOAGENT_ANDROID_APK_BASE_DIR
    || path.join(DATA_DIR, 'uploads', 'android-apks'),
);
const MAX_APK_BYTES = Number(process.env.NEOAGENT_ANDROID_APK_MAX_BYTES || 512 * 1024 * 1024);
const IDLE_TIMEOUT_MS = Number(process.env.NEOAGENT_VM_IDLE_TIMEOUT_MS || 10 * 60 * 1000);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function assertPathInside(baseDir, candidatePath, label) {
  const resolvedBase = path.resolve(baseDir);
  const resolvedCandidate = path.resolve(candidatePath);
  const relativePath = path.relative(resolvedBase, resolvedCandidate);
  if (
    relativePath.startsWith('..')
    || path.isAbsolute(relativePath)
    || relativePath === ''
  ) {
    throw new Error(`${label} is outside the allowed directory.`);
  }
  return resolvedCandidate;
}

function isPidAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) {
    return false;
  }
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

class RuntimeHttpClient {
  constructor(baseUrl, token = '', options = {}) {
    this.baseUrl = String(baseUrl || '').replace(/\/+$/, '');
    this.token = String(token || '').trim();
    this.onActivity = options.onActivity || null;
  }

  async waitForHealth(options = {}) {
    const timeoutMs = Number(options.timeoutMs || 600000); // Increased from 120s to 10m for bootstrap
    const intervalMs = Number(options.intervalMs || 1000);
    const checkLiveness = options.checkLiveness || (() => true);
    const startedAt = Date.now();
    let lastError = null;

    while (Date.now() - startedAt < timeoutMs) {
      if (!checkLiveness()) {
        throw new Error('Guest runtime process exited unexpectedly during bootstrap.');
      }
      const elapsed = Math.round((Date.now() - startedAt) / 1000);
      try {
        const health = await this.request('GET', '/health', undefined, { timeoutMs: 2000 });
        if (health?.status === 'ok') {
          console.log(`[Runtime] Guest agent ready after ${elapsed}s`);
          return health;
        }
        lastError = new Error('Guest agent health check returned a non-ok status.');
      } catch (error) {
        lastError = error;
        if (elapsed % 10 === 0) {
          console.log(`[Runtime] Waiting for guest agent health... (${elapsed}s elapsed, last error: ${error.message})`);
        }
      }
      await new Promise((resolve) => setTimeout(resolve, intervalMs));
    }

    if (lastError) {
      throw new Error(`Timed out waiting for the guest runtime to become ready: ${lastError.message}`);
    }
    throw new Error('Timed out waiting for the guest runtime to become ready.');
  }

  async request(method, pathname, body, options = {}) {
    const retryCount = Math.max(0, Number(options.retryCount ?? 6));
    const retryDelayMs = Math.max(100, Number(options.retryDelayMs ?? 1000));
    let lastError = null;

    for (let attempt = 0; attempt <= retryCount; attempt += 1) {
      const controller = options.timeoutMs ? new AbortController() : null;
      const timer = controller ? setTimeout(() => controller.abort(new Error(`Request timed out after ${options.timeoutMs} ms.`)), options.timeoutMs) : null;
      try {
        const response = await fetch(`${this.baseUrl}${pathname}`, {
          method,
          headers: {
            'content-type': 'application/json',
            ...(this.token ? { authorization: `Bearer ${this.token}` } : {}),
          },
          body: body === undefined ? undefined : JSON.stringify(body),
          signal: controller?.signal,
        });

        const contentType = response.headers.get('content-type') || '';
        const payload = contentType.includes('application/json')
          ? await response.json().catch(() => ({}))
          : { text: await response.text().catch(() => '') };

        if (!response.ok) {
          const errorMessage = payload?.error || payload?.text || `Runtime request failed: ${response.status}`;
          throw new Error(errorMessage);
        }
        if (typeof this.onActivity === 'function') {
          this.onActivity();
        }
        return payload;
      } catch (error) {
        lastError = error;
        const message = String(error?.message || error);
        const retryable = /fetch failed|ECONNREFUSED|ECONNRESET|socket hang up|timed out/i.test(message);
        if (!retryable || attempt === retryCount) {
          throw error;
        }
        await new Promise((resolve) => setTimeout(resolve, retryDelayMs));
      } finally {
        if (timer) {
          clearTimeout(timer);
        }
      }
    }

    throw lastError || new Error('Runtime request failed.');
  }

  async requestStream(method, pathname, stream, options = {}) {
    const response = await fetch(`${this.baseUrl}${pathname}`, {
      method,
      headers: {
        ...(options.contentType ? { 'content-type': options.contentType } : {}),
        ...(options.contentLength != null ? { 'content-length': String(options.contentLength) } : {}),
        ...(options.headers || {}),
        ...(this.token ? { authorization: `Bearer ${this.token}` } : {}),
      },
      body: stream,
      duplex: 'half',
    });

    if (response.ok && typeof this.onActivity === 'function') {
      this.onActivity();
    }

    const contentType = response.headers.get('content-type') || '';
    const payload = contentType.includes('application/json')
      ? await response.json().catch(() => ({}))
      : { text: await response.text().catch(() => '') };

    if (!response.ok) {
      const errorMessage = payload?.error || payload?.text || `Runtime request failed: ${response.status}`;
      throw new Error(errorMessage);
    }
    return payload;
  }
}

class VmBrowserProvider {
  constructor(client, options = {}) {
    this.client = client;
    this.userId = options.userId;
    this.artifactStore = options.artifactStore || null;
    this.headless = true;
  }

  async #materialize(result) {
    if (!result || !this.artifactStore || this.userId == null) {
      return result;
    }

    const readablePathCandidates = [];
    if (result.fullPath) {
      readablePathCandidates.push(String(result.fullPath));
    }
    if (typeof result.screenshotPath === 'string' && result.screenshotPath.trim() !== '') {
      readablePathCandidates.push(result.screenshotPath);
    }
    if (readablePathCandidates.length === 0) {
      return result;
    }

    let file = null;
    const maxAttempts = 20;
    for (let attempt = 0; attempt < maxAttempts && !file?.content; attempt += 1) {
      for (const candidate of readablePathCandidates) {
        try {
          file = await this.client.request('POST', '/files/read', {
            path: candidate,
            encoding: 'base64',
          });
          if (file?.content) {
            break;
          }
        } catch (error) {
          if (attempt === maxAttempts - 1) {
            console.warn('[Runtime:browser_vm] screenshot materialization read failed', {
              userId: this.userId,
              candidate,
              error: String(error?.message || error),
            });
          }
        }
      }
      if (!file?.content) {
        await sleep(250);
      }
    }
    if (!file?.content) {
      if (typeof result.screenshotPath === 'string' && result.screenshotPath.trim() !== '') {
        console.warn('[Runtime:browser_vm] unresolved VM screenshot path suppressed', {
          userId: this.userId,
          screenshotPath: result.screenshotPath,
        });
        return {
          ...result,
          screenshotPath: null,
          artifactId: result.artifactId || null,
          fullPath: result.fullPath || null,
        };
      }
      return result;
    }

    const allocation = this.artifactStore.allocateFile(this.userId, {
      kind: 'browser-screenshot',
      backend: 'vm',
      extension: 'png',
      contentType: 'image/png',
      filenameBase: 'browser-screenshot',
    });
    fs.writeFileSync(allocation.storagePath, Buffer.from(String(file.content || ''), 'base64'));
    this.artifactStore.finalizeFile(allocation.artifactId, allocation.storagePath);
    return {
      ...result,
      screenshotPath: allocation.url,
      artifactId: allocation.artifactId,
      fullPath: allocation.storagePath,
    };
  }

  async navigate(url, options = {}) { return this.#materialize(await this.client.request('POST', '/browser/navigate', { url, ...options })); }
  async click(selector, text, screenshot = true) { return this.#materialize(await this.client.request('POST', '/browser/click', { selector, text, screenshot })); }
  async clickPoint(x, y, screenshot = true) { return this.#materialize(await this.client.request('POST', '/browser/click-point', { x, y, screenshot })); }
  async type(selector, text, options = {}) { return this.#materialize(await this.client.request('POST', '/browser/fill', { selector, value: text, ...options })); }
  async typeText(text, options = {}) { return this.#materialize(await this.client.request('POST', '/browser/type-text', { text, ...options })); }
  async pressKey(key, screenshot = true) { return this.#materialize(await this.client.request('POST', '/browser/press-key', { key, screenshot })); }
  async scroll(deltaX, deltaY, screenshot = true) { return this.#materialize(await this.client.request('POST', '/browser/scroll', { deltaX, deltaY, screenshot })); }
  extract(selector, attribute, all = false) { return this.client.request('POST', '/browser/extract', { selector, attribute, all }); }
  evaluate(script) { return this.client.request('POST', '/browser/execute', { code: script }); }
  async screenshot(options = {}) { return this.#materialize(await this.client.request('POST', '/browser/screenshot', options)); }
  launch(options = {}) { return this.client.request('POST', '/browser/launch', options); }
  closeBrowser() { return this.client.request('POST', '/browser/close'); }
  fill(selector, value) { return this.type(selector, value); }
  extractContent(options = {}) { return this.client.request('POST', '/browser/extract', options); }
  executeJS(code) { return this.evaluate(code); }
  async getPageInfo() {
    const status = await this.client.request('GET', '/browser/status');
    this.headless = status?.headless !== false;
    return status?.pageInfo || null;
  }
  async isLaunched() {
    const status = await this.client.request('GET', '/browser/status');
    this.headless = status?.headless !== false;
    return status?.launched === true;
  }
  async getPageCount() {
    const status = await this.client.request('GET', '/browser/status');
    return Number(status?.pages || 0);
  }
  async setHeadless(value) {
    this.headless = true;
    return { success: true };
  }
}

class LocalVmExecutionBackend {
  constructor(options = {}) {
    this.vmManager = options.vmManager;
    this.runtimeProfile = options.runtimeProfile === 'android' ? 'android' : 'browser_cli';
    this.token = options.token || process.env.NEOAGENT_VM_GUEST_TOKEN || '';
    this.artifactStore = options.artifactStore || null;
    this.lastActivity = new Map();
    this.reaperInterval = null;

    if (IDLE_TIMEOUT_MS > 0) {
      this.#startIdleReaper();
    }
  }

  #touch(userId) {
    const key = String(userId || '').trim();
    if (key) {
      this.lastActivity.set(key, Date.now());
    }
  }

  #startIdleReaper() {
    if (this.reaperInterval) return;
    this.reaperInterval = setInterval(async () => {
      const now = Date.now();
      for (const [userId, lastUsed] of this.lastActivity.entries()) {
        if (now - lastUsed > IDLE_TIMEOUT_MS) {
          console.log(`[Runtime:${this.runtimeProfile}] User ${userId} runtime idle for ${Math.round((now - lastUsed) / 1000)}s, shutting down VM.`);
          this.lastActivity.delete(userId);
          try {
            await this.vmManager?.killVm?.(userId);
          } catch (err) {
            console.error(`[Runtime:${this.runtimeProfile}] Failed to shut down idle VM for user ${userId}:`, err.message);
          }
        }
      }
    }, Math.min(IDLE_TIMEOUT_MS, 60 * 1000));
  }

  async #clientForUser(userId) {
    if (!this.vmManager) {
      throw new Error('Local VM manager is not available.');
    }
    const session = await this.vmManager.ensureVm(userId);
    this.#touch(userId);
    const client = new RuntimeHttpClient(session.baseUrl, session.guestToken || this.token, {
      onActivity: () => this.#touch(userId),
    });
    try {
      await client.waitForHealth({
        timeoutMs: Number(process.env.NEOAGENT_VM_BOOT_TIMEOUT_MS || 20 * 60 * 1000),
        checkLiveness: () => {
          const key = String(userId || '').trim();
          const session = this.vmManager.instances.get(key);
          return Boolean(session && session.process && isPidAlive(session.process.pid));
        },
      });
    } catch (error) {
      const runtimeError = typeof session.getLastError === 'function' ? session.getLastError() : '';
      const detail = runtimeError ? ` ${runtimeError}` : '';
      throw new Error(`${error.message}${detail}`.trim());
    }
    return client;
  }

  async executeCommand(userId, command, options = {}) {
    const client = await this.#clientForUser(userId);
    return client.request('POST', '/exec', {
      command,
      cwd: options.cwd,
      timeout: options.timeout,
      stdin_input: options.stdinInput,
      pty: options.pty === true,
      inputs: options.inputs || [],
    });
  }

  async killCommand(userId, pid, reason = 'aborted') {
    const client = await this.#clientForUser(userId);
    return client.request('POST', '/exec/kill', {
      pid,
      reason,
    });
  }

  async getBrowserProviderForUser(userId) {
    return new VmBrowserProvider(await this.#clientForUser(userId), {
      userId,
      artifactStore: this.artifactStore,
    });
  }

  async getCommandExecutorForUser(userId) {
    return {
      execute: (command, options = {}) => this.executeCommand(userId, command, options),
      executeInteractive: (command, inputs = [], options = {}) => this.executeCommand(userId, command, {
        ...options,
        pty: true,
        inputs,
      }),
      kill: (pid, reason = 'aborted') => this.killCommand(userId, pid, reason),
    };
  }

  async isGuestAgentReadyForUser(userId, timeoutMs = 1000) {
    if (!this.vmManager) {
      return false;
    }
    const key = String(userId || '').trim();
    if (!key) {
      return false;
    }
    const session = this.vmManager.instances?.get?.(key);
    if (!session?.baseUrl) {
      return false;
    }
    const client = new RuntimeHttpClient(session.baseUrl, this.token);
    try {
      await client.request('GET', '/health', undefined, { timeoutMs });
      return true;
    } catch {
      return false;
    }
  }

  async shutdown() {
    if (this.reaperInterval) {
      clearInterval(this.reaperInterval);
      this.reaperInterval = null;
    }
    await this.vmManager?.shutdown?.();
  }
}

module.exports = {
  LocalVmExecutionBackend,
  RuntimeHttpClient,
  VmBrowserProvider,
};
