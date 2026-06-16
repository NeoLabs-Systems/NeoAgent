'use strict';

const crypto = require('crypto');
const {
  isClearlyReadOnlyShellCommand,
} = require('./loop/progress_classification');

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

function normalizeReadOnlyShellIntent(command = '') {
  const text = String(command || '')
    .replace(/(^|\n)\s*#.*(?=\n|$)/g, '\n')
    .replace(/2?>\s*(?:"[^"]+"|'[^']+'|\S+)/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  const urls = [...text.matchAll(/https?:\/\/[^\s"'`|;&)]+/gi)]
    .map((match) => match[0].replace(/[?#].*$/, ''))
    .sort();
  const paths = [...text.matchAll(/(?:^|\s)(\/[A-Za-z0-9._~/%+-][^\s"'`|;&)]*)/g)]
    .map((match) => match[1].replace(/[?#].*$/, ''))
    .filter((item) => !item.startsWith('/tmp/'))
    .sort();
  const repoSearches = [...text.matchAll(/\brepo:[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+/gi)]
    .map((match) => match[0].toLowerCase())
    .sort();

  if (urls.length || paths.length || repoSearches.length) {
    return {
      kind: 'read_only_shell_intent',
      urls,
      paths,
      repoSearches,
    };
  }

  return {
    kind: 'read_only_shell_command',
    command: text
      .replace(/\|\s*(cat|head(?:\s+-n?\s+\d+)?|tail(?:\s+-n?\s+\d+)?|wc(?:\s+-[A-Za-z]+)?)\b[^|;&]*/g, '')
      .trim(),
  };
}

function canonicalToolArgs(toolName, args) {
  if (toolName === 'execute_command' && isClearlyReadOnlyShellCommand(args?.command || '')) {
    return normalizeReadOnlyShellIntent(args.command);
  }
  return args || {};
}

class ToolRepetitionGuard {
  constructor({ unchangedLimit = 2 } = {}) {
    this.unchangedLimit = Math.max(1, Number(unchangedLimit) || 2);
    this.entries = new Map();
  }

  key(toolName, args) {
    return `${String(toolName || '')}:${stableHash(canonicalToolArgs(toolName, args))}`;
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
      argsHash: stableHash(canonicalToolArgs(toolName, args)),
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
  normalizeReadOnlyShellIntent,
  stableHash,
};
