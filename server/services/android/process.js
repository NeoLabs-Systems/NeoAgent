'use strict';

const { spawn } = require('node:child_process');

const DEFAULT_TIMEOUT_MS = 20_000;
const DEFAULT_MAX_OUTPUT_BYTES = 4 * 1024 * 1024;
const MAX_TIMEOUT_MS = 30 * 60 * 1000;

function clampNumber(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.round(parsed)));
}

function createProcessError(message, code, details = {}) {
  const error = new Error(message);
  error.code = code;
  Object.assign(error, details);
  return error;
}

function runProcess(command, args = [], options = {}) {
  const timeoutMs = clampNumber(options.timeoutMs, DEFAULT_TIMEOUT_MS, 100, MAX_TIMEOUT_MS);
  const maxOutputBytes = clampNumber(
    options.maxOutputBytes,
    DEFAULT_MAX_OUTPUT_BYTES,
    1024,
    1024 * 1024 * 1024,
  );
  const encoding = options.encoding === null ? null : (options.encoding || 'utf8');

  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env,
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true,
    });
    const stdout = [];
    const stderr = [];
    let stdoutBytes = 0;
    let stderrBytes = 0;
    let settled = false;
    let forceKillTimer = null;

    const decode = (chunks) => {
      const buffer = Buffer.concat(chunks);
      return encoding === null ? buffer : buffer.toString(encoding);
    };
    const cleanup = () => {
      clearTimeout(timeout);
      options.signal?.removeEventListener('abort', onAbort);
    };
    const settle = (error, result = null) => {
      if (settled) return;
      settled = true;
      cleanup();
      if (error) reject(error);
      else resolve(result);
    };
    const terminate = (error) => {
      try { child.kill('SIGTERM'); } catch {}
      forceKillTimer = setTimeout(() => {
        try { child.kill('SIGKILL'); } catch {}
      }, 1000);
      forceKillTimer.unref?.();
      settle(error);
    };
    const onAbort = () => {
      const error = options.signal?.reason instanceof Error
        ? options.signal.reason
        : createProcessError('Command was aborted.', 'ABORT_ERR');
      if (!(options.signal?.reason instanceof Error)) error.name = 'AbortError';
      terminate(error);
    };
    const collect = (target, chunk, streamName) => {
      if (settled) return;
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      if (streamName === 'stdout') stdoutBytes += buffer.length;
      else stderrBytes += buffer.length;
      if (stdoutBytes + stderrBytes > maxOutputBytes) {
        terminate(createProcessError(
          `Command exceeded the ${maxOutputBytes}-byte output limit.`,
          'PROCESS_OUTPUT_LIMIT',
        ));
        return;
      }
      target.push(buffer);
    };

    const timeout = setTimeout(() => {
      terminate(createProcessError(
        `Command timed out after ${timeoutMs} ms.`,
        'PROCESS_TIMEOUT',
        { timeoutMs },
      ));
    }, timeoutMs);
    timeout.unref?.();

    child.stdout?.on('data', (chunk) => collect(stdout, chunk, 'stdout'));
    child.stderr?.on('data', (chunk) => collect(stderr, chunk, 'stderr'));
    child.once('error', (error) => settle(error));
    child.once('close', (exitCode, signal) => {
      if (forceKillTimer) clearTimeout(forceKillTimer);
      if (settled) return;
      const result = {
        stdout: decode(stdout),
        stderr: decode(stderr),
        exitCode,
        signal: signal || null,
      };
      if (exitCode === 0) {
        settle(null, result);
        return;
      }
      const stderrText = Buffer.concat(stderr).toString('utf8').trim();
      const stdoutText = Buffer.concat(stdout).toString('utf8').trim();
      settle(createProcessError(
        stderrText || stdoutText || `Command exited with code ${exitCode}.`,
        'PROCESS_EXIT',
        result,
      ));
    });

    if (options.signal?.aborted) {
      onAbort();
      return;
    }
    options.signal?.addEventListener('abort', onAbort, { once: true });
    if (options.input != null) child.stdin?.end(options.input);
    else child.stdin?.end();
  });
}

module.exports = {
  DEFAULT_MAX_OUTPUT_BYTES,
  DEFAULT_TIMEOUT_MS,
  clampNumber,
  runProcess,
};
