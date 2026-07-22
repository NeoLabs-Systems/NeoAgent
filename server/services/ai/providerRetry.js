'use strict';

const { createAbortError } = require('../../utils/abort');
const {
  RETRYABLE_HTTP_STATUS: RETRYABLE_STATUS,
  RETRYABLE_NETWORK_CODES: RETRYABLE_CODES,
  abortableDelay,
  computeBackoffMs,
  getErrorCode,
  getHttpStatus,
  retryAfterMilliseconds,
} = require('../../utils/retry');

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
function isTransientError(err) {
  if (!err) return false;

  const status = getHttpStatus(err);
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
  return retryAfterMilliseconds(err.headers || err.response?.headers);
}

function abortError(signal) {
  return createAbortError(signal, 'Provider retry aborted.');
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
    if (options.signal?.aborted) throw abortError(options.signal);
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
      await abortableDelay(waitMs, options.signal);
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
