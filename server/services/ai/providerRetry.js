'use strict';

// Centralized transient-error retry for AI provider calls.
//
// A transient blip (rate limit, provider overload, brief network failure) should
// retry the SAME model with a short backoff. Only after these retries are
// exhausted does the engine fall back to a different (often weaker) model. This
// keeps response quality high and avoids burning the fallback chain on errors a
// one-second wait would have resolved.

const DEFAULTS = {
  maxAttempts: 3, // total attempts including the first
  baseDelayMs: 500,
  maxDelayMs: 8000,
};

// HTTP statuses worth retrying: request timeout, conflict, rate limit, and the
// 5xx family including Anthropic's 529 "overloaded" and common CDN edge codes.
const RETRYABLE_STATUS = new Set([408, 409, 425, 429, 500, 502, 503, 504, 520, 521, 522, 524, 529]);

// Low-level socket / DNS errors surfaced by Node and undici.
const RETRYABLE_CODES = new Set([
  'ECONNRESET', 'ECONNREFUSED', 'ETIMEDOUT', 'EPIPE', 'EAI_AGAIN', 'ENOTFOUND',
  'ENETUNREACH', 'EHOSTUNREACH', 'EAGAIN',
  'UND_ERR_CONNECT_TIMEOUT', 'UND_ERR_SOCKET', 'UND_ERR_HEADERS_TIMEOUT',
]);

function readNumberEnv(name, fallback, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  const raw = process.env[name];
  if (raw === undefined || raw === null || String(raw).trim() === '') return fallback;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function resolveConfig(overrides = {}) {
  return {
    maxAttempts: overrides.maxAttempts
      ?? readNumberEnv('NEOAGENT_AI_RETRY_MAX_ATTEMPTS', DEFAULTS.maxAttempts, { min: 1, max: 8 }),
    baseDelayMs: overrides.baseDelayMs
      ?? readNumberEnv('NEOAGENT_AI_RETRY_BASE_MS', DEFAULTS.baseDelayMs, { min: 0, max: 60000 }),
    maxDelayMs: overrides.maxDelayMs
      ?? readNumberEnv('NEOAGENT_AI_RETRY_MAX_MS', DEFAULTS.maxDelayMs, { min: 0, max: 120000 }),
  };
}

// SDKs disagree on where they put the HTTP status: OpenAI/Anthropic expose
// `.status`, raw http clients use `.statusCode`, and some nest it under
// `.response.status`. Check all of them.
function getStatus(err) {
  if (!err || typeof err !== 'object') return null;
  const candidates = [err.status, err.statusCode, err.response?.status, err.cause?.status];
  for (const value of candidates) {
    const num = Number(value);
    if (Number.isFinite(num) && num >= 100 && num < 600) return num;
  }
  return null;
}

function getErrorCode(err) {
  if (!err || typeof err !== 'object') return null;
  return err.code || err.errno || err.cause?.code || null;
}

function isTransientError(err) {
  if (!err) return false;

  const status = getStatus(err);
  if (status !== null) return RETRYABLE_STATUS.has(status);

  const code = getErrorCode(err);
  if (code && RETRYABLE_CODES.has(String(code))) return true;

  // SDK connection wrappers that don't carry a status or code.
  const name = String(err.name || '');
  if (name === 'APIConnectionError' || name === 'APIConnectionTimeoutError') return true;

  const message = String(err.message || '').toLowerCase();
  if (!message) return false;
  return /\b(overloaded|rate limit|timed? ?out|timeout|temporarily unavailable|connection (?:reset|refused|error)|socket hang up|network (?:error|timeout)|service unavailable)\b/.test(message);
}

// Honor a server-provided Retry-After when present; it is authoritative over our
// own backoff. Supports both delta-seconds and `retry-after-ms` style headers.
function retryAfterMs(err) {
  if (!err || typeof err !== 'object') return null;
  const headers = err.headers || err.response?.headers;
  const read = (name) => {
    if (!headers) return undefined;
    if (typeof headers.get === 'function') return headers.get(name);
    return headers[name] ?? headers[name.toLowerCase()];
  };

  const ms = read('retry-after-ms');
  if (ms !== undefined && ms !== null && String(ms).trim() !== '') {
    const parsed = Number(ms);
    if (Number.isFinite(parsed) && parsed >= 0) return parsed;
  }

  const after = read('retry-after');
  if (after !== undefined && after !== null && String(after).trim() !== '') {
    const seconds = Number(after);
    if (Number.isFinite(seconds) && seconds >= 0) return seconds * 1000;
    const date = Date.parse(String(after));
    if (Number.isFinite(date)) return Math.max(0, date - Date.now());
  }

  return null;
}

// Exponential backoff with equal-jitter: half the window is fixed, half random,
// which spreads retries out without ever collapsing the delay to zero.
function computeBackoffMs(attempt, baseDelayMs, maxDelayMs) {
  const exp = Math.min(maxDelayMs, baseDelayMs * 2 ** (attempt - 1));
  return Math.round(exp / 2 + Math.random() * (exp / 2));
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Run `fn` with transient-error retries.
 *
 * @param {(attempt: number) => Promise<any>} fn The provider call to attempt;
 *   invoked with the current 1-based attempt number.
 * @param {object} [options]
 * @param {(err: any) => boolean} [options.isRetryable] Override transient classification.
 * @param {(info: {attempt:number, delayMs:number, error:any}) => void} [options.onRetry]
 *   Called before each wait so callers can surface progress to the user.
 * @param {string} [options.label] Prefix for diagnostic logs.
 */
async function withProviderRetry(fn, options = {}) {
  const { maxAttempts, baseDelayMs, maxDelayMs } = resolveConfig(options);
  const isRetryable = typeof options.isRetryable === 'function' ? options.isRetryable : isTransientError;
  const label = options.label || 'ProviderRetry';

  let attempt = 0;
  while (true) {
    attempt += 1;
    try {
      return await fn(attempt);
    } catch (err) {
      const exhausted = attempt >= maxAttempts;
      if (exhausted || !isRetryable(err)) throw err;

      const waitMs = retryAfterMs(err) ?? computeBackoffMs(attempt, baseDelayMs, maxDelayMs);
      console.warn(
        `[${label}] transient failure on attempt ${attempt}/${maxAttempts}; retrying in ${waitMs}ms: ${String(err?.message || err).slice(0, 200)}`
      );
      if (typeof options.onRetry === 'function') {
        try {
          options.onRetry({ attempt, delayMs: waitMs, error: err });
        } catch { /* a misbehaving progress callback must not abort the retry */ }
      }
      await delay(waitMs);
    }
  }
}

module.exports = {
  withProviderRetry,
  isTransientError,
  retryAfterMs,
  computeBackoffMs,
  resolveConfig,
  RETRYABLE_STATUS,
  RETRYABLE_CODES,
};
