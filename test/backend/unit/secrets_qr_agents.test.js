'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('integration secrets encrypt, decrypt, and avoid double encryption', () => {
  ctx = createTestRuntime();
  const { encryptValue, decryptValue, isEncryptedValue } = require('../../../server/services/integrations/secrets');
  const encrypted = encryptValue('secret-value');
  assert.equal(isEncryptedValue(encrypted), true);
  assert.equal(decryptValue(encrypted), 'secret-value');
  assert.equal(encryptValue(encrypted), encrypted);
  assert.equal(encryptValue(''), '');
  assert.equal(encryptValue(null), '');
  assert.equal(decryptValue('plain'), 'plain');
});

test('QR login test exports parse SQLite UTC dates and expiration state', () => {
  ctx = createTestRuntime();
  const { __test } = require('../../../server/services/account/qr_login');
  assert.equal(Number.isFinite(__test.parseSqliteUtcMs('2026-05-25 12:00:00')), true);
  assert.equal(Number.isFinite(__test.parseSqliteUtcMs('2026-05-25T12:00:00Z')), true);
  assert.equal(Number.isNaN(__test.parseSqliteUtcMs('')), true);
  assert.equal(__test.challengeIsExpired({ expires_at: '2000-01-01 00:00:00' }), true);
  assert.equal(__test.challengeIsExpired({ expires_at: '2999-01-01 00:00:00' }), false);
  assert.equal(__test.challengeIsExpired(null), true);
});

test('agent manager creates defaults, resolves IDs, normalizes slugs, and isolates users', async () => {
  ctx = createTestRuntime();
  const db = ctx.db;
  const userA = await createTestUser(db, { username: 'agent_a' });
  const userB = await createTestUser(db, { username: 'agent_b' });
  const manager = require('../../../server/services/agents/manager');

  const main = manager.ensureMainAgent(userA.userId);
  assert.equal(main.slug, 'main');
  assert.equal(manager.resolveAgentId(userA.userId, null), main.id);

  const custom = manager.createAgent(userA.userId, { displayName: 'Research Agent !!' });
  assert.equal(custom.slug, 'research-agent');

  const agentsA = manager.listAgents(userA.userId);
  const agentsB = manager.listAgents(userB.userId);
  assert.equal(agentsA.some((agent) => agent.id === custom.id), true);
  assert.equal(agentsB.some((agent) => agent.id === custom.id), false);
});
