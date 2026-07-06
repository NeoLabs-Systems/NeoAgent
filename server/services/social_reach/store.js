'use strict';

const db = require('../../db/database');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { normalizePlatformId } = require('./platforms');

function cookieSettingKey(platform) {
  return `social_reach_cookies_${normalizePlatformId(platform)}`;
}

function readRawSetting(userId, key) {
  if (!userId || !key) return null;
  return db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, key)?.value || null;
}

function writeRawSetting(userId, key, value) {
  db.prepare(
    `INSERT INTO user_settings (user_id, key, value)
     VALUES (?, ?, ?)
     ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`,
  ).run(userId, key, value);
}

function deleteRawSetting(userId, key) {
  db.prepare('DELETE FROM user_settings WHERE user_id = ? AND key = ?').run(userId, key);
}

function readJsonSetting(userId, key, fallback = null) {
  const raw = readRawSetting(userId, key);
  if (!raw) return fallback;
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

function readCookieBundle(userId, platform) {
  const raw = readRawSetting(userId, cookieSettingKey(platform));
  if (!raw) return null;
  try {
    return JSON.parse(decryptValue(raw));
  } catch {
    return null;
  }
}

function writeCookieBundle(userId, platform, bundle) {
  const payload = {
    platform: normalizePlatformId(platform),
    importedAt: new Date().toISOString(),
    cookies: Array.isArray(bundle?.cookies) ? bundle.cookies : [],
  };
  writeRawSetting(userId, cookieSettingKey(platform), encryptValue(JSON.stringify(payload)));
  return payload;
}

function deleteCookieBundle(userId, platform) {
  deleteRawSetting(userId, cookieSettingKey(platform));
}

function getCookieSummary(userId, platform) {
  const bundle = readCookieBundle(userId, platform);
  const cookies = Array.isArray(bundle?.cookies) ? bundle.cookies : [];
  return {
    configured: cookies.length > 0,
    count: cookies.length,
    importedAt: bundle?.importedAt || null,
  };
}

function cookieHeaderForPlatform(userId, platform) {
  const bundle = readCookieBundle(userId, platform);
  const cookies = Array.isArray(bundle?.cookies) ? bundle.cookies : [];
  return cookies
    .filter((cookie) => cookie && cookie.name && cookie.value != null)
    .map((cookie) => `${String(cookie.name).trim()}=${String(cookie.value)}`)
    .join('; ');
}

module.exports = {
  cookieHeaderForPlatform,
  cookieSettingKey,
  deleteCookieBundle,
  getCookieSummary,
  readCookieBundle,
  readJsonSetting,
  writeCookieBundle,
};
