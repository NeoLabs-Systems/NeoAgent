'use strict';

// Opt-in usage data sharing. A user who turns it on lets the server's admins
// see their usage metadata in the admin analytics, pooled with every other
// sharing account. Consent lives in one user_settings row; turning it off
// deletes the device snapshot with it.

const db = require('../../db/database');
const { httpError } = require('../../utils/http_error');

const SETTING_KEY = 'usage_data_sharing';

const CLIENT_PLATFORMS = new Set(['android', 'ios', 'web', 'macos', 'windows', 'linux']);
const APP_VERSION_PATTERN = /^[0-9A-Za-z.+-]{1,32}$/;

function readRecord(userId) {
  const row = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, SETTING_KEY);
  if (!row) return null;
  try {
    return JSON.parse(row.value);
  } catch {
    return null;
  }
}

function writeRecord(userId, record) {
  db.prepare(`
    INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)
    ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value
  `).run(userId, SETTING_KEY, JSON.stringify(record));
}

// Only a fixed set of coarse fields survives; anything else the client sends
// is dropped rather than stored.
function normalizeClient(value) {
  if (!value || typeof value !== 'object') return null;
  const platform = String(value.platform || '').toLowerCase();
  const appVersion = String(value.appVersion || '');
  return {
    platform: CLIENT_PLATFORMS.has(platform) ? platform : null,
    appVersion: APP_VERSION_PATTERN.test(appVersion) ? appVersion : null,
  };
}

function getDataSharing(userId) {
  const record = readRecord(userId);
  const enabled = record?.enabled === true;
  return {
    enabled,
    since: enabled ? record.since || null : null,
    client: enabled ? record.client || null : null,
  };
}

function setDataSharing(userId, { enabled, client } = {}) {
  if (typeof enabled !== 'boolean') {
    throw httpError(400, 'enabled must be true or false');
  }
  const current = getDataSharing(userId);
  if (!enabled) {
    writeRecord(userId, { enabled: false });
  } else {
    writeRecord(userId, {
      enabled: true,
      since: current.since || new Date().toISOString(),
      client: normalizeClient(client) || current.client,
    });
  }
  return getDataSharing(userId);
}

// The app refreshes its device snapshot at sign-in. Ignored unless sharing is on.
function recordClientSnapshot(userId, client) {
  const current = getDataSharing(userId);
  if (!current.enabled) return current;
  writeRecord(userId, { enabled: true, since: current.since, client: normalizeClient(client) });
  return getDataSharing(userId);
}

function listSharingRecords() {
  const rows = db.prepare(`
    SELECT s.user_id, s.value
    FROM user_settings s
    JOIN users u ON u.id = s.user_id
    WHERE s.key = ?
  `).all(SETTING_KEY);
  const records = [];
  for (const row of rows) {
    try {
      const record = JSON.parse(row.value);
      if (record?.enabled === true) records.push({ userId: row.user_id, client: record.client || null });
    } catch {
      // A malformed row counts as not sharing.
    }
  }
  return records;
}

module.exports = {
  SETTING_KEY,
  getDataSharing,
  setDataSharing,
  recordClientSnapshot,
  listSharingRecords,
};
