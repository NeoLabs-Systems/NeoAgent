'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

describe('auth and account routes', () => {
  let ctx;
  let app;

  before(() => {
    ctx = createTestRuntime();
    app = createTestApp().app;
  });

  after(() => teardownTestRuntime(ctx));

  test('auth status returns public unauthenticated shape', async () => {
    const res = await request(app).get('/api/auth/status').expect(200);
    assert.equal(typeof res.body.hasUser, 'boolean');
    assert.equal(res.body.authenticated, false);
    assert.equal(res.body.user, null);
    assert.ok(Array.isArray(res.body.providers));
  });

  test('register validates fields, creates a session, and prevents duplicate email', async () => {
    await request(app).post('/api/auth/register').send({}).expect(400);
    await request(app).post('/api/auth/register').send({
      username: 'ab',
      email: 'bad',
      password: 'short',
    }).expect(400);

    const client = agent(app);
    const res = await client.post('/api/auth/register').send({
      username: 'registered_user',
      email: 'registered@example.com',
      password: 'AutonomousPass1!',
    }).expect(200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.user.username, 'registered_user');
    assert.equal(Object.hasOwn(res.body.user, 'password'), false);
    await client.get('/api/auth/me').expect(200);

    await request(app).post('/api/auth/register').send({
      username: 'registered_user_2',
      email: 'registered@example.com',
      password: 'AutonomousPass1!',
    }).expect(409);
  });

  test('login handles bad credentials, establishes session, and logout destroys it', async () => {
    const user = await createTestUser(ctx.db, { username: 'login_user' });
    const client = agent(app);
    await client.post('/api/auth/login').send({ username: user.username }).expect(400);
    await client.post('/api/auth/login').send({ username: user.username, password: 'wrong' }).expect(401);
    const res = await client.post('/api/auth/login').send({
      username: user.username,
      password: user.password,
    }).expect(200);
    assert.equal(res.body.success, true);
    assert.equal(res.text.includes('$2'), false);
    await client.get('/api/auth/me').expect(200);
    await client.post('/api/auth/logout').expect(200);
    await client.get('/api/auth/me').expect(401);
  });

  test('password reset request is anti-enumeration', async () => {
    const res = await request(app)
      .post('/api/auth/password/forgot')
      .send({ account: 'nobody@example.com' })
      .expect(200);
    assert.equal(res.body.success, true);
  });

  test('account routes require auth and expose account/session state', async () => {
    const user = await createTestUser(ctx.db, { username: 'account_user' });
    await request(app).get('/api/account').expect(401);

    const client = agent(app);
    await loginAs(client, user);
    const account = await client.get('/api/account').expect(200);
    assert.equal(account.body.user.username, user.username);
    assert.equal(typeof account.body.twoFactor.enabled, 'boolean');
    assert.ok(Array.isArray(account.body.authProviders));

    const updated = await client
      .put('/api/account/display-name')
      .send({ displayName: 'Neo Tester' })
      .expect(200);
    assert.equal(updated.body.user.display_name, 'Neo Tester');
    assert.equal(
      ctx.db.prepare('SELECT display_name FROM users WHERE id = ?').get(user.userId).display_name,
      'Neo Tester',
    );

    const sessions = await client.get('/api/account/sessions').expect(200);
    assert.ok(Array.isArray(sessions.body.sessions));
    assert.ok(sessions.body.sessions.length >= 1);

    await client.post('/api/account/2fa/setup').send({ currentPassword: 'wrong' }).expect(401);
  });
});
