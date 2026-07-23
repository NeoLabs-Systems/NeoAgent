'use strict';

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');

const DEFAULT_IDLE_TIMEOUT_MINUTES = 30;
const MIN_IDLE_TIMEOUT_MINUTES = 5;
const MAX_IDLE_TIMEOUT_MINUTES = 120;
const MAX_OUTPUT_BYTES = 16 * 1024 * 1024;

function resolveCliScript() {
  try {
    return require.resolve('@bitwarden/cli/build/bw.js');
  } catch {
    const error = new Error('Bitwarden CLI is not installed. Reinstall NeoAgent dependencies and try again.');
    error.code = 'BITWARDEN_CLI_MISSING';
    throw error;
  }
}

function normalizeIdleTimeoutMinutes(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return DEFAULT_IDLE_TIMEOUT_MINUTES;
  return Math.max(MIN_IDLE_TIMEOUT_MINUTES, Math.min(MAX_IDLE_TIMEOUT_MINUTES, Math.round(parsed)));
}

function scopeKey(userId, agentId) {
  return `${String(userId)}:${String(agentId)}`;
}

function appDataDirectory(userId, agentId) {
  const safeUser = String(userId).replace(/[^a-zA-Z0-9_-]/g, '_');
  const safeAgent = String(agentId).replace(/[^a-zA-Z0-9_-]/g, '_');
  return path.join(DATA_DIR, 'integrations', 'bitwarden', safeUser, safeAgent);
}

function runProcess(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env,
      shell: false,
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    });
    const stdout = [];
    const stderr = [];
    let stdoutBytes = 0;
    let stderrBytes = 0;
    let settled = false;
    const timeoutMs = Math.max(1000, Number(options.timeoutMs || 60_000));
    let timer = null;
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      options.signal?.removeEventListener('abort', onAbort);
      callback(value);
    };
    const onAbort = () => {
      child.kill('SIGKILL');
      const error = new Error('Bitwarden operation was aborted.');
      error.name = 'AbortError';
      error.code = 'ABORT_ERR';
      finish(reject, error);
    };
    timer = setTimeout(() => {
      child.kill('SIGKILL');
      const error = new Error('Bitwarden CLI timed out.');
      error.code = 'BITWARDEN_CLI_TIMEOUT';
      finish(reject, error);
    }, timeoutMs);
    if (options.signal?.aborted) {
      onAbort();
      return;
    }
    options.signal?.addEventListener('abort', onAbort, { once: true });

    child.stdout.on('data', (chunk) => {
      stdoutBytes += chunk.length;
      if (stdoutBytes <= MAX_OUTPUT_BYTES) stdout.push(chunk);
    });
    child.stderr.on('data', (chunk) => {
      stderrBytes += chunk.length;
      if (stderrBytes <= MAX_OUTPUT_BYTES) stderr.push(chunk);
    });
    child.on('error', (error) => finish(reject, error));
    child.on('close', (code) => {
      if (code !== 0) {
        const error = new Error('Bitwarden rejected the operation.');
        error.code = 'BITWARDEN_CLI_FAILED';
        error.exitCode = code;
        error.stderrPresent = stderrBytes > 0;
        finish(reject, error);
        return;
      }
      if (stdoutBytes > MAX_OUTPUT_BYTES || stderrBytes > MAX_OUTPUT_BYTES) {
        const error = new Error('Bitwarden CLI returned too much data.');
        error.code = 'BITWARDEN_CLI_OUTPUT_TOO_LARGE';
        finish(reject, error);
        return;
      }
      finish(resolve, Buffer.concat(stdout).toString('utf8').trim());
    });
  });
}

class BitwardenCli {
  constructor(options = {}) {
    this.runner = options.runner || runProcess;
    this.cliScript = options.cliScript || null;
    this.sessions = new Map();
    this.timer = setInterval(() => this.lockExpired().catch(() => {}), 30_000);
    this.timer.unref?.();
  }

