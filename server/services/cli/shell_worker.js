/**
 * shell_worker.js — Forked shell execution worker
 *
 * This file is intentionally self-contained with zero imports from server/.
 * It runs as a child_process.fork() child with no access to the server's
 * database, JWT secrets, or any app state. The blast radius of a compromised
 * command result is limited to this process.
 *
 * Protocol (IPC):
 *   Request:  { requestId, command, options: { cwd, timeout, env, stdinInput } }
 *   Response: { requestId, result: { stdout, stderr, exitCode, timedOut, durationMs } }
 *             | { requestId, error: string }
 */
'use strict';

const { spawn, execFileSync } = require('child_process');

const DEFAULT_TIMEOUT_MS = 15 * 60 * 1000;
const FORCE_KILL_GRACE_MS = 5000;
const MAX_STDOUT_CHARS = 50000;
const MAX_STDERR_CHARS = 10000;

let _defaultShell = null;

function resolveShell() {
  if (_defaultShell) return _defaultShell;
  const candidates = [process.env.SHELL, '/bin/zsh', '/bin/bash', '/bin/sh'].filter(Boolean);
  for (const candidate of candidates) {
    try {
      execFileSync(candidate, ['-lc', 'printf ok'], {
        timeout: 3000, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
      });
      _defaultShell = candidate;
      return _defaultShell;
    } catch {}
  }
  _defaultShell = '/bin/sh';
  return _defaultShell;
}

function clampTimeout(value) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : DEFAULT_TIMEOUT_MS;
}

function truncate(str, max) {
  if (typeof str !== 'string') str = String(str ?? '');
  return str.length > max ? str.slice(0, max) + `\n...[truncated, ${str.length} total chars]` : str;
}

function supportsPipefail(shell) {
  return /(?:^|\/)(?:bash|zsh|ksh|mksh|yash)$/.test(String(shell || ''));
}

function execute(command, options, callback) {
  const shell = resolveShell();
  const cwd = options.cwd || process.env.HOME;
  const timeout = clampTimeout(options.timeout);
  const wrapped = supportsPipefail(shell) ? `set -o pipefail; ${command}` : command;

  let stdout = '';
  let stderr = '';
  let killed = false;
  let timedOut = false;
  const startedAt = Date.now();

  let env = { ...process.env };
  if (options.env && typeof options.env === 'object') {
    env = { ...env, ...options.env };
  }

  const proc = spawn(shell, ['-l', '-c', wrapped], {
    cwd,
    env,
    detached: process.platform !== 'win32',
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  const timer = setTimeout(() => {
    killed = true;
    timedOut = true;
    try { process.kill(-proc.pid, 'SIGTERM'); } catch { proc.kill('SIGTERM'); }
    setTimeout(() => { try { proc.kill('SIGKILL'); } catch {} }, FORCE_KILL_GRACE_MS);
  }, timeout);

  proc.stdout.on('data', (d) => { stdout += d; if (stdout.length > 500000) stdout = stdout.slice(-250000); });
  proc.stderr.on('data', (d) => { stderr += d; if (stderr.length > 100000) stderr = stderr.slice(-50000); });

  if (options.stdinInput) {
    proc.stdin.write(options.stdinInput);
    proc.stdin.end();
  }

  proc.on('close', (code) => {
    clearTimeout(timer);
    callback(null, {
      exitCode: typeof code === 'number' ? code : null,
      stdout: truncate(stdout.trim(), MAX_STDOUT_CHARS),
      stderr: truncate(stderr.trim(), MAX_STDERR_CHARS),
      killed,
      timedOut,
      durationMs: Date.now() - startedAt,
      command,
      cwd,
    });
  });

  proc.on('error', (err) => {
    clearTimeout(timer);
    callback(null, {
      exitCode: -1,
      stdout: '',
      stderr: err.message,
      killed: false,
      timedOut: false,
      durationMs: Date.now() - startedAt,
      command,
      cwd,
      error: err.message,
    });
  });
}

process.on('message', ({ requestId, command, options = {} }) => {
  try {
    execute(command, options, (err, result) => {
      process.send({ requestId, result });
    });
  } catch (err) {
    process.send({ requestId, error: String(err?.message || err) });
  }
});

// Signal readiness
process.send?.({ type: 'ready' });
