'use strict';

const DEFAULT_CAPTURE_INTERVAL_MS = 10 * 1000;
const DEFAULT_RETENTION_DAYS = 7;
const CLEANUP_INTERVAL_MS = 24 * 60 * 60 * 1000;
const MIN_CAPTURE_INTERVAL_MS = 1000;
const MINIMUM_TEXT_LENGTH = 5;
const FRONTMOST_APP_SCRIPT = 'tell application "System Events" to get name of first application process whose frontmost is true';

function isExplicitlyEnabled(value) {
  return ['1', 'true', 'on', 'yes'].includes(String(value || '').trim().toLowerCase());
}

function parsePositiveInteger(value, name, fallback, minimum = 1) {
  if (value == null || String(value).trim() === '') {
    return fallback;
  }

  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < minimum) {
    throw new Error(`${name} must be an integer greater than or equal to ${minimum}.`);
  }
  return parsed;
}

function hasOpenConnectionForUser(registry, userId) {
  const connections = registry?.connectionsByUser?.get(String(userId));
  if (connections instanceof Map) {
    return Array.from(connections.values()).some(
      (connection) => typeof connection?.isOpen === 'function' && connection.isOpen(),
    );
  }
  return typeof connections?.isOpen === 'function' && connections.isOpen();
}

module.exports = {
  CLEANUP_INTERVAL_MS,
  DEFAULT_CAPTURE_INTERVAL_MS,
  DEFAULT_RETENTION_DAYS,
  FRONTMOST_APP_SCRIPT,
  MINIMUM_TEXT_LENGTH,
  MIN_CAPTURE_INTERVAL_MS,
  hasOpenConnectionForUser,
  isExplicitlyEnabled,
  parsePositiveInteger,
};