  #session(userId, agentId) {
    return this.sessions.get(scopeKey(userId, agentId)) || null;
  }

  #touch(userId, agentId) {
    const session = this.#session(userId, agentId);
    if (session) session.lastUsedAt = Date.now();
    return session;
  }

  #environment(userId, agentId, extra = {}) {
    const directory = appDataDirectory(userId, agentId);
    fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
    try { fs.chmodSync(directory, 0o700); } catch {}
    const inherited = {};
    for (const name of [
      'PATH',
      'HOME',
      'TMPDIR',
      'TMP',
      'TEMP',
      'LANG',
      'LC_ALL',
      'HTTPS_PROXY',
      'HTTP_PROXY',
      'NO_PROXY',
      'NODE_EXTRA_CA_CERTS',
    ]) {
      if (process.env[name]) inherited[name] = process.env[name];
    }
    return {
      ...inherited,
      BITWARDENCLI_APPDATA_DIR: directory,
      ...extra,
    };
  }

  async #run(userId, agentId, args, options = {}) {
    const script = this.cliScript || resolveCliScript();
    return this.runner(process.execPath, [script, ...args], {
      ...options,
      env: this.#environment(userId, agentId, options.env || {}),
    });
  }

  getStatus(userId, agentId) {
    const session = this.#session(userId, agentId);
    return {
      cliAvailable: (() => {
        try {
          this.cliScript || resolveCliScript();
          return true;
        } catch {
          return false;
        }
      })(),
      unlocked: Boolean(session?.sessionKey),
      idleTimeoutMinutes: session?.idleTimeoutMinutes || DEFAULT_IDLE_TIMEOUT_MINUTES,
      lastUsedAt: session?.lastUsedAt ? new Date(session.lastUsedAt).toISOString() : null,
    };
  }

  async configure(userId, agentId, config, options = {}) {
    const serverUrl = String(config.serverUrl || 'https://vault.bitwarden.com').trim().replace(/\/+$/, '');
    await this.logout(userId, agentId);
    await this.#run(userId, agentId, ['config', 'server', serverUrl], options);
    await this.#run(userId, agentId, ['login', '--apikey'], {
      ...options,
      env: {
        BW_CLIENTID: String(config.clientId || ''),
        BW_CLIENTSECRET: String(config.clientSecret || ''),
      },
    });
    return { configured: true };
  }

  async unlock(userId, agentId, masterPassword, idleTimeoutMinutes, options = {}) {
    const password = String(masterPassword || '');
    if (!password) {
      const error = new Error('Bitwarden master password is required.');
      error.code = 'BITWARDEN_MASTER_PASSWORD_REQUIRED';
      throw error;
    }
    const sessionKey = await this.#run(userId, agentId, [
      'unlock',
      '--passwordenv',
      'NEOAGENT_BITWARDEN_MASTER_PASSWORD',
      '--raw',
    ], {
      ...options,
      env: { NEOAGENT_BITWARDEN_MASTER_PASSWORD: password },
    });
    if (!sessionKey) {
      const error = new Error('Bitwarden did not return an unlock session.');
      error.code = 'BITWARDEN_UNLOCK_FAILED';
      throw error;
    }
    this.sessions.set(scopeKey(userId, agentId), {
      sessionKey,
      lastUsedAt: Date.now(),
      idleTimeoutMinutes: normalizeIdleTimeoutMinutes(idleTimeoutMinutes),
    });
    return this.getStatus(userId, agentId);
  }

  requireSession(userId, agentId) {
    const session = this.#touch(userId, agentId);
    if (!session?.sessionKey) {
      const error = new Error('Bitwarden is locked. Unlock it in Official Integrations.');
      error.code = 'BITWARDEN_LOCKED';
      throw error;
    }
    return session.sessionKey;
  }

  async sync(userId, agentId, options = {}) {
    const sessionKey = this.requireSession(userId, agentId);
    await this.#run(userId, agentId, ['sync'], {
      ...options,
      env: { BW_SESSION: sessionKey },
    });
  }

  async listItems(userId, agentId, options = {}) {
    const sessionKey = this.requireSession(userId, agentId);
    const raw = await this.#run(userId, agentId, ['list', 'items'], {
      ...options,
      env: { BW_SESSION: sessionKey },
    });
    const items = JSON.parse(raw || '[]');
    return Array.isArray(items) ? items : [];
  }

  async getItem(userId, agentId, itemId, options = {}) {
    const sessionKey = this.requireSession(userId, agentId);
    const raw = await this.#run(userId, agentId, ['get', 'item', String(itemId)], {
      ...options,
      env: { BW_SESSION: sessionKey },
    });
    const item = JSON.parse(raw || '{}');
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new Error('Bitwarden returned an invalid item.');
    }
    return item;
  }

  async lock(userId, agentId) {
    const key = scopeKey(userId, agentId);
    const session = this.sessions.get(key);
    this.sessions.delete(key);
    if (!session?.sessionKey) return { locked: true };
    try {
      await this.#run(userId, agentId, ['lock'], {
        env: { BW_SESSION: session.sessionKey },
        timeoutMs: 15_000,
      });
    } catch {
      // The in-memory decryption key has already been discarded.
    }
    return { locked: true };
  }

  async logout(userId, agentId) {
    await this.lock(userId, agentId);
    try {
      await this.#run(userId, agentId, ['logout'], { timeoutMs: 15_000 });
    } catch {
      // Treat an already logged-out CLI as disconnected.
    }
    fs.rmSync(appDataDirectory(userId, agentId), { recursive: true, force: true });
    return { loggedOut: true };
  }

  async lockExpired() {
    const now = Date.now();
    const expired = [];
    for (const [key, session] of this.sessions.entries()) {
      if (now - session.lastUsedAt >= session.idleTimeoutMinutes * 60_000) {
        expired.push(key);
      }
    }
    await Promise.allSettled(expired.map((key) => {
      const separator = key.indexOf(':');
      return this.lock(key.slice(0, separator), key.slice(separator + 1));
    }));
  }

  async shutdown() {
    clearInterval(this.timer);
    const scopes = Array.from(this.sessions.keys());
    await Promise.allSettled(scopes.map((key) => {
      const separator = key.indexOf(':');
      return this.lock(key.slice(0, separator), key.slice(separator + 1));
    }));
  }
}

module.exports = {
  BitwardenCli,
  DEFAULT_IDLE_TIMEOUT_MINUTES,
  appDataDirectory,
  normalizeIdleTimeoutMinutes,
  runProcess,
};
