'use strict';

const db = require('../../db/database');
const { normalizeTimeZone } = require('../../utils/timezone');

// The user's configured IANA time zone, or null when they have not set one.
function getUserTimeZone(userId) {
  const row = db.prepare("SELECT value FROM user_settings WHERE user_id = ? AND key = 'timezone'").get(userId);
  return normalizeTimeZone(row?.value);
}

module.exports = { getUserTimeZone };
