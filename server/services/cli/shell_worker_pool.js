'use strict';

const { fork } = require('child_process');
const { randomUUID } = require('crypto');
const path = require('path');

const WORKER_SCRIPT = path.resolve(__dirname, 'shell_worker.js');
const DEFAULT_WORKER_ENV_KEYS = Object.freeze([
  'HOME',
  'PATH',
  'SHELL',
  'TMPDIR',
  'TMP',
  'TEMP',
  'TERM',
  'LANG',
  'LC_ALL',
  'LC_CTYPE',
  'USER',
  'LOGNAME',
  'COLORTERM',
  'SystemRoot',
  'ComSpec',
  'PATHEXT',
  'WINDIR',
]);

function normalizeExtraEnvKeys(extraEnvKeys = process.env.NEOAGENT_SHELL_WORKER_ENV_ALLOWLIST || '') {
  if (Array.isArray(extraEnvKeys)) {
    return extraEnvKeys.map((key) => String(key || '').trim()).filter(Boolean);
  }
  return String(extraEnvKeys || '')
    .split(',')
    .map((key) => key.trim())
    .filter(Boolean);
}

function buildWorkerEnv(baseEnv = process.env, extraEnvKeys) {
  const allowedKeys = new Set([
    ...DEFAULT_WORKER_ENV_KEYS,
    ...normalizeExtraEnvKeys(extraEnvKeys),
  ]);
  const workerEnv = {};
  for (const key of allowedKeys) {
    if (Object.prototype.hasOwnProperty.call(baseEnv, key) && baseEnv[key] != null) {
      workerEnv[key] = String(baseEnv[key]);
    }
  }
  return workerEnv;
}

function createShutdownResult(message, killed = false) {
  return {
    exitCode: -1,
    stdout: '',
    stderr: message,
    killed,
    timedOut: false,
    durationMs: 0,
  };
}

class ShellWorkerPool {
  /**
   * @param {object} [options]
   * @param {number} [options.size=4]       Number of worker processes to keep alive
   * @param {string} [options.workerScript] Override worker script path (for tests)
   */
  constructor({ size = 4, workerScript = WORKER_SCRIPT } = {}) {
    this._size = size;
    this._workerScript = workerScript;
    /** @type {Array<{ proc: ChildProcess, busy: boolean, pendingRequestId: string|null }>} */
    this._workers = [];
    /** @type {Array<{ requestId: string, command: string, options: object, resolve: Function, reject: Function }>} */
    this._queue = [];
    /** @type {Map<string, Function>} requestId → resolve */
    this._pending = new Map();
    this._shuttingDown = false;

    for (let i = 0; i < this._size; i++) {
      this._spawnWorker();
    }
  }

  _spawnWorker() {
    const proc = fork(this._workerScript, [], {
      detached: false,
      stdio: ['pipe', 'pipe', 'pipe', 'ipc'],
      env: buildWorkerEnv(process.env),
    });

    const workerEntry = { proc, busy: false, pendingRequestId: null };
    this._workers.push(workerEntry);

    proc.on('message', (msg) => {
      if (msg?.type === 'ready') return;

      const { requestId, result, error } = msg || {};
      const resolve = this._pending.get(requestId);
      if (resolve) {
        this._pending.delete(requestId);
        resolve(error ? { exitCode: -1, stdout: '', stderr: error, killed: false, timedOut: false } : result);
      }
      workerEntry.busy = false;
      workerEntry.pendingRequestId = null;
      this._drain();
    });

    proc.on('exit', (code) => {
      const idx = this._workers.indexOf(workerEntry);
      if (idx !== -1) this._workers.splice(idx, 1);

      // Reject the in-flight request on this worker, if any
      if (workerEntry.pendingRequestId) {
        const resolve = this._pending.get(workerEntry.pendingRequestId);
        if (resolve) {
          this._pending.delete(workerEntry.pendingRequestId);
          const message = this._shuttingDown ? 'Server shutting down' : 'Worker process crashed';
          resolve(createShutdownResult(message, true));
        }
      }

      if (this._shuttingDown) return;

      console.warn(`[ShellWorkerPool] Worker exited (code=${code}), respawning`);
      this._spawnWorker();
    });

    proc.on('error', (err) => {
      console.error('[ShellWorkerPool] Worker error:', err.message);
    });

    return workerEntry;
  }

  _drain() {
    if (this._queue.length === 0) return;
    const idleWorker = this._workers.find((w) => !w.busy);
    if (!idleWorker) return;

    const job = this._queue.shift();
    this._dispatch(idleWorker, job);
  }

  _dispatch(workerEntry, job) {
    const { requestId, command, options, resolve } = job;
    workerEntry.busy = true;
    workerEntry.pendingRequestId = requestId;
    this._pending.set(requestId, resolve);
    workerEntry.proc.send({ requestId, command, options });
  }

  /**
   * Execute a shell command in an isolated worker process.
   * @param {string} command
   * @param {object} [options]
   * @returns {Promise<object>} result with { stdout, stderr, exitCode, killed, timedOut, durationMs }
   */
  execute(command, options = {}) {
    return new Promise((resolve) => {
      const requestId = randomUUID();
      const job = { requestId, command, options, resolve };
      const idleWorker = this._workers.find((w) => !w.busy);
      if (idleWorker) {
        this._dispatch(idleWorker, job);
      } else {
        this._queue.push(job);
      }
    });
  }

  /** Gracefully terminate all workers. */
  shutdown() {
    if (this._shuttingDown) return;
    this._shuttingDown = true;

    const shutdownResult = createShutdownResult('Server shutting down', true);
    for (const job of this._queue) {
      job.resolve(shutdownResult);
    }
    this._queue = [];

    for (const w of this._workers) {
      if (w.pendingRequestId) {
        const resolve = this._pending.get(w.pendingRequestId);
        if (resolve) {
          this._pending.delete(w.pendingRequestId);
          resolve(shutdownResult);
        }
        w.pendingRequestId = null;
        w.busy = false;
      }
    }

    for (const w of this._workers) {
      try { w.proc.kill(); } catch {}
    }
    this._workers = [];
    this._pending.clear();
  }
}

module.exports = {
  ShellWorkerPool,
  DEFAULT_WORKER_ENV_KEYS,
  buildWorkerEnv,
};
