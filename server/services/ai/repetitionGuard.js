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
  if (toolName === 'execute_command' && isClearlyReadOnlyShellCommand(args?.command || '', { fetches: true })) {
    return normalizeReadOnlyShellIntent(args.command);
  }
  return args || {};
}

// How long an earlier answer can stand in for a repeated read. Nothing the
// harness saw changed, but a person or a background process could have.
const DUPLICATE_READ_WINDOW_MS = 2 * 60 * 1000;
// A tool that fails the same way for different arguments is down, not misused:
// a used-up search quota, an organization that blocks the app, a service that is
// unreachable. Asking it again with other arguments only burns turns, so after
// this many such failures in a row it rests, for as long as it said or a minute.
const TOOL_FAILURE_LIMIT = 3;
const TOOL_REST_MS = 60 * 1000;

/**
 * Tells a useful repeat from a useless one. A call's fingerprint includes the
 * version of the state it depends on, so re-reading a file after an edit is new
 * work and re-reading it before any edit is not. Two rules follow:
 *
 * - A deterministic read repeated against unchanged state is suppressed once; the
 *   model already has that answer. If it asks again it has a reason, such as a
 *   background process writing the file, so the next one runs.
 * - Anything else is stopped only once it has failed the same way repeatedly: a
 *   search or a poll can legitimately change, and a failed call changed nothing, so
 *   repeating it cannot turn out differently.
 */
class ToolRepetitionGuard {
  constructor({ unchangedLimit = 2, now = Date.now } = {}) {
    this.unchangedLimit = Math.max(1, Number(unchangedLimit) || 2);
    this.now = now;
    this.entries = new Map();
    this.answeredReads = new Map();
    this.stateVersions = new Map();
    this.toolFailures = new Map();
    // A compaction may have removed the earlier answer from the model's view.
    this.contextEpoch = 0;
  }

  stateVersion(scope) {
    return this.stateVersions.get(scope) || 0;
  }

  fingerprint(toolName, args, stateScope = 'none') {
    return stableHash({
      tool: String(toolName || ''),
      args: canonicalToolArgs(toolName, args),
      state: `${stateScope}:${this.stateVersion(stateScope)}`,
      epoch: this.contextEpoch,
    });
  }

  key(toolName, args, stateScope = null) {
    const state = stateScope ? `:${stateScope}:${this.stateVersion(stateScope)}` : '';
    return `${String(toolName || '')}${state}:${stableHash(canonicalToolArgs(toolName, args))}`;
  }

  noteStateChanged(scope) {
    if (scope && scope !== 'none') this.stateVersions.set(scope, this.stateVersion(scope) + 1);
  }

  noteCompaction() {
    this.contextEpoch += 1;
    this.answeredReads.clear();
    for (const [key, entry] of this.entries) {
      if (!entry.failure) this.entries.delete(key);
    }
  }

  // Claims the read before it runs, so identical reads in one parallel batch run
  // once. The claim is dropped again if the read fails, and by the suppression it
  // causes, so one repeat is stopped and the one after it is not.
  claimRead(fingerprint, stepIndex) {
    const prior = this.answeredReads.get(fingerprint);
    if (prior && this.now() - prior.at < DUPLICATE_READ_WINDOW_MS) {
      this.answeredReads.delete(fingerprint);
      return prior;
    }
    this.answeredReads.set(fingerprint, { stepIndex, at: this.now() });
    return null;
  }

  releaseRead(fingerprint) {
    this.answeredReads.delete(fingerprint);
  }

  // Successful reads use the timed claim cache. Repeated failures are blocked,
  // but reads may retry after expiry because external state can change.
  shouldBlock(toolName, args, { readOnly = true, stateScope = null } = {}) {
    const entry = this.entries.get(this.key(toolName, args, stateScope));
    if (!entry || entry.unchangedCount < this.unchangedLimit) return false;
    if (readOnly && this.now() - entry.at >= DUPLICATE_READ_WINDOW_MS) return false;
    return Boolean(entry.failure);
  }

  lastFailure(toolName, args, stateScope = null) {
    return this.entries.get(this.key(toolName, args, stateScope))?.failure || '';
  }

  // Why a tool cannot be used right now, or null.
  toolResting(toolName) {
    const streak = this.toolFailures.get(String(toolName || ''));
    if (!streak || streak.count < TOOL_FAILURE_LIMIT || this.now() >= streak.until) return null;
    return { failure: streak.failure, count: streak.count, retryInMs: streak.until - this.now() };
  }

  #noteToolOutcome(toolName, failure, result) {
    const name = String(toolName || '');
    if (!failure) {
      this.toolFailures.delete(name);
      return;
    }
    const previous = this.toolFailures.get(name);
    const count = previous?.failure === failure ? previous.count + 1 : 1;
    const retryAfterMs = Number(result?.retryAfterSeconds) > 0 ? Number(result.retryAfterSeconds) * 1000 : TOOL_REST_MS;
    this.toolFailures.set(name, { failure, count, until: this.now() + retryAfterMs });
  }

  observe(toolName, args, result, failure = '', { stateScope = null } = {}) {
    this.#noteToolOutcome(toolName, failure, result);
    const key = this.key(toolName, args, stateScope);
    const resultHash = stableHash(failure ? { failure } : result);
    const previous = this.entries.get(key);
    const unchangedCount = previous?.resultHash === resultHash
      ? previous.unchangedCount + 1
      : 1;
    const next = {
      at: this.now(),
      toolName,
      argsHash: stableHash(canonicalToolArgs(toolName, args)),
      resultHash,
      unchangedCount,
      failure,
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
