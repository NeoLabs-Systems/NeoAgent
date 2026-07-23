'use strict';

const { createAbortError, isAbortError } = require('./abort');

const RETRYABLE_HTTP_STATUS = new Set([
  408, 409, 425, 429, 500, 502, 503, 504, 520, 521, 522, 524, 529,
]);
const RETRYABLE_NETWORK_CODES = new Set([
  'ECONNRESET',
  'ECONNREFUSED',
  'ETIMEDOUT',
  'EPIPE',
  'EAI_AGAIN',
  'ENOTFOUND',
  'ENETUNREACH',
  'EHOSTUNREACH',
  'EAGAIN',
  'UND_ERR_CONNECT_TIMEOUT',
  'UND_ERR_SOCKET',
  'UND_ERR_HEADERS_TIMEOUT',
  'INTEGRATION_HTTP_TIMEOUT',
]);

function getHttpStatus(error) {
  if (!error || typeof error !== 'object') return null;
  const candidates = [
    error.status,
    error.statusCode,
    error.response?.status,
    error.cause?.status,
  ];
  for (const value of candidates) {
    const status = Number(value);
    if (Number.isFinite(status) && status >= 100 && status < 600) return status;
  }
  return null;
}

function getErrorCode(error) {
  if (!error || typeof error !== 'object') return null;
  return error.code || error.errno || error.cause?.code || null;
}

function readHeader(headers, name) {
  if (!headers) return undefined;
  if (typeof headers.get === 'function') return headers.get(name);
  return headers[name] ?? headers[name.toLowerCase()];
}

function retryAfterMilliseconds(headers, now = Date.now()) {
  const milliseconds = readHeader(headers, 'retry-after-ms');
  if (milliseconds !== undefined && milliseconds !== null && String(milliseconds).trim()) {
    const parsed = Number(milliseconds);
    if (Number.isFinite(parsed) && parsed >= 0) return parsed;
  }

  const retryAfter = readHeader(headers, 'retry-after');
  if (retryAfter === undefined || retryAfter === null || !String(retryAfter).trim()) {
    return null;
  }
  const seconds = Number(retryAfter);
  if (Number.isFinite(seconds) && seconds >= 0) return seconds * 1000;
  const date = Date.parse(String(retryAfter));
  return Number.isFinite(date) ? Math.max(0, date - now) : null;
}

function computeBackoffMs(attempt, baseDelayMs, maxDelayMs) {
  const exp = Math.min(maxDelayMs, baseDelayMs * 2 ** (attempt - 1));
  return Math.round(exp / 2 + Math.random() * (exp / 2));
}

function isTransientIoError(error) {
  if (!error || isAbortError(error)) return false;
  const status = getHttpStatus(error);
  if (status !== null) return RETRYABLE_HTTP_STATUS.has(status);
  const code = getErrorCode(error);
  return Boolean(code && RETRYABLE_NETWORK_CODES.has(String(code)));
}

function abortableDelay(milliseconds, signal = null) {
  if (signal?.aborted) return Promise.reject(createAbortError(signal));
  return new Promise((resolve, reject) => {
    let timer = null;
    const onAbort = () => {
      if (timer) clearTimeout(timer);
      signal?.removeEventListener('abort', onAbort);
      reject(createAbortError(signal));
    };
    timer = setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, Math.max(0, Number(milliseconds) || 0));
    signal?.addEventListener('abort', onAbort, { once: true });
  });
}

module.exports = {
  RETRYABLE_HTTP_STATUS,
  RETRYABLE_NETWORK_CODES,
  abortableDelay,
  computeBackoffMs,
  getErrorCode,
  getHttpStatus,
  isTransientIoError,
  readHeader,
  retryAfterMilliseconds,
};
