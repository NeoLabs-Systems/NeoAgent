'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const Sqlite = require('better-sqlite3');

const { migrateAccessControl } = require('../../../lib/schema_migrations');

function legacyDatabase(usernames, { pendingEmail = false } = {}) {
  const db = new Sqlite(':memory:');
  db.exec(`
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      email TEXT,
      email_verified_at TEXT
    );
    CREATE TABLE admin_two_factor (id INTEGER PRIMARY KEY CHECK (id = 1));
    CREATE TABLE admin_recovery_codes (id INTEGER PRIMARY KEY AUTOINCREMENT);
  `);
  for (const username of usernames) {
    db.prepare('INSERT INTO users (username, password, email, email_verified_at) VALUES (?, ?, ?, ?)')
      .run(username, 'x', pendingEmail ? `${username}@example.com` : null, null);
  }
  return db;
}

function admins(db) {
  return db.prepare('SELECT username FROM users WHERE is_admin = 1 ORDER BY id').all()
    .map((row) => row.username);
}

test('a single-account install promotes its only account once', () => {
  const db = legacyDatabase(['owner']);
  migrateAccessControl(db);
  assert.deepEqual(admins(db), ['owner']);

  // Re-running on every boot must not re-promote after an operator revoke.
  db.prepare('UPDATE users SET is_admin = 0').run();
  migrateAccessControl(db);
  assert.deepEqual(admins(db), []);
});

test('a pending email signup or a managed deployment is never promoted', () => {
  const pending = legacyDatabase(['stranger'], { pendingEmail: true });
  migrateAccessControl(pending);
  assert.deepEqual(admins(pending), []);

  const previous = process.env.NEOAGENT_DEPLOYMENT_MODE;
  process.env.NEOAGENT_DEPLOYMENT_MODE = 'managed';
  try {
    const managed = legacyDatabase(['tenant']);
    migrateAccessControl(managed);
    assert.deepEqual(admins(managed), []);
  } finally {
    if (previous === undefined) delete process.env.NEOAGENT_DEPLOYMENT_MODE;
    else process.env.NEOAGENT_DEPLOYMENT_MODE = previous;
  }
});

test('a multi-account install gets no automatic admin', () => {
  const db = legacyDatabase(['first', 'second']);
  migrateAccessControl(db);
  assert.deepEqual(admins(db), []);
});

test('the first account created on a fresh install becomes admin, later ones do not', () => {
  const db = legacyDatabase([]);
  migrateAccessControl(db);
  db.prepare('INSERT INTO users (username, password) VALUES (?, ?)').run('first', 'x');
  db.prepare('INSERT INTO users (username, password) VALUES (?, ?)').run('second', 'x');
  assert.deepEqual(admins(db), ['first']);
});

test('the singleton admin 2FA tables are dropped', () => {
  const db = legacyDatabase([]);
  migrateAccessControl(db);
  for (const table of ['admin_two_factor', 'admin_recovery_codes']) {
    assert.equal(
      db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?").get(table),
      undefined,
    );
  }
});
