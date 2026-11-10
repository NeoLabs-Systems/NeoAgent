'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');
const { resolvePublicBaseUrl } = require('../integrations/env');

const SETTING_KEY = 'web_sharing_enabled';
const MAX_SHARES_PER_USER = 20;
const GUEST_AGENT_PORT = 8421;

// First path segments the server already answers. A share lives at
// /<username>/<slug>, so an account whose name is one of these cannot share.
const RESERVED_SEGMENTS = new Set([
  'api', 'app', 'socket.io', '_neolabs', 'status', 'login', 'logout', 'auth', 'health',
  'assets', 'css', 'images', 'js', 'index.html', 'status.html', '404.html',
  'app-build.json', 'favicon.ico', 'robots.txt', 'sitemap.xml', '.well-known',
]);

// On unless the owner turned it off; an unreadable setting counts as off, so a
// broken read never exposes a page.
function isWebSharingEnabled(userId) {
  if (userId == null) return false;
  try {
    const row = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, SETTING_KEY);
    if (!row) return true;
    return JSON.parse(row.value) !== false;
  } catch {
    return false;
  }
}

function slugFor(name) {
  return String(name || '')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48)
    .replace(/-+$/, '');
}

function userSegment(username) {
  return encodeURIComponent(String(username || ''));
}

function isReservedSegment(segment) {
  return RESERVED_SEGMENTS.has(String(segment || '').toLowerCase());
}

function shareUrl(username, slug, baseUrl = resolvePublicBaseUrl()) {
  return `${String(baseUrl).replace(/\/+$/, '')}/${userSegment(username)}/${slug}/`;
}

function usernameOf(userId) {
  return db.prepare('SELECT username FROM users WHERE id = ?').get(userId)?.username || '';
}

function describe(row, username, baseUrl) {
  return {
    id: row.id,
    name: row.title || row.slug,
    slug: row.slug,
    port: row.port,
    url: shareUrl(username, row.slug, baseUrl),
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

function listShares(userId, { baseUrl } = {}) {
  const username = usernameOf(userId);
  return db.prepare('SELECT * FROM web_shares WHERE user_id = ? ORDER BY created_at, id')
    .all(userId)
    .map((row) => describe(row, username, baseUrl));
}

function validatePort(value) {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535 || port === GUEST_AGENT_PORT) return null;
  return port;
}

// Creates the share, or points an existing one with the same name at the port.
function saveShare({ userId, agentId = null, name, port, baseUrl }) {
  const username = usernameOf(userId);
  if (!username) return { error: 'Unknown account.' };
  if (isReservedSegment(userSegment(username))) {
    return { error: `Pages cannot be shared under the account name "${username}", which the server uses for its own pages.` };
  }
  const slug = slugFor(name);
  if (!slug) return { error: 'name needs at least one letter or digit.' };
  const existing = db.prepare('SELECT id FROM web_shares WHERE user_id = ? AND slug = ?').get(userId, slug);
  if (!existing) {
    const count = db.prepare('SELECT COUNT(*) AS count FROM web_shares WHERE user_id = ?').get(userId).count;
    if (count >= MAX_SHARES_PER_USER) {
      return { error: `At most ${MAX_SHARES_PER_USER} pages can be shared at once; stop sharing one first.` };
    }
    db.prepare('INSERT INTO web_shares (id, user_id, agent_id, slug, title, port) VALUES (?, ?, ?, ?, ?, ?)')
      .run(randomUUID(), userId, agentId, slug, String(name).trim().slice(0, 120), port);
  } else {
    db.prepare("UPDATE web_shares SET port = ?, title = ?, agent_id = ?, updated_at = datetime('now') WHERE id = ?")
      .run(port, String(name).trim().slice(0, 120), agentId, existing.id);
  }
  const row = db.prepare('SELECT * FROM web_shares WHERE user_id = ? AND slug = ?').get(userId, slug);
  return { share: describe(row, username, baseUrl), replaced: Boolean(existing) };
}

// By id, slug or the name it was shared under.
function removeShare(userId, ref) {
  const key = String(ref || '').trim();
  if (!key) return false;
  const result = db.prepare('DELETE FROM web_shares WHERE user_id = ? AND (id = ? OR slug = ?)')
    .run(userId, key, slugFor(key) || key);
  return result.changes > 0;
}

// The share a public address points at, if its owner still allows sharing.
function findPublicShare(segment, slug) {
  if (isReservedSegment(segment)) return null;
  let username;
  try {
    username = decodeURIComponent(segment);
  } catch {
    return null;
  }
  const user = db.prepare('SELECT id, username FROM users WHERE lower(username) = lower(?)').get(username);
  if (!user || !isWebSharingEnabled(user.id)) return null;
  const share = db.prepare('SELECT * FROM web_shares WHERE user_id = ? AND slug = ?').get(user.id, String(slug || '').toLowerCase());
  return share ? { share, user } : null;
}

module.exports = {
  MAX_SHARES_PER_USER,
  SETTING_KEY,
  findPublicShare,
  isReservedSegment,
  isWebSharingEnabled,
  listShares,
  removeShare,
  saveShare,
  shareUrl,
  slugFor,
  userSegment,
  validatePort,
};
