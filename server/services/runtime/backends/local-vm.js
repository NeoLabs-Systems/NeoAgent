'use strict';

const fs = require('fs');
const path = require('path');
const { DATA_DIR } = require('../../../../runtime/paths');
const { fetchResponseText, waitForAbortableResult } = require('../../network/http');
const { createAbortError } = require('../../../utils/abort');

const APK_UPLOAD_ROOT = path.resolve(
  process.env.NEOAGENT_ANDROID_APK_BASE_DIR
    || path.join(DATA_DIR, 'uploads', 'android-apks'),
);
const MAX_APK_BYTES = Number(process.env.NEOAGENT_ANDROID_APK_MAX_BYTES || 512 * 1024 * 1024);
const IDLE_TIMEOUT_MS = Number(process.env.NEOAGENT_VM_IDLE_TIMEOUT_MS || 10 * 60 * 1000);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function abortError(signal, fallback = 'Operation aborted.') {
  return createAbortError(signal, fallback);
}

function delayWithSignal(ms, signal) {
  if (signal?.aborted) return Promise.reject(abortError(signal));
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      clearTimeout(timer);
      reject(abortError(signal));
    };
    signal?.addEventListener('abort', onAbort, { once: true });
  });
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
      if (options.signal?.aborted) throw abortError(options.signal);
      if (!checkLiveness()) {
        throw new Error('Guest runtime process exited unexpectedly during bootstrap.');
      }
      const elapsed = Math.round((Date.now() - startedAt) / 1000);
      try {
        const health = await this.request('GET', '/health', undefined, {
          timeoutMs: 2000,
          signal: options.signal,
        });
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
      await delayWithSignal(intervalMs, options.signal);
    }

    if (lastError) {
      throw new Error(`Timed out waiting for the guest runtime to become ready: ${lastError.message}`);
    }
    throw new Error('Timed out waiting for the guest runtime to become ready.');
  }

  async request(method, pathname, body, options = {}) {
    const normalizedMethod = String(method || 'GET').toUpperCase();
    const safeToRetry = ['GET', 'HEAD', 'OPTIONS'].includes(normalizedMethod);
    const retryCount = Math.max(0, Number(options.retryCount ?? (safeToRetry ? 6 : 0)));
    const retryDelayMs = Math.max(100, Number(options.retryDelayMs ?? 1000));
    let lastError = null;

    for (let attempt = 0; attempt <= retryCount; attempt += 1) {
      if (options.signal?.aborted) throw abortError(options.signal);
      try {
        const { response, text } = await fetchResponseText(`${this.baseUrl}${pathname}`, {
          method: normalizedMethod,
          headers: {
            'content-type': 'application/json',
            ...(this.token ? { authorization: `Bearer ${this.token}` } : {}),
          },
          body: body === undefined ? undefined : JSON.stringify(body),
          signal: options.signal,
          timeoutMs: Number(options.timeoutMs || 30000),
          maxResponseBytes: Number(options.maxResponseBytes || 32 * 1024 * 1024),
          serviceName: 'Guest runtime',
          timeoutCode: 'RUNTIME_HTTP_TIMEOUT',
          tooLargeCode: 'RUNTIME_HTTP_RESPONSE_TOO_LARGE',
        });

        const contentType = response.headers.get('content-type') || '';
        let payload = { text };
        if (contentType.includes('application/json')) {
          try {
            payload = JSON.parse(text);
          } catch {
            payload = {};
          }
        }

        if (!response.ok) {
          const errorMessage = payload?.error || payload?.text || `Runtime request failed: ${response.status}`;
          const error = new Error(errorMessage);
          error.status = response.status;
          throw error;
        }
        if (typeof this.onActivity === 'function') {
          this.onActivity();
        }
        return payload;
      } catch (error) {
        if (options.signal?.aborted) throw abortError(options.signal);
        lastError = error;
        const message = String(error?.message || error);
        const retryable = /fetch failed|ECONNREFUSED|ECONNRESET|socket hang up|timed out/i.test(message);
        if (!retryable || attempt === retryCount) {
          throw error;
        }
        await delayWithSignal(retryDelayMs, options.signal);
      }
    }

    throw lastError || new Error('Runtime request failed.');
  }

  async requestStream(method, pathname, stream, options = {}) {
    const retryCount = 0;
    const retryDelayMs = Math.max(100, Number(options.retryDelayMs ?? 1000));
    let lastError = null;

    for (let attempt = 0; attempt <= retryCount; attempt += 1) {
      if (options.signal?.aborted) throw abortError(options.signal);
      try {
        const { response, text } = await fetchResponseText(`${this.baseUrl}${pathname}`, {
          method,
          headers: {
            ...(options.contentType ? { 'content-type': options.contentType } : {}),
            ...(options.contentLength != null ? { 'content-length': String(options.contentLength) } : {}),
            ...(options.headers || {}),
            ...(this.token ? { authorization: `Bearer ${this.token}` } : {}),
          },
          body: stream,
          duplex: 'half',
          signal: options.signal,
          timeoutMs: Number(options.timeoutMs || 60000),
          maxResponseBytes: Number(options.maxResponseBytes || 2 * 1024 * 1024),
          serviceName: 'Guest runtime upload',
          timeoutCode: 'RUNTIME_HTTP_TIMEOUT',
          tooLargeCode: 'RUNTIME_HTTP_RESPONSE_TOO_LARGE',
        });

        if (response.ok && typeof this.onActivity === 'function') {
          this.onActivity();
        }

        const contentType = response.headers.get('content-type') || '';
        let payload = { text };
        if (contentType.includes('application/json')) {
          try {
            payload = JSON.parse(text);
          } catch {
            payload = {};
          }
        }

        if (!response.ok) {
          const errorMessage = payload?.error || payload?.text || `Runtime request failed: ${response.status}`;
          const error = new Error(errorMessage);
          error.status = response.status;
          throw error;
        }
        return payload;
      } catch (error) {
        if (options.signal?.aborted) throw abortError(options.signal);
        lastError = error;
        const message = String(error?.message || error);
        const retryable = /fetch failed|ECONNREFUSED|ECONNRESET|socket hang up|timed out/i.test(message);
        if (!retryable || attempt === retryCount) {
          throw error;
        }
        await delayWithSignal(retryDelayMs, options.signal);
      }
    }

    throw lastError || new Error('Runtime request failed.');
  }
}

