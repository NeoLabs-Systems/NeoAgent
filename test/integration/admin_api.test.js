'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

describe('admin API', () => {
  let ctx;
  let app;
  let owner;
  let member;

  function setAdmin(userId, isAdmin) {
    ctx.db.prepare('UPDATE users SET is_admin = ? WHERE id = ?').run(isAdmin ? 1 : 0, userId);
  }

  async function signedIn(user) {
    const client = agent(app);
    await loginAs(client, user);
    return client;
  }

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    owner = await createTestUser(ctx.db, { username: 'install_owner' });
    member = await createTestUser(ctx.db, { username: 'regular_member' });
  });

  after(() => teardownTestRuntime(ctx));

  test('the first account on a fresh install is admin, later accounts are not', () => {
    const flag = (userId) => ctx.db.prepare('SELECT is_admin FROM users WHERE id = ?').get(userId).is_admin;
    assert.equal(flag(owner.userId), 1);
    assert.equal(flag(member.userId), 0);
  });

  test('admin routes need a session, then the admin flag', async () => {
    await request(app).get('/api/admin/users').expect(401);

    const client = await signedIn(member);
    const denied = await client.get('/api/admin/users').expect(403);
    assert.equal(denied.body.code, 'ADMIN_REQUIRED');
    await client.post('/api/admin/sql').send({ query: 'SELECT 1' }).expect(403);
    await client.put('/api/admin/access/signup').send({ enabled: false }).expect(403);
  });

  test('server updates are admin-only', async () => {
    const client = await signedIn(member);
    const update = await client.post('/api/settings/update').expect(403);
    assert.equal(update.body.code, 'ADMIN_REQUIRED');
    const channel = await client.put('/api/settings/update/channel').send({ channel: 'beta' }).expect(403);
    assert.equal(channel.body.code, 'ADMIN_REQUIRED');
  });

  test('admins list and search accounts, including who is admin', async () => {
    const client = await signedIn(owner);
    const res = await client.get('/api/admin/users').expect(200);
    const byName = new Map(res.body.users.map((user) => [user.username, user]));
    assert.equal(byName.get(owner.username).is_admin, 1);
    assert.equal(byName.get(member.username).is_admin, 0);
    assert.equal(typeof byName.get(member.username).run_count, 'number');
    assert.equal(Object.hasOwn(byName.get(member.username), 'password'), false);

    const search = await client.get('/api/admin/users').query({ q: 'regular_' }).expect(200);
    assert.deepEqual(search.body.users.map((user) => user.username), [member.username]);
  });

  test('revoking admin applies to the very next request of an existing session', async () => {
    const deputy = await createTestUser(ctx.db, { username: 'deputy_admin' });
    setAdmin(deputy.userId, true);
    const client = await signedIn(deputy);
    await client.get('/api/admin/users').expect(200);

    setAdmin(deputy.userId, false);
    const denied = await client.get('/api/admin/users').expect(403);
    assert.equal(denied.body.code, 'ADMIN_REQUIRED');
    await client.get('/api/auth/me').expect(200);
  });

  test('deleting accounts refuses admins and erases everyone else', async () => {
    const client = await signedIn(owner);

    const self = await client.delete(`/api/admin/users/${owner.userId}`).expect(403);
    assert.equal(self.body.code, 'ADMIN_ACCOUNT');
    const otherAdmin = await createTestUser(ctx.db, { username: 'other_admin' });
    setAdmin(otherAdmin.userId, true);
    const other = await client.delete(`/api/admin/users/${otherAdmin.userId}`).expect(403);
    assert.equal(other.body.code, 'ADMIN_ACCOUNT');

    const doomed = await createTestUser(ctx.db, { username: 'doomed_member' });
    const erased = await client.delete(`/api/admin/users/${doomed.userId}`).expect(200);
    assert.equal(erased.body.ok, true);
    assert.equal(typeof erased.body.tablesCleared, 'number');
    assert.equal(ctx.db.prepare('SELECT id FROM users WHERE id = ?').get(doomed.userId), undefined);

    await client.delete('/api/admin/users/999999').expect(404);
    await client.delete('/api/admin/users/not-a-number').expect(400);
  });

  test('per-account and default rate limits round-trip and are validated', async () => {
    const client = await signedIn(owner);
    await client
      .put(`/api/admin/users/${member.userId}/rate-limits`)
      .send({ rate_limit_4h: 5000, rate_limit_weekly: null })
      .expect(200);
    const limits = await client.get(`/api/admin/users/${member.userId}/rate-limits`).expect(200);
    assert.deepEqual(limits.body.limits, { rate_limit_4h: 5000, rate_limit_weekly: null });
    await client
      .put(`/api/admin/users/${member.userId}/rate-limits`)
      .send({ rate_limit_4h: -1 })
      .expect(400);

    await client.put('/api/admin/config/rate-limits').send({ rate_limit_4h: 7000, rate_limit_weekly: 90000 }).expect(200);
    const defaults = await client.get('/api/admin/config/rate-limits').expect(200);
    assert.deepEqual(defaults.body, { rate_limit_4h: 7000, rate_limit_weekly: 90000 });
  });

  test('the SQL console runs read-only queries and rejects everything else', async () => {
    const client = await signedIn(owner);
    const usersBefore = ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n;

    const res = await client
      .post('/api/admin/sql')
      .send({ query: 'SELECT id, username FROM users ORDER BY id' })
      .expect(200);
    assert.deepEqual(res.body.columns, ['id', 'username']);
    assert.equal(res.body.rows[0].username, owner.username);
    assert.equal(res.body.truncated, false);
    assert.equal(res.body.total, usersBefore);

    for (const query of [
      'DELETE FROM users',
      "UPDATE users SET is_admin = 1 WHERE username = 'regular_member'",
      'WITH doomed AS (SELECT id FROM users) DELETE FROM users WHERE id IN doomed',
      'SELECT 1; DROP TABLE users',
      '',
    ]) {
      await client.post('/api/admin/sql').send({ query }).expect(400);
    }
    assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users').get().n, usersBefore);
  });

  test('access settings expose only the sign-up toggle', async () => {
    const client = await signedIn(owner);
    const access = await client.get('/api/admin/access').expect(200);
    assert.deepEqual(access.body, { signupEnabled: true });

    const off = await client.put('/api/admin/access/signup').send({ enabled: false }).expect(200);
    assert.deepEqual(off.body, { ok: true, signupEnabled: false });
    const on = await client.put('/api/admin/access/signup').send({ enabled: true }).expect(200);
    assert.equal(on.body.signupEnabled, true);
  });

  test('server overview endpoints answer with the documented shapes', async () => {
    const client = await signedIn(owner);
    const version = await client.get('/api/admin/version').expect(200);
    assert.equal(typeof version.body.uptime, 'number');
    assert.equal(typeof version.body.updateStatus.state, 'string');
    const health = await client.get('/api/admin/health').expect(200);
    assert.ok(health.body.results.some((result) => result.id === 'database' && result.passed));
    const analytics = await client.get('/api/admin/analytics').query({ range: 7 }).expect(200);
    assert.equal(analytics.body.stats.totalUsers >= 2, true);
    const logs = await client.get('/api/admin/logs').expect(200);
    assert.ok(Array.isArray(logs.body.logs));
  });

  test('the retired standalone admin endpoints are gone', async () => {
    const client = await signedIn(owner);
    await client.get('/api/admin/config').expect(404);
    await client.post('/api/admin/settings/apikey/rotate').expect(404);
    await request(app).post('/admin/api/login').send({ username: 'admin', password: 'x' }).expect(404);
  });
});
