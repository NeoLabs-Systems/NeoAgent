'use strict';

const { createHash } = require('crypto');
const { canonicalize } = require('../../repetitionGuard');

function argsDigest(args) {
  return `sha256:${createHash('sha256').update(JSON.stringify(canonicalize(args || {}))).digest('hex').slice(0, 32)}`;
}

// Argument values and names may both contain user content. Neither belongs in
// the metadata ledger; the step/capture stores have separate access and retention.
function redactArgs(args = {}) {
  return { count: Object.keys(args || {}).length, digest: argsDigest(args) };
}

// Last-boundary protection for error bodies echoed by tools/providers. Never
// retain arbitrary exception text in the metadata ledger.
function redactEventPayload(value) {
  if (Array.isArray(value)) return value.map(redactEventPayload);
  if (!value || typeof value !== 'object') return value;
  const out = {};
  for (const [key, item] of Object.entries(value)) {
    if (key === 'args_redacted') out[key] = { count: Number(item?.count) || 0, digest: item?.digest || argsDigest(item) };
    else if (key === 'error') out[key] = item ? { present: true } : null;
    else out[key] = redactEventPayload(item);
  }
  return out;
}

module.exports = {
  argsDigest,
  redactArgs,
  redactEventPayload,
};
