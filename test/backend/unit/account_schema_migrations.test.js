'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createTestRuntime,
  flushProjectCache,
  teardownTestRuntime,
} = require('../../helpers/db');

function insertPendingSignup(db, username) {
  const { lastInsertRowid } = db.prepare(`
    INSERT INTO users (username, email, email_verified_at, password)
    VALUES (?, ?, NULL, 'hash')
  `).run(username, `${username}@example.com`);
  db.prepare(`
    INSERT INTO user_email_tokens (user_id, type, email, token_hash, expires_at)
    VALUES (?, 'signup_confirmation', ?, ?, datetime('now', '+1 day'))
  `).run(lastInsertRowid, `${username}@example.com`, `hash-${username}`);
  return Number(lastInsertRowid);
}

function restartDatabase(db) {
  db.close();
  flushProjectCache();
  return require('../../../server/db/database');
}

test('a pending sign-up stays unconfirmed across restarts; pre-confirmation accounts are backfilled once', async () => {
  const ctx = createTestRuntime();
  try {
    let db = ctx.db;
    const pendingId = insertPendingSignup(db, 'pending_signup');
    db = restartDatabase(db);
    const verifiedAt = (id) => db.prepare('SELECT email_verified_at FROM users WHERE id = ?').get(id).email_verified_at;
    assert.equal(verifiedAt(pendingId), null);

    // A database from before email confirmation: its accounts never got a
    // sign-up token and are confirmed by the one-time backfill.
    db.pragma('user_version = 0');
    const legacyId = Number(db.prepare(`
      INSERT INTO users (username, email, email_verified_at, password)
      VALUES ('legacy_account', 'legacy@example.com', NULL, 'hash')
    `).run().lastInsertRowid);
    db = restartDatabase(db);
    assert.ok(verifiedAt(legacyId));
    assert.equal(verifiedAt(pendingId), null);
    assert.ok(db.pragma('user_version', { simple: true }) >= 1);

    db.prepare("UPDATE users SET email_verified_at = NULL WHERE id = ?").run(legacyId);
    db = restartDatabase(db);
    assert.equal(verifiedAt(legacyId), null, 'the backfill must not run again');
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('the first account to be able to sign in becomes admin, not an unconfirmed sign-up', () => {
  const ctx = createTestRuntime();
  try {
    const { db } = ctx;
    const isAdmin = (id) => db.prepare('SELECT is_admin FROM users WHERE id = ?').get(id).is_admin;

    const pendingId = insertPendingSignup(db, 'first_pending');
    assert.equal(isAdmin(pendingId), 0);
    db.prepare("UPDATE users SET email_verified_at = datetime('now') WHERE id = ?").run(pendingId);
    assert.equal(isAdmin(pendingId), 1);

    const laterPendingId = insertPendingSignup(db, 'later_pending');
    db.prepare("UPDATE users SET email_verified_at = datetime('now') WHERE id = ?").run(laterPendingId);
    assert.equal(isAdmin(laterPendingId), 0);
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('a self-hosted first account without email confirmation is admin at once', () => {
  const ctx = createTestRuntime();
  try {
    const { db } = ctx;
    const id = Number(db.prepare(`
      INSERT INTO users (username, email, email_verified_at, password)
      VALUES ('operator', 'operator@example.com', datetime('now'), 'hash')
    `).run().lastInsertRowid);
    assert.equal(db.prepare('SELECT is_admin FROM users WHERE id = ?').get(id).is_admin, 1);
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('usernames are unique regardless of case, and existing case duplicates do not block startup', () => {
  const ctx = createTestRuntime();
  try {
    const { db } = ctx;
    const { migrateCaseInsensitiveAccountNames } = require('../../../lib/schema_migrations');
    const insert = db.prepare("INSERT INTO users (username, password) VALUES (?, 'hash')");
    insert.run('Neo');
    assert.throws(() => insert.run('neo'), /UNIQUE constraint failed/);

    db.exec('DROP INDEX idx_users_username_lower');
    insert.run('NEO');
    assert.doesNotThrow(() => migrateCaseInsensitiveAccountNames(db));
    const index = db.prepare(
      "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = 'idx_users_username_lower'",
    ).get();
    assert.equal(index, undefined);
  } finally {
    teardownTestRuntime(ctx);
  }
});
