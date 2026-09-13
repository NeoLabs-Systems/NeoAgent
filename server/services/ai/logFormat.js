'use strict';

const { parseMaybeJson } = require('../../utils/text');

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

module.exports = {
  shortenRunId,
  summarizeForLog,
  parseMaybeJson,
};
