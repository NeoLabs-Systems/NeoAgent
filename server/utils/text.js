'use strict';

function trimText(value) {
  return String(value || '').trim();
}

function requireText(value, label = 'value') {
  const text = trimText(value);
  if (!text) throw new Error(`${label} is required.`);
  return text;
}

function asObject(value, fallback = {}) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : fallback;
}

function toOptionalString(value, maxLength = 512) {
  if (value == null) return '';
  const normalized = String(value).trim();
  if (!normalized) return '';
  return normalized.slice(0, maxLength);
}

function parseMaybeJson(value, fallback = null) {
  if (value == null || value === '') return fallback;
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) {
    value = Buffer.from(value).toString('utf8');
    if (!value) return fallback;
  }
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(String(value));
  } catch {
    return fallback;
  }
}

function parseJsonObject(value, fallback = {}) {
  const fallbackObject = asObject(fallback, {});
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) {
    value = Buffer.from(value).toString('utf8');
  }
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return { ...value };
  }
  if (value == null || value === '') return { ...fallbackObject };
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : { ...fallbackObject };
  } catch {
    return { ...fallbackObject };
  }
}

// The JSON object inside a model reply, which may wrap it in prose or code
// fences. Returns null when there is none.
function extractJsonObject(text) {
  const raw = String(text || '').trim();
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start === -1 || end <= start) return null;
  try {
    const parsed = JSON.parse(raw.slice(start, end + 1));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

// Settings and trigger payloads sometimes arrive JSON-encoded more than once
// (a string stored as `"\"value\""`). Unwrap at most twice, and treat anything
// that decodes to a non-string as absent rather than leaking a serialized blob.
function normalizeStoredString(value) {
  if (value == null) return '';
  if (typeof value !== 'string') return String(value || '').trim();
  let current = value.trim();
  for (let i = 0; i < 2; i += 1) {
    if (!current) return '';
    try {
      const parsed = JSON.parse(current);
      if (typeof parsed === 'string') {
        current = parsed.trim();
        continue;
      }
      // Numeric IDs (Discord snowflakes, Telegram chat ids, phone numbers) are
      // valid JSON numbers; keep the raw text so precision isn't lost.
      if (typeof parsed === 'number') return current;
      return '';
    } catch {
      return current;
    }
  }
  return current;
}

module.exports = {
  asObject,
  extractJsonObject,
  normalizeStoredString,
  parseJsonObject,
  parseMaybeJson,
  requireText,
  toOptionalString,
  trimText,
};
