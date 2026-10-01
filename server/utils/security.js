'use strict';

const crypto = require('crypto');

const HOME = process.env.HOME || process.env.USERPROFILE || '';
const PROJECT_ROOT = require('path').join(__dirname, '../..');

function sanitizeError(err) {
  if (!err) return 'An unexpected error occurred';
  const raw = typeof err === 'string' ? err : err.message || String(err);

  let msg = raw;
  if (!msg || msg === '[object Object]') {
    msg = 'An unexpected error occurred';
  }

  // Replace home directory path with ~
  if (HOME) {
    msg = msg.split(HOME).join('~');
  }

  // Replace project root path with [app]
  if (PROJECT_ROOT) {
    msg = msg.split(PROJECT_ROOT).join('[app]');
  }

  // Strip node_modules paths with either slash style.
  msg = msg.replace(/(?:^|[\s'"(\[])\S*?[\\/]node_modules(?:[\\/]\S*)?/g, (match) => {
    const prefixMatch = match.match(/^[\s'"(\[]/);
    const prefix = prefixMatch ? prefixMatch[0] : '';
    return `${prefix}[module]`;
  });

  // Strip remaining absolute Unix paths (leave short relative paths intact).
  msg = msg.replace(/(^|[\s'"(\[])\/(?:[^\s'"\])]+\/){2,}[^\s'"\])]+/g, '$1[path]');

  // Strip Windows absolute paths and UNC paths with either slash style.
  msg = msg.replace(/(^|[\s'"(\[])(?:[A-Za-z]:[\\/](?:[^\s'"\])]+[\\/])+[^\s'"\])]+|[\\/]{2}[^\s'"\\/\])]+[\\/][^\s'"\])]+(?:[\\/][^\s'"\])]+)+)/g, '$1[path]');

  return msg.trim() || 'An unexpected error occurred';
}

function validateString(value, { maxLength = 50000, name = 'value' } = {}) {
  if (typeof value !== 'string') throw new Error(`${name} must be a string`);
  if (value.length === 0) throw new Error(`${name} must not be empty`);
  if (value.length > maxLength) throw new Error(`${name} exceeds maximum length of ${maxLength} characters`);
  return value;
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left ?? ''), 'utf8');
  const b = Buffer.from(String(right ?? ''), 'utf8');
  if (a.length === 0 || b.length === 0) return false;
  const size = Math.max(a.length, b.length);
  const paddedA = Buffer.alloc(size);
  const paddedB = Buffer.alloc(size);
  a.copy(paddedA);
  b.copy(paddedB);
  return crypto.timingSafeEqual(paddedA, paddedB) && a.length === b.length;
}

// PKCE code challenges and similar OAuth values need base64url, which Node's
// digest() does not emit directly.
function base64UrlSha256(value) {
  return crypto
    .createHash('sha256')
    .update(String(value || ''))
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

module.exports = { base64UrlSha256, sanitizeError, validateString, safeEqual };
