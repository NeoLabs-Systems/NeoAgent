'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const Sqlite = require('better-sqlite3');

const { removeRetiredBillingData } = require('../../../lib/schema_migrations');

const BILLING_TABLES = [
  'billing_plans',
  'billing_customers',
  'user_subscriptions',
  'subscription_events',
  'trial_fingerprints',
];

test('retired billing cleanup drops the billing tables and the plan override column', () => {
  const db = new Sqlite(':memory:');
  try {
    db.exec(`
      CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, billing_override_plan_id TEXT);
      CREATE TABLE billing_plans (id TEXT PRIMARY KEY);
      CREATE TABLE billing_customers (user_id INTEGER PRIMARY KEY, stripe_customer_id TEXT);
      CREATE TABLE user_subscriptions (id TEXT PRIMARY KEY, user_id INTEGER, plan_id TEXT REFERENCES billing_plans(id));
      CREATE TABLE subscription_events (id INTEGER PRIMARY KEY, user_id INTEGER);
      CREATE TABLE trial_fingerprints (id INTEGER PRIMARY KEY, user_id INTEGER);
      INSERT INTO users (id, username, billing_override_plan_id) VALUES (1, 'neo', 'plan_pro');
      INSERT INTO billing_plans (id) VALUES ('plan_pro');
      INSERT INTO user_subscriptions (id, user_id, plan_id) VALUES ('sub', 1, 'plan_pro');
    `);

    removeRetiredBillingData(db);
    // Runs on every start, so a second pass must be a no-op.
    removeRetiredBillingData(db);

    const remaining = db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all().map((row) => row.name);
    assert.deepEqual(remaining.filter((name) => BILLING_TABLES.includes(name)), []);
    assert.deepEqual(db.prepare('PRAGMA table_info(users)').all().map((column) => column.name), ['id', 'username']);
    assert.deepEqual(db.prepare('SELECT id, username FROM users').all(), [{ id: 1, username: 'neo' }]);
  } finally {
    db.close();
  }
});
