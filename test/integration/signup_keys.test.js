'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

describe('sign-up keys', () => {
  let ctx;
  let app;
  let admin;
  let member;
  let previousAllowSignup;

  function setKeyRequired(required) {
    process.env.NEOAGENT_ALLOW_SIGNUP = required ? 'false' : 'true';
  }

  function keyRow(code) {
    return ctx.db.prepare('SELECT * FROM signup_keys WHERE code = ?').get(code.replace(/-/g, ''));
  }

  function registration(username, signupKey) {
    return {
      username,
      email: `${username}@example.com`,
      password: 'Correct-Horse-Battery-9',
      ...(signupKey === undefined ? {} : { signupKey }),
    };
  }

  before(async () => {
    previousAllowSignup = process.env.NEOAGENT_ALLOW_SIGNUP;
    ctx = createTestRuntime();
    app = createTestApp().app;
    const owner = await createTestUser(ctx.db, { username: 'keys_admin' });
    member = await createTestUser(ctx.db, { username: 'keys_member' });
    admin = agent(app);
    await loginAs(admin, owner);
  });

  after(() => {
    if (previousAllowSignup == null) delete process.env.NEOAGENT_ALLOW_SIGNUP;
    else process.env.NEOAGENT_ALLOW_SIGNUP = previousAllowSignup;
    teardownTestRuntime(ctx);
  });

  test('key management is admin-only', async () => {
    const client = agent(app);
    await loginAs(client, member);
    await client.get('/api/admin/signup-keys').expect(403);
    await client.post('/api/admin/signup-keys').send({ count: 1 }).expect(403);
  });

  test('the access setting switches between open sign-up and keys', async () => {
    setKeyRequired(false);
    assert.deepEqual((await admin.get('/api/admin/access').expect(200)).body, { signupKeyRequired: false });

    const on = await admin.put('/api/admin/access/signup').send({ keyRequired: true }).expect(200);
    assert.deepEqual(on.body, { ok: true, signupKeyRequired: true });
    assert.equal(process.env.NEOAGENT_ALLOW_SIGNUP, 'false');
    await admin.put('/api/admin/access/signup').send({ keyRequired: 'yes' }).expect(400);

    const status = await request(app).get('/api/auth/status').expect(200);
    assert.equal(status.body.signupKeyRequired, true);
    assert.equal(status.body.registrationOpen, false);
  });

  test('admins create keys singly or in batches, with a label', async () => {
    await admin.post('/api/admin/signup-keys').send({ count: 0 }).expect(400);
    await admin.post('/api/admin/signup-keys').send({ count: 501 }).expect(400);
    await admin.post('/api/admin/signup-keys').send({ count: '3' }).expect(400);

    const res = await admin.post('/api/admin/signup-keys').send({ count: 3, label: '  Beta wave  ' }).expect(201);
    assert.equal(res.body.keys.length, 3);
    for (const key of res.body.keys) {
      assert.match(key.code, /^[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}$/);
      assert.equal(key.label, 'Beta wave');
      assert.equal(key.status, 'unused');
      assert.equal(key.createdBy, 'keys_admin');
    }
    assert.equal(new Set(res.body.keys.map((key) => key.code)).size, 3);

    const list = await admin.get('/api/admin/signup-keys').expect(200);
    assert.ok(list.body.keys.length >= 3);
  });

  test('registration needs a valid, unused key and spends it', async () => {
    setKeyRequired(true);
    const [key] = (await admin.post('/api/admin/signup-keys').send({ count: 1 }).expect(201)).body.keys;

    const missing = await request(app).post('/api/auth/register').send(registration('no_key_user')).expect(403);
    assert.equal(missing.body.code, 'SIGNUP_KEY_REQUIRED');
    const wrong = await request(app).post('/api/auth/signup-key/check').send({ key: 'AAAA-AAAA-AAAA' }).expect(403);
    assert.equal(wrong.body.code, 'SIGNUP_KEY_INVALID');

    // Typed loosely: lower case, no dashes, O for 0 and I/L for 1.
    const loose = key.code.toLowerCase().replace(/-/g, '').replace(/0/g, 'o').replace(/1/g, 'l');
    assert.deepEqual((await request(app).post('/api/auth/signup-key/check').send({ key: loose }).expect(200)).body, { valid: true });

    const client = agent(app);
    await client.post('/api/auth/register').send(registration('keyed_user', loose)).expect(200);
    const row = keyRow(key.code);
    assert.ok(row.used_at);
    const user = ctx.db.prepare('SELECT id FROM users WHERE username = ?').get('keyed_user');
    assert.equal(row.used_by_user_id, user.id);

    const listed = (await admin.get('/api/admin/signup-keys').expect(200)).body.keys.find((k) => k.id === key.id);
    assert.equal(listed.status, 'used');
    assert.deepEqual(listed.usedBy, { id: user.id, username: 'keyed_user' });

    const reused = await request(app).post('/api/auth/register').send(registration('second_user', key.code)).expect(403);
    assert.equal(reused.body.code, 'SIGNUP_KEY_USED');
    assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM users WHERE username = ?').get('second_user').n, 0);
  });

  test('a revoked key stops working; a used key cannot be revoked', async () => {
    setKeyRequired(true);
    const [key] = (await admin.post('/api/admin/signup-keys').send({ count: 1 }).expect(201)).body.keys;
    await admin.delete(`/api/admin/signup-keys/${key.id}`).expect(200);
    await admin.delete(`/api/admin/signup-keys/${key.id}`).expect(404);
    const res = await request(app).post('/api/auth/signup-key/check').send({ key: key.code }).expect(403);
    assert.equal(res.body.code, 'SIGNUP_KEY_INVALID');

    const used = ctx.db.prepare('SELECT id FROM signup_keys WHERE used_at IS NOT NULL').get();
    await admin.delete(`/api/admin/signup-keys/${used.id}`).expect(404);
  });

  test('with open sign-up no key is needed and none is spent', async () => {
    setKeyRequired(false);
    const [key] = (await admin.post('/api/admin/signup-keys').send({ count: 1 }).expect(201)).body.keys;
    await agent(app).post('/api/auth/register').send(registration('open_user', key.code)).expect(200);
    assert.equal(keyRow(key.code).used_at, null);
  });
});