class VmBrowserProvider {
  constructor(client, options = {}) {
    this.client = client;
    this.userId = options.userId;
    this.artifactStore = options.artifactStore || null;
    this.headless = true;
  }

  async #request(method, pathname, body, options = {}) {
    const payload = body && typeof body === 'object' ? { ...body } : body;
    const signal = options.signal || payload?.signal || null;
    if (payload && typeof payload === 'object') delete payload.signal;
    return this.client.request(method, pathname, payload, {
      timeoutMs: Number(options.timeoutMs || 120_000),
      signal,
    });
  }

  async #materialize(result, options = {}) {
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
      if (options.signal?.aborted) throw abortError(options.signal);
      for (const candidate of readablePathCandidates) {
        try {
          file = await this.#request('POST', '/files/read', {
            path: candidate,
            encoding: 'base64',
          }, { signal: options.signal, timeoutMs: 10_000 });
          if (file?.content) {
            break;
          }
        } catch (error) {
          if (options.signal?.aborted) throw abortError(options.signal);
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
        await delayWithSignal(250, options.signal);
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
    if (options.signal?.aborted) throw abortError(options.signal);

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

  async navigate(url, options = {}) {
    return this.#materialize(
      await this.#request('POST', '/browser/navigate', { url, ...options }, options),
      options,
    );
  }
  async click(selector, text, screenshot = true, options = {}) {
    return this.#materialize(
      await this.#request('POST', '/browser/click', { selector, text, screenshot }, options),
      options,
    );
  }
  async clickPoint(x, y, screenshot = true, options = {}) {
    return this.#materialize(
      await this.#request('POST', '/browser/click-point', { x, y, screenshot }, options),
      options,
    );
  }
  async type(selector, text, options = {}) {
    return this.#materialize(
      await this.#request('POST', '/browser/fill', { selector, value: text, ...options }, options),
      options,
    );
  }
  async typeText(text, options = {}) {
    return this.#materialize(
      await this.#request('POST', '/browser/type-text', { text, ...options }, options),
      options,
    );
  }
  async pressKey(key, screenshot = true, options = {}) {
    return this.#materialize(
      await this.#request('POST', '/browser/press-key', { key, screenshot }, options),
      options,
    );
  }
  async scroll(deltaX, deltaY, screenshot = true, options = {}) {
    return this.#materialize(
      await this.#request('POST', '/browser/scroll', { deltaX, deltaY, screenshot }, options),
      options,
    );
  }
  async extract(selector, attribute, all = false, options = {}) {
    return this.#request('POST', '/browser/extract', { selector, attribute, all }, options);
  }
  async evaluate(script, options = {}) {
    return this.#request('POST', '/browser/execute', { code: script }, options);
  }
  async screenshot(options = {}) {
    return this.#materialize(
      await this.#request('POST', '/browser/screenshot', options, options),
      options,
    );
  }
  async screenshotJpeg(quality = 80, options = {}) {
    const result = await this.#request('POST', '/browser/screenshot-jpeg', { ...options, quality }, options);
    const content = String(result?.contentBase64 || '');
    if (!content) throw new Error('VM browser screenshot-jpeg returned no data.');
    return Buffer.from(content, 'base64');
  }
  async launch(options = {}) { return this.#request('POST', '/browser/launch', options, options); }
  async closeBrowser(options = {}) { return this.#request('POST', '/browser/close', undefined, options); }
  async fill(selector, value, options = {}) { return this.type(selector, value, options); }
  async fillCredential(input, options = {}) {
    return this.#request('POST', '/browser/credential-fill', input, options);
  }
  async submitProtectedCredential(protectedFillId, options = {}) {
    return this.#request('POST', '/browser/credential-submit', { protectedFillId }, options);
  }
  async cancelProtectedCredential(protectedFillId, options = {}) {
    return this.#request('POST', '/browser/credential-cancel', { protectedFillId }, options);
  }
  async extractContent(options = {}) { return this.#request('POST', '/browser/extract', options, options); }
  async executeJS(code, options = {}) { return this.evaluate(code, options); }
  async getPageInfo(options = {}) {
    const status = await this.client.request('GET', '/browser/status', undefined, options);
    this.headless = status?.headless !== false;
    return status?.pageInfo || null;
  }
  async isLaunched(options = {}) {
    const status = await this.client.request('GET', '/browser/status', undefined, options);
    this.headless = status?.headless !== false;
    return status?.launched === true;
  }
  async getPageCount(options = {}) {
    const status = await this.client.request('GET', '/browser/status', undefined, options);
    return Number(status?.pages || 0);
  }
  async getCookies(options = {}) {
    return this.client.request('GET', '/browser/cookies', undefined, options);
  }
  async setHeadless(value) {
    this.headless = true;
    return { success: true };
  }
}

class LocalVmExecutionBackend {
  constructor(options = {}) {
    this.vmManager = options.vmManager;
    const runtimeProfile = String(options.runtimeProfile || '').trim();
    this.runtimeProfile = ['android', 'browser', 'cli', 'browser_cli'].includes(runtimeProfile)
      ? runtimeProfile
      : 'browser_cli';
    this.token = options.token || process.env.NEOAGENT_VM_GUEST_TOKEN || '';
    this.artifactStore = options.artifactStore || null;
    this.lastActivity = new Map();
    this.reaperInterval = null;
    this.reaperInFlight = false;
    this.shuttingDown = false;
    this.shutdownPromise = null;

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
      if (this.reaperInFlight || this.shuttingDown) return;
      this.reaperInFlight = true;
      const now = Date.now();
      try {
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
      } finally {
        this.reaperInFlight = false;
      }
    }, Math.min(IDLE_TIMEOUT_MS, 60 * 1000));
    this.reaperInterval.unref?.();
  }

  async #clientForUser(userId, options = {}) {
    if (options.signal?.aborted) throw abortError(options.signal);
    if (this.shuttingDown) {
      const error = new Error('Local VM runtime is shutting down.');
      error.code = 'RUNTIME_SHUTTING_DOWN';
      throw error;
    }
    if (!this.vmManager) {
      throw new Error('Local VM manager is not available.');
    }
    const session = await waitForAbortableResult(
      Promise.resolve(this.vmManager.ensureVm(userId, { signal: options.signal })),
      options.signal,
      'VM startup aborted.',
    );
    if (this.shuttingDown) {
      const error = new Error('Local VM runtime is shutting down.');
      error.code = 'RUNTIME_SHUTTING_DOWN';
      throw error;
    }
    this.#touch(userId);
    const client = new RuntimeHttpClient(session.baseUrl, session.guestToken || this.token, {
      onActivity: () => this.#touch(userId),
    });
    try {
      await client.waitForHealth({
        timeoutMs: Number(process.env.NEOAGENT_VM_BOOT_TIMEOUT_MS || 20 * 60 * 1000),
        signal: options.signal,
        checkLiveness: () => {
          const key = String(userId || '').trim();
          const session = this.vmManager.instances.get(key);
          return Boolean(session && session.process && isPidAlive(session.process.pid));
        },
      });
    } catch (error) {
      if (options.signal?.aborted) throw abortError(options.signal);
      const runtimeError = typeof session.getLastError === 'function' ? session.getLastError() : '';
      const detail = runtimeError ? ` ${runtimeError}` : '';
      throw new Error(`${error.message}${detail}`.trim());
    }
    return client;
  }

  async executeCommand(userId, command, options = {}) {
    const client = await this.#clientForUser(userId, options);
    const requestedCommandTimeout = Number(options.timeout || 0);
    const transportTimeout = requestedCommandTimeout > 0
      ? Math.min(30 * 60 * 1000, requestedCommandTimeout + 30_000)
      : 16 * 60 * 1000;
    const result = await client.request('POST', '/exec', {
      command,
      cwd: options.cwd,
      timeout: options.timeout,
      stdin_input: options.stdinInput,
      pty: options.pty === true,
      inputs: options.inputs || [],
    }, {
      timeoutMs: transportTimeout,
      retryCount: 0,
      signal: options.signal,
    });
    return this.#materializeCommandOutput(client, userId, result, options);
  }

  async #materializeCommandOutput(client, userId, result, options = {}) {
    const outputPath = String(result?.outputFilePath || '').trim();
    if (!outputPath) return result;

    const sanitized = { ...result };
    delete sanitized.outputFilePath;
    delete sanitized.outputFileByteSize;
    delete sanitized.outputFileComplete;
    if (!this.artifactStore) {
      return { ...sanitized, artifactError: 'Artifact store is unavailable.' };
    }

    try {
      const file = await client.request('POST', '/files/read', {
        path: outputPath,
        encoding: 'base64',
        delete_after_read: true,
      }, {
        timeoutMs: 30_000,
        maxResponseBytes: 24 * 1024 * 1024,
        retryCount: 0,
        signal: options.signal,
      });
      const content = Buffer.from(String(file?.content || ''), 'base64');
      if (!content.length) throw new Error('Guest command output artifact was empty.');
      const artifact = await this.artifactStore.createBufferArtifact(userId, {
        kind: 'command-output',
        backend: 'vm',
        extension: 'log',
        contentType: 'text/plain; charset=utf-8',
        filenameBase: 'command-output',
        content,
        signal: options.signal,
        metadata: {
          runId: options.runId || null,
          stepId: options.stepId || null,
          stdoutBytes: Number(result.stdoutBytes || 0),
          stderrBytes: Number(result.stderrBytes || 0),
          complete: result.outputFileComplete !== false,
        },
      });
      return {
        ...sanitized,
        outputArtifact: {
          artifactId: artifact.artifactId,
          url: artifact.url,
          byteSize: artifact.byteSize,
          complete: result.outputFileComplete !== false,
        },
      };
    } catch (error) {
      if (options.signal?.aborted) throw abortError(options.signal);
      return {
        ...sanitized,
        artifactError: String(error?.message || error),
      };
    }
  }

  async killCommand(userId, pid, reason = 'aborted') {
    const client = await this.#clientForUser(userId);
    return client.request('POST', '/exec/kill', {
      pid,
      reason,
    });
  }

  async getBrowserProviderForUser(userId, options = {}) {
    return new VmBrowserProvider(await this.#clientForUser(userId, options), {
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
    if (this.shutdownPromise) return this.shutdownPromise;
    this.shuttingDown = true;
    if (this.reaperInterval) {
      clearInterval(this.reaperInterval);
      this.reaperInterval = null;
    }
    this.shutdownPromise = Promise.resolve(this.vmManager?.shutdown?.());
    await this.shutdownPromise;
    return { state: 'stopped' };
  }
}

module.exports = {
  LocalVmExecutionBackend,
  RuntimeHttpClient,
  VmBrowserProvider,
};
