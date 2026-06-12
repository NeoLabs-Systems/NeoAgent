'use strict';

const crypto = require('crypto');

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!value || typeof value !== 'object') return value;
  return Object.keys(value)
    .sort()
    .reduce((result, key) => {
      result[key] = canonicalize(value[key]);
      return result;
    }, {});
}

function stableHash(value) {
  const text = typeof value === 'string'
    ? value
    : JSON.stringify(canonicalize(value));
  return crypto.createHash('sha256').update(text).digest('hex');
}

class ToolRepetitionGuard {
  constructor({ unchangedLimit = 2 } = {}) {
    this.unchangedLimit = Math.max(1, Number(unchangedLimit) || 2);
    this.entries = new Map();
  }

  key(toolName, args) {
    return `${String(toolName || '')}:${stableHash(args || {})}`;
  }

  shouldBlock(toolName, args) {
    const entry = this.entries.get(this.key(toolName, args));
    return Boolean(entry && entry.unchangedCount >= this.unchangedLimit);
  }

  observe(toolName, args, result) {
    const key = this.key(toolName, args);
    const resultHash = stableHash(result);
    const previous = this.entries.get(key);
    const unchangedCount = previous?.resultHash === resultHash
      ? previous.unchangedCount + 1
      : 1;
    const next = {
      toolName,
      argsHash: stableHash(args || {}),
      resultHash,
      unchangedCount,
    };
    this.entries.set(key, next);
    return next;
  }
}

module.exports = {
  ToolRepetitionGuard,
  canonicalize,
  stableHash,
};
