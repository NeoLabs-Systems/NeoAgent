'use strict';

const db = require('../../db/database');

// Every change to who is admin or who manages whom lands here. Rows keep user
// ids only (set to NULL when an account is erased), never names or emails, so
// the log survives account deletion without retaining personal data.

function recordAccessEvent(action, { actorUserId = null, subjectUserId = null, detail = {} } = {}) {
  db.prepare(`
    INSERT INTO access_audit_log (action, actor_user_id, subject_user_id, detail_json)
    VALUES (?, ?, ?, ?)
  `).run(action, actorUserId, subjectUserId, JSON.stringify(detail));
}

// Usernames for the user ids referenced inside event details (e.g. the manager
// of a new delegation), so the activity list can name them.
function usernamesById(entries) {
  const ids = new Set();
  for (const entry of entries) {
    for (const [key, value] of Object.entries(entry.detail)) {
      if (key.endsWith('UserId') && Number.isInteger(value)) ids.add(value);
    }
  }
  if (ids.size === 0) return {};
  const list = [...ids];
  const rows = db.prepare(
    `SELECT id, username FROM users WHERE id IN (${list.map(() => '?').join(', ')})`,
  ).all(...list);
  return Object.fromEntries(rows.map((row) => [row.id, row.username]));
}

function listAccessEvents({ limit = 100 } = {}) {
  const rows = db.prepare(`
    SELECT log.id, log.action, log.detail_json, log.created_at,
           actor.id AS actor_id, actor.username AS actor_username,
           subject.id AS subject_id, subject.username AS subject_username
    FROM access_audit_log log
    LEFT JOIN users actor ON actor.id = log.actor_user_id
    LEFT JOIN users subject ON subject.id = log.subject_user_id
    ORDER BY log.id DESC
    LIMIT ?
  `).all(limit);
  const entries = rows.map((row) => ({
    id: row.id,
    action: row.action,
    actor: row.actor_id == null ? null : { id: row.actor_id, username: row.actor_username },
    subject: row.subject_id == null ? null : { id: row.subject_id, username: row.subject_username },
    detail: JSON.parse(row.detail_json || '{}'),
    createdAt: row.created_at,
  }));
  return { entries, usernames: usernamesById(entries) };
}

module.exports = { recordAccessEvent, listAccessEvents };
