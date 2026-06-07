'use strict';

// Small, dependency-free helpers for shaping values into safe log lines and
// for tolerant JSON parsing. Shared across the AI engine and its sibling
// modules so log formatting stays consistent and testable.

function shortenRunId(runId) {
  const value = String(runId || '').trim();
  if (!value) return 'unknown';
  return value.length <= 8 ? value : value.slice(0, 8);
}

function summarizeForLog(value, maxChars = 220) {
  if (value == null) return '';

  let text = '';
  if (typeof value === 'string') {
    text = value;
  } else {
    try {
      text = JSON.stringify(value);
    } catch {
      text = String(value);
    }
  }

  const normalized = text.replace(/\s+/g, ' ').trim();
  if (normalized.length <= maxChars) return normalized;
  return `${normalized.slice(0, maxChars)}...`;
}

function parseMaybeJson(value, fallback = null) {
  if (!value) return fallback;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

module.exports = {
  shortenRunId,
  summarizeForLog,
  parseMaybeJson,
};
