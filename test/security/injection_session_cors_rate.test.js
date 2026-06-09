'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

function sidCookie(res) {
  const raw = res.headers['set-cookie'] || [];
  const sid = raw.find((item) => item.startsWith('neoagent.sid='));
  return sid ? sid.split(';')[0] : '';
}

describe('injection, sessions, rate limiting, and CORS', () => {
  let ctx;
  let app;

  before(() => {
    ctx = createTestRuntime();
    app = createTestApp().app;
  });

  after(() => teardownTestRuntime(ctx));

  test('SQL injection payloads in auth fields do not authenticate or crash', async () => {
    const user = await createTestUser(ctx.db, { username: 'inject_user' });
    for (const payload of [`${user.username}' OR 1=1 --`, "' OR '1'='1", 'admin"; DROP TABLE users; --']) {
      const res = await request(app).post('/api/auth/login').send({
        username: payload,
        password: 'anything',
      });
      assert.notEqual(res.statusCode, 200);
      assert.notEqual(res.statusCode, 500);
    }
    assert.equal(ctx.db.prepare('SELECT COUNT(*) AS count FROM users').get().count > 0, true);
  });

  test('XSS payloads are JSON encoded and error responses do not leak paths or stack traces', async () => {
    const user = await createTestUser(ctx.db, { username: 'xss_user' });
    const client = agent(app);
    await loginAs(client, user);
    const payload = '<img src=x onerror=alert(1)>';
    const res = await client.put('/api/account/display-name').send({ displayName: payload }).expect(200);
    assert.equal(res.body.user.display_name, payload);
    assert.equal(res.headers['content-type'].includes('application/json'), true);
    const bad = await client.post('/api/mcp').send({ name: 'bad', command: 'file:///etc/passwd' }).expect(400);
    assert.doesNotMatch(bad.text, /\/Users\/|node_modules|at\s+\w+\s+\(/);
  });

  test('session id changes on login, logout invalidates session, and hashes never leak', async () => {
    const user = await createTestUser(ctx.db, { username: 'session_user' });
    const client = agent(app);
    const beforeLogin = await client.get('/api/auth/status').expect(200);
    const beforeSid = sidCookie(beforeLogin);
    const login = await client.post('/api/auth/login').send({
      username: user.username,
      password: user.password,
    }).expect(200);
    const afterSid = sidCookie(login);
    assert.ok(afterSid);
    assert.notEqual(afterSid, beforeSid);
    assert.equal(login.text.includes('$2'), false);
    const me = await client.get('/api/auth/me').expect(200);
    assert.equal(me.text.includes('$2'), false);
    await client.post('/api/auth/logout').expect(200);
    await client.get('/api/auth/me').expect(401);
  });

  test('login and password reset rate limiters return 429 under repeated same-IP attempts', async () => {
    const loginIp = '10.20.30.40';
    let loginLimited = false;
    for (let index = 0; index < 22; index += 1) {
      const res = await request(app)
        .post('/api/auth/login')
        .set('X-Forwarded-For', loginIp)
        .send({ username: `nobody_${index}`, password: 'wrong' });
      if (res.statusCode === 429) {
        loginLimited = true;
        assert.ok(res.headers['ratelimit-limit'] || res.headers['ratelimit']);
        break;
      }
    }
    assert.equal(loginLimited, true);

    const resetIp = '10.20.30.41';
    let resetLimited = false;
    for (let index = 0; index < 22; index += 1) {
      const res = await request(app)
        .post('/api/auth/password/forgot')
        .set('X-Forwarded-For', resetIp)
        .send({ account: `nobody_${index}@example.com` });
      if (res.statusCode === 429) {
        resetLimited = true;
        break;
      }
    }
    assert.equal(resetLimited, true);
  });

  test('CORS and origin checks allow same-origin but block external/null state-changing origins', async () => {
    const user = await createTestUser(ctx.db, { username: 'cors_user' });
    const client = agent(app);
    await loginAs(client, user);
    await client.put('/api/account/display-name').send({ displayName: 'Allowed' }).expect(200);
    await client
      .put('/api/account/display-name')
      .set('Origin', 'https://evil.example')
      .send({ displayName: 'Blocked' })
      .expect(403);
    await client
      .put('/api/account/display-name')
      .set('Origin', 'null')
      .send({ displayName: 'Blocked' })
      .expect(403);
    await client
      .put('/api/account/display-name')
      .set('Origin', 'http://localhost:5173')
      .send({ displayName: 'Loopback' })
      .expect(200);
  });
});
