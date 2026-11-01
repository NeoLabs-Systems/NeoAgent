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

  test('usage data sharing is opt-in and only changes through its own route', async () => {
    const user = await createTestUser(ctx.db, { username: 'sharing_user' });
    const client = agent(app);
    await loginAs(client, user);

    const before = await client.get('/api/account').expect(200);
    assert.equal(before.body.dataSharing.enabled, false);
    assert.equal((await client.get('/api/auth/me').expect(200)).body.user.sharesUsageData, false);

    await client.put('/api/settings').send({ usage_data_sharing: { enabled: true } }).expect(200);
    await client.put('/api/settings/usage_data_sharing').send({ value: { enabled: true } }).expect(403);
    assert.equal((await client.get('/api/account').expect(200)).body.dataSharing.enabled, false);

    await client.put('/api/account/data-sharing').send({ enabled: 'yes' }).expect(400);
    const on = await client
      .put('/api/account/data-sharing')
      .send({ enabled: true, client: { platform: 'web', appVersion: '3.6.1' } })
      .expect(200);
    assert.equal(on.body.dataSharing.enabled, true);
    assert.deepEqual(on.body.dataSharing.client, { platform: 'web', appVersion: '3.6.1' });
    assert.equal((await client.get('/api/auth/me').expect(200)).body.user.sharesUsageData, true);

    const off = await client.put('/api/account/data-sharing').send({ enabled: false }).expect(200);
    assert.deepEqual(off.body.dataSharing, { enabled: false, since: null, client: null });
  });

  test('sign-up failures name the field with a stable code', async () => {
    const attempt = (body) => request(app).post('/api/auth/register').set('X-Forwarded-For', '10.77.0.2').send({
      username: 'code_user',
      email: 'code_user@example.com',
      password: 'AutonomousPass1!',
      ...body,
    });
    const shortName = await attempt({ username: 'ab' }).expect(400);
    assert.equal(shortName.body.code, 'USERNAME_TOO_SHORT');
    assert.match(shortName.body.error, /Username/);
    assert.equal((await attempt({ password: 'Ab1!' }).expect(400)).body.code, 'PASSWORD_TOO_SHORT');
    const weak = await attempt({ password: 'Zq9!codeuserW' }).expect(400);
    assert.equal(weak.body.code, 'PASSWORD_WEAK');
    assert.match(weak.body.error, /username or email/);
    assert.equal((await attempt({ email: 'not-an-email' }).expect(400)).body.code, 'INVALID_EMAIL');

    await attempt({}).expect(200);
    assert.equal(
      (await attempt({ username: 'CODE_USER', email: 'other@example.com' }).expect(409)).body.code,
      'USERNAME_TAKEN',
    );
    assert.equal(
      (await attempt({ username: 'code_user_2', email: 'Code_User@Example.com' }).expect(409)).body.code,
      'EMAIL_TAKEN',
    );
    const login = await request(app).post('/api/auth/login').set('X-Forwarded-For', '10.77.0.2')
      .send({ username: 'code_user', password: 'wrong' }).expect(401);
    assert.equal(login.body.code, 'INVALID_CREDENTIALS');
  });

  test('sign-in takes the username or the email in any letter case', async () => {
    const user = await createTestUser(ctx.db, { username: 'MixedCase_User', email: 'mixed.case@example.com' });
    for (const account of ['mixedcase_user', 'MIXEDCASE_USER', 'Mixed.Case@Example.com']) {
      const res = await request(app).post('/api/auth/login').set('X-Forwarded-For', '10.77.0.3')
        .send({ username: account, password: user.password }).expect(200);
      assert.equal(res.body.user.username, 'MixedCase_User');
    }
  });

  test('sign-in over plain http is refused when session cookies are https-only', async () => {
    const session = require('express-session');
    const secureApp = createTestApp({
      sessionMiddleware: session({
        secret: 'test-secret-32-chars-long-for-suite',
        name: 'neoagent.sid',
        resave: false,
        saveUninitialized: false,
        proxy: true,
        cookie: { httpOnly: true, sameSite: 'lax', secure: true },
      }),
    }).app;
    secureApp.locals.httpRuntimeConfig.publicUrl = 'https://agent.example.com/app';
    const user = await createTestUser(ctx.db, { username: 'insecure_transport_user' });

    const refused = await request(secureApp).post('/api/auth/login').set('X-Forwarded-For', '10.77.0.4')
      .send({ username: user.username, password: user.password }).expect(400);
    assert.equal(refused.body.code, 'INSECURE_TRANSPORT');
    assert.equal(refused.body.httpsUrl, 'https://agent.example.com');
    assert.match(refused.body.error, /https:\/\/agent\.example\.com/);
    const register = await request(secureApp).post('/api/auth/register').set('X-Forwarded-For', '10.77.0.4').send({
      username: 'insecure_signup', email: 'insecure_signup@example.com', password: 'AutonomousPass1!',
    }).expect(400);
    assert.equal(register.body.code, 'INSECURE_TRANSPORT');
    assert.equal(ctx.db.prepare('SELECT 1 FROM users WHERE username = ?').get('insecure_signup'), undefined);

    const proxied = await request(secureApp).post('/api/auth/login')
      .set('X-Forwarded-For', '10.77.0.4')
      .set('X-Forwarded-Proto', 'https')
      .send({ username: user.username, password: user.password }).expect(200);
    assert.ok(String(proxied.headers['set-cookie'] || '').includes('neoagent.sid'));
  });

  test('showing sign-in QR codes does not use up the sign-in rate limit', async () => {
    const ip = '10.77.0.1';
    for (let index = 0; index < 20; index += 1) {
      await request(app).post('/api/auth/qr-login/challenge')
        .set('X-Forwarded-For', ip).send({}).expect(200);
    }
    const user = await createTestUser(ctx.db, { username: 'qr_then_login' });
    await request(app).post('/api/auth/login')
      .set('X-Forwarded-For', ip)
      .send({ username: user.username, password: user.password })
      .expect(200);
  });
});
