'use strict';

const { sanitizeError } = require('./security');
const { publicErrorCode } = require('./http_error');

const GENERIC_ERROR_MESSAGE = 'Something went wrong. Please try again.';
const MAX_READABLE_LENGTH = 300;

// Kept in step with `looksTechnical` in flutter_app/lib/src/error_text.dart.
const TECHNICAL_PATTERNS = [
  /(?:^|\n)\s*(?:at\s+\S|#\d+\s)/,
  /\b\w*(?:Error|Exception):/,
  /\b(?:ECONN\w+|ENOTFOUND|ETIMEDOUT|EAI_AGAIN|EPIPE|ENOENT|EACCES|EPERM|EADDR\w+|EHOSTUNREACH|ENETUNREACH|ERR_[A-Z0-9_]+|SQLITE_[A-Z0-9_]+)\b/,
  /\[(?:path|module|app)\]|node_modules|(?:^|[\s'"(])(?:~\/|\/Users\/|\/home\/|\/var\/|\/tmp\/|\/etc\/|[A-Za-z]:\\)/,
  /stack trace|traceback|cannot read propert|is not a function|is not defined|unexpected token|not valid json|getaddrinfo|socket hang up|fetch failed|constraint failed|no such (?:table|column)|\bsqlite\b|\bsql\b/i,
  /\bHTTP\s*\d{3}\b|\bstatus(?: code)?:?\s*\d{3}\b|^\d{3}\b/i,
  /[a-z]_(?:error|exception|failed)\b/i,
  /[{[]\s*"/,
];

function looksTechnical(text) {
  const value = String(text || '').trim();
  if (!value) return false;
  if (value.includes('\n') || value.length > MAX_READABLE_LENGTH) return true;
  return TECHNICAL_PATTERNS.some((pattern) => pattern.test(value));
}

// What someone without admin rights may read about a failure. Only a message
// written for people survives: a plain string, or an error carrying a public
// code or a 4xx status. Anything else is an exception's own text.
function nonAdminErrorMessage(err) {
  const status = Number(err?.status || err?.statusCode);
  const written = typeof err === 'string'
    || Boolean(publicErrorCode(err))
    || (status >= 400 && status < 500);
  if (!written) return GENERIC_ERROR_MESSAGE;
  const message = sanitizeError(err);
  return looksTechnical(message) ? GENERIC_ERROR_MESSAGE : message;
}

const ERROR_TEXT_KEYS = new Set(['error', 'last_error', 'lastError', 'errorMessage', 'error_message']);
const SERVER_FAILURE_DETAIL_KEYS = ['message', 'detail', 'details', 'stack'];
const MAX_REDACT_DEPTH = 10;

function isPlainContainer(value) {
  if (Array.isArray(value)) return true;
  if (!value || typeof value !== 'object') return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function redactNested(value, depth) {
  if (depth > MAX_REDACT_DEPTH || !isPlainContainer(value)) return value;
  if (Array.isArray(value)) return value.map((item) => redactNested(item, depth + 1));
  const copy = {};
  for (const [key, item] of Object.entries(value)) {
    copy[key] = ERROR_TEXT_KEYS.has(key) && typeof item === 'string' && looksTechnical(item)
      ? GENERIC_ERROR_MESSAGE
      : redactNested(item, depth + 1);
  }
  return copy;
}

// A JSON response as a non-admin may see it. A 5xx says nothing about its
// cause; any other response keeps its text unless that text is technical.
function redactResponseBody(body, status) {
  const redacted = redactNested(body, 0);
  if (status < 500 || !isPlainContainer(redacted) || Array.isArray(redacted)) return redacted;
  for (const key of SERVER_FAILURE_DETAIL_KEYS) delete redacted[key];
  if (typeof redacted.error === 'string') redacted.error = GENERIC_ERROR_MESSAGE;
  return redacted;
}

// A stored run holds raw exception text by construction, so its error fields
// never reach a non-admin, whatever they say.
function redactRunRecord(record) {
  if (!record?.error) return record;
  const redacted = { ...record, error: GENERIC_ERROR_MESSAGE };
  if ('result' in record) redacted.result = null;
  return redacted;
}

function redactRunEvent(event) {
  if (!event?.payload?.error) return event;
  return { ...event, payload: { ...event.payload, error: GENERIC_ERROR_MESSAGE } };
}

module.exports = {
  GENERIC_ERROR_MESSAGE,
  looksTechnical,
  nonAdminErrorMessage,
  redactResponseBody,
  redactRunEvent,
  redactRunRecord,
};
