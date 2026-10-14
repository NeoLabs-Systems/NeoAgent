'use strict';

const bcrypt = require('bcrypt');
const crypto = require('crypto');
const db = require('../../db/database');
const { redeemSignupKeyForNewUser } = require('../access/signup_keys');
const { isReservedAdminUsername } = require('../access/admin');
const { isUsernameTaken, validateNewUsername } = require('./credentials');

function normalizeUsernameCandidate(value) {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '')
    .replace(/^[._-]+|[._-]+$/g, '');
  if (normalized.length >= 3) {
    return normalized.slice(0, 32);
  }
  return '';
}

function hasUsernameCandidate(identity) {
  return Boolean(normalizeUsernameCandidate(identity.username || identity.displayName)
    || normalizeUsernameCandidate(String(identity.email || '').split('@')[0]));
}

async function createProviderAccount(identity, signupKey, provider, selectedUsername) {
  const passwordHash = await bcrypt.hash(crypto.randomUUID(), 12);
  return db.transaction(() => {
    // Another callback can register this identity while password hashing yields.
    const existing = db.prepare(
      'SELECT user_id FROM user_auth_providers WHERE provider_key = ? AND provider_user_id = ?',
    ).get(provider.key, identity.providerUserId);
    if (existing) {
      saveProviderAccount(existing.user_id, provider, identity);
      return { userId: existing.user_id, created: false };
    }
    if (selectedUsername) validateNewUsername(selectedUsername);
    const username = selectedUsername || generateUniqueUsername(identity);
    const result = db.prepare(
      `INSERT INTO users (
         username,
         email,
         email_verified_at,
         password,
         password_login_enabled
       ) VALUES (?, ?, ?, ?, 0)`,
    ).run(
      username,
      identity.email?.toLowerCase() || null,
      identity.email ? new Date().toISOString() : null,
      passwordHash,
    );
    const userId = Number(result.lastInsertRowid);
    redeemSignupKeyForNewUser(signupKey, userId);
    saveProviderAccount(userId, provider, identity);
    return { userId, created: true };
  })();
}

function generateUniqueUsername(identity) {
  const candidates = [
    normalizeUsernameCandidate(identity.username || identity.displayName),
    normalizeUsernameCandidate(String(identity.email || '').split('@')[0]),
    'user',
  ].filter(Boolean);

  for (const candidate of candidates) {
    const value = firstAvailableUsername(candidate);
    if (value) return value;
  }
  return firstAvailableUsername('user');
}

function firstAvailableUsername(base) {
  const normalizedBase = normalizeUsernameCandidate(base) || 'user';
  for (let attempt = 0; attempt < 1000; attempt += 1) {
    const suffix = attempt === 0 ? '' : String(attempt + 1);
    const username = `${normalizedBase}${suffix}`.slice(0, 32);
    if (!isUsernameTaken(username) && !isReservedAdminUsername(username)) return username;
  }
  return `user${Date.now().toString().slice(-6)}`;
}

function saveProviderAccount(userId, provider, identity) {
  db.transaction(() => {
    saveLink(userId, provider, identity);
    provider.saveCredentials?.(userId, identity);
  })();
}

function saveLink(userId, provider, identity) {
  db.prepare(
    `INSERT INTO user_auth_providers (
       user_id,
       provider_key,
       provider_user_id,
       email,
       metadata_json,
       last_used_at,
       updated_at
     ) VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))
     ON CONFLICT(provider_key, provider_user_id) DO UPDATE SET
       user_id = excluded.user_id,
       email = excluded.email,
       metadata_json = excluded.metadata_json,
       last_used_at = excluded.last_used_at,
       updated_at = excluded.updated_at`,
  ).run(
    userId,
    provider.key,
    identity.providerUserId,
    identity.email?.toLowerCase() || null,
    JSON.stringify({
      displayName: identity.displayName || null,
      avatarUrl: identity.avatarUrl || null,
      emailVerified: identity.emailVerified === true,
      ...(identity.metadata || {}),
    }),
  );
}

module.exports = { createProviderAccount, saveProviderAccount, hasUsernameCandidate };
