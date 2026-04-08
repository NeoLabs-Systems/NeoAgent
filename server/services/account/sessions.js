'use strict';

const crypto = require('crypto');
const Sqlite = require('better-sqlite3');
const { DATA_DIR } = require('../../../runtime/paths');
const db = require('../../db/database');
const { clientIpFromRequest, lookupIpLocation } = require('./geoip');
const { getSessionSecret } = require('./session_secret');

const sessionsDb = new Sqlite(`${DATA_DIR}/sessions.db`);
try {
  sessionsDb.exec('CREATE TABLE IF NOT EXISTS sessions (sid PRIMARY KEY, sess, expire)');
} catch {
  // The primary session middleware owns schema normalization.
}

function sessionHash(sessionId) {
  return crypto.createHmac('sha256', getSessionSecret()).update(String(sessionId || '')).digest('hex');
}

function sessionExpiresAt(req) {
  const cookie = req.session?.cookie;
  const expires = cookie?.expires;
  if (expires) return new Date(expires).toISOString();
  const maxAge = Number(cookie?.originalMaxAge || 0);
  if (maxAge > 0) return new Date(Date.now() + maxAge).toISOString();
  return null;
}

function userAgentFromRequest(req) {
  return String(req.get?.('user-agent') || req.headers?.['user-agent'] || '').slice(0, 500);
}

function sessionIsActiveWhere(alias = '') {
  const prefix = alias ? `${alias}.` : '';
  return `${prefix}revoked_at IS NULL AND (${prefix}expires_at IS NULL OR datetime(${prefix}expires_at) > datetime('now'))`;
}

function sessionLooksUnusual(userId, hash, geo, userAgent) {
  const previous = db.prepare(`
    SELECT ip_address, user_agent, location_label
    FROM user_sessions
    WHERE user_id = ?
      AND session_hash != ?
      AND ${sessionIsActiveWhere()}
    ORDER BY datetime(last_seen_at) DESC
    LIMIT 20
  `).all(userId, hash);
  if (!previous.length) return false;

  const ip = String(geo.ipAddress || '');
  const location = String(geo.label || '');
  return !previous.some((row) => {
    const sameDevice = row.ip_address === ip && row.user_agent === userAgent;
    const sameLocation = location && location !== 'Unknown' && row.location_label === location;
    return sameDevice || sameLocation;
  });
}

function recordCurrentSession(req, userId, options = {}) {
  if (!req?.sessionID || !userId) return null;
  const geo = lookupIpLocation(clientIpFromRequest(req));
  const hash = sessionHash(req.sessionID);
  const userAgent = userAgentFromRequest(req);
  const expiresAt = sessionExpiresAt(req);
  const existing = db.prepare('SELECT id FROM user_sessions WHERE session_hash = ?').get(hash);
  const unusual = options.login === true && !existing
    ? sessionLooksUnusual(userId, hash, geo, userAgent)
    : false;
  db.prepare(`
    INSERT INTO user_sessions (
      user_id, session_hash, ip_address, user_agent, location_label,
      location_json, created_at, last_seen_at, expires_at, revoked_at
    )
    VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'), ?, NULL)
    ON CONFLICT(session_hash) DO UPDATE SET
      user_id = excluded.user_id,
      ip_address = excluded.ip_address,
      user_agent = excluded.user_agent,
      location_label = excluded.location_label,
      location_json = excluded.location_json,
      last_seen_at = datetime('now'),
      expires_at = excluded.expires_at,
      revoked_at = NULL
  `).run(
    userId,
    hash,
    geo.ipAddress,
    userAgent,
    geo.label,
    JSON.stringify(geo.data || {}),
    expiresAt,
  );
  return {
    hash,
    isNew: !existing,
    unusual,
    ipAddress: geo.ipAddress,
    location: geo.label,
    userAgent,
  };
}

function pruneExpiredSessions() {
  try {
    db.prepare(`
      UPDATE user_sessions
      SET revoked_at = COALESCE(revoked_at, datetime('now'))
      WHERE expires_at IS NOT NULL
        AND datetime(expires_at) <= datetime('now')
        AND revoked_at IS NULL
    `).run();
  } catch {
    // Session metadata should never block account settings.
  }
}

function parseLocationJson(value) {
  try {
    const parsed = JSON.parse(value || '{}');
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function listSessions(req, userId) {
  recordCurrentSession(req, userId);
  pruneExpiredSessions();
  const currentHash = req?.sessionID ? sessionHash(req.sessionID) : null;
  return db.prepare(`
    SELECT id, session_hash, ip_address, user_agent, location_label, location_json,
           created_at, last_seen_at, expires_at
    FROM user_sessions
    WHERE user_id = ?
      AND revoked_at IS NULL
      AND (expires_at IS NULL OR datetime(expires_at) > datetime('now'))
    ORDER BY datetime(last_seen_at) DESC, id DESC
  `).all(userId).map((row) => ({
    id: row.id,
    current: currentHash === row.session_hash,
    ipAddress: row.ip_address || null,
    userAgent: row.user_agent || '',
    location: row.location_label || 'Unknown',
    locationData: parseLocationJson(row.location_json),
    createdAt: row.created_at || null,
    lastSeenAt: row.last_seen_at || null,
    expiresAt: row.expires_at || null,
  }));
}

function revokeSession(req, userId, sessionRecordId) {
  const row = db.prepare(`
    SELECT id, session_hash
    FROM user_sessions
    WHERE id = ? AND user_id = ? AND revoked_at IS NULL
  `).get(sessionRecordId, userId);
  if (!row) {
    const error = new Error('Session not found');
    error.statusCode = 404;
    throw error;
  }

  if (req?.sessionID && row.session_hash === sessionHash(req.sessionID)) {
    const error = new Error('Use logout to end the current session');
    error.statusCode = 400;
    throw error;
  }

  try {
    const sessionRows = sessionsDb.prepare('SELECT sid FROM sessions').all();
    const matching = sessionRows.find((sessionRow) => sessionHash(sessionRow.sid) === row.session_hash);
    if (matching?.sid) {
      sessionsDb.prepare('DELETE FROM sessions WHERE sid = ?').run(matching.sid);
    }
  } catch {
    // Test harnesses and partially migrated installs may not have the session table yet.
    // Session metadata is still revoked below.
  }

  db.prepare('UPDATE user_sessions SET revoked_at = datetime(\'now\') WHERE id = ? AND user_id = ?')
    .run(row.id, userId);
  return { success: true };
}

function revokeAllSessionsForUser(userId) {
  if (!userId) return { success: true, revoked: 0 };
  const rows = db.prepare(`
    SELECT id, session_hash
    FROM user_sessions
    WHERE user_id = ? AND revoked_at IS NULL
  `).all(userId);

  try {
    const sessionRows = sessionsDb.prepare('SELECT sid FROM sessions').all();
    const hashes = new Set(rows.map((row) => row.session_hash));
    const deleteSession = sessionsDb.prepare('DELETE FROM sessions WHERE sid = ?');
    for (const sessionRow of sessionRows) {
      if (hashes.has(sessionHash(sessionRow.sid))) {
        deleteSession.run(sessionRow.sid);
      }
    }
  } catch {
    // Session metadata is still revoked below.
  }

  db.prepare(`
    UPDATE user_sessions
    SET revoked_at = datetime('now')
    WHERE user_id = ? AND revoked_at IS NULL
  `).run(userId);
  return { success: true, revoked: rows.length };
}

module.exports = {
  listSessions,
  recordCurrentSession,
  revokeAllSessionsForUser,
  revokeSession,
  sessionHash,
};
