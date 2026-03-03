/**
 * Security utilities — shared helpers for input validation and output sanitization.
 */

const HOME = process.env.HOME || process.env.USERPROFILE || '';
const PROJECT_ROOT = require('path').join(__dirname, '../..');

/**
 * Strip internal filesystem paths and module stack frames from an error message
 * before sending it to a client. Prevents leaking absolute paths, internal
 * directory structure, or dependency internals in API responses.
 */
function sanitizeError(err) {
  if (!err) return 'An unexpected error occurred';
  const raw = typeof err === 'string' ? err : err.message || String(err);

  let msg = raw;

  // Replace home directory path with ~
  if (HOME) {
    msg = msg.split(HOME).join('~');
  }

  // Replace project root path with [app]
  if (PROJECT_ROOT) {
    msg = msg.split(PROJECT_ROOT).join('[app]');
  }

  // Strip node_modules paths
  msg = msg.replace(/[^\s'"]+node_modules[^\s'"]+/g, '[module]');

  // Strip remaining absolute Unix paths (leave relative paths intact)
  msg = msg.replace(/\/[a-zA-Z0-9._-]+(?:\/[a-zA-Z0-9._-]+){2,}/g, '[path]');

  // Strip Windows absolute paths
  msg = msg.replace(/[A-Za-z]:\\[^\s'"]+/g, '[path]');

  return msg.trim() || 'An unexpected error occurred';
}

/**
 * Validate that a value is a plain string within an allowed length range.
 */
function validateString(value, { maxLength = 50000, name = 'value' } = {}) {
  if (typeof value !== 'string') throw new Error(`${name} must be a string`);
  if (value.length === 0) throw new Error(`${name} must not be empty`);
  if (value.length > maxLength) throw new Error(`${name} exceeds maximum length of ${maxLength} characters`);
  return value;
}

/**
 * Returns true if the string looks like it contains a prompt injection attempt.
 * This is a heuristic for logging/alerting — NOT a hard block (context window still applies).
 */
function detectPromptInjection(text) {
  if (typeof text !== 'string') return false;
  const patterns = [
    /ignore\s+(all\s+)?previous\s+instructions/i,
    /you\s+are\s+now\s+(DAN|GPT|jailbreak)/i,
    /system\s+prompt\s*(override|bypass|end)/i,
    /\[SYSTEM\]/i,
    /###\s*(SYSTEM|OVERRIDE|NEW INSTRUCTIONS)/i,
    /<\/?system>/i,
    /reveal\s+(your\s+)?(system\s+)?prompt/i,
    /act\s+as\s+if\s+you\s+have\s+no\s+(rules|restrictions|guidelines)/i,
    /forget\s+(all\s+)?(previous|prior)\s+(instructions|context|training)/i,
  ];
  return patterns.some(p => p.test(text));
}

module.exports = { sanitizeError, validateString, detectPromptInjection };
