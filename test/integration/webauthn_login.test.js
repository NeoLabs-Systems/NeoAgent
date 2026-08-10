'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');
const { createVirtualAuthenticator } = require('../helpers/webauthn');

const ORIGIN = 'http://localhost:3000';

describe('security key (WebAuthn) sign-in', () => {
  let ctx;
  let app;

  before(() => {
    ctx = createTestRuntime();
    app = createTestApp().app;
  });

  after(() => teardownTestRuntime(ctx));

  function enableTwoFactor(userId) {
    ctx.db.prepare(`
      INSERT INTO user_two_factor (user_id, secret, enabled, enabled_at)
      VALUES (?, 'stored-secret', 1, datetime('now'))
      ON CONFLICT(user_id) DO UPDATE SET secret = excluded.secret, enabled = 1
    `).run(userId);
  }

  async function registerSecurityKey(client, authenticator, label) {
    const optionsRes = await client
      .post('/api/account/security-keys/register/options')
      .set('Origin', ORIGIN)
      .expect(200);
    const attestation = authenticator.register({
      options: optionsRes.body.options,
      origin: ORIGIN,
    });
    return client
      .post('/api/account/security-keys/register/verify')
      .set('Origin', ORIGIN)
      .send({ response: attestation, label })
      .expect(200);
  }

  async function signInWithSecurityKey(client, authenticator, { username, userHandle } = {}) {
    const optionsRes = await client
      .post('/api/auth/webauthn/login/options')
      .set('Origin', ORIGIN)
      .send(username ? { username } : {})
      .expect(200);
    const assertion = authenticator.authenticate({
      options: optionsRes.body.options,
      origin: ORIGIN,
      userHandle,
    });
    return client
      .post('/api/auth/webauthn/login/verify')
      .set('Origin', ORIGIN)
      .send({ response: assertion });
  }

  test('registers a key, signs in without a password, and manages the key', async () => {
    const user = await createTestUser(ctx.db, { username: 'webauthn_primary' });
    const authenticator = createVirtualAuthenticator();
    const client = agent(app);
    await loginAs(client, user);

    const registered = await registerSecurityKey(client, authenticator, 'YubiKey 5');
    assert.equal(registered.body.success, true);
    assert.equal(registered.body.credentials.length, 1);
    assert.equal(registered.body.credentials[0].label, 'YubiKey 5');

    const account = await client.get('/api/account').expect(200);
    assert.equal(account.body.securityKeys.length, 1);
    await client.post('/api/auth/logout').expect(200);

    const signedOut = agent(app);
    const login = await signInWithSecurityKey(signedOut, authenticator, {
      userHandle: user.userId,
    });
    assert.equal(login.statusCode, 200);
    assert.equal(login.body.success, true);
    assert.equal(login.body.user.username, user.username);
    const me = await signedOut.get('/api/auth/me').expect(200);
    assert.equal(me.body.user.username, user.username);

    const keyId = account.body.securityKeys[0].id;
    const renamed = await signedOut
      .put(`/api/account/security-keys/${keyId}`)
      .send({ label: 'Backup key' })
      .expect(200);
    assert.equal(renamed.body.credentials[0].label, 'Backup key');
    assert.ok(renamed.body.credentials[0].lastUsedAt);

    const removed = await signedOut.delete(`/api/account/security-keys/${keyId}`).expect(200);
    assert.equal(removed.body.credentials.length, 0);
  });

  test('a user-verifying key skips the 2FA challenge', async () => {
    const user = await createTestUser(ctx.db, { username: 'webauthn_uv' });
    const authenticator = createVirtualAuthenticator({ userVerified: true });
    const client = agent(app);
    await loginAs(client, user);
    await registerSecurityKey(client, authenticator, 'Verified key');
    await client.post('/api/auth/logout').expect(200);
    enableTwoFactor(user.userId);

    const login = await signInWithSecurityKey(agent(app), authenticator, {
      userHandle: user.userId,
    });
    assert.equal(login.statusCode, 200);
    assert.equal(login.body.success, true);
    assert.equal(login.body.requiresTwoFactor, undefined);
  });

  test('a presence-only key still has to pass 2FA', async () => {
    const user = await createTestUser(ctx.db, { username: 'webauthn_presence_only' });
    const authenticator = createVirtualAuthenticator({ userVerified: false });
    const client = agent(app);
    await loginAs(client, user);
    await registerSecurityKey(client, authenticator, 'Presence key');
    await client.post('/api/auth/logout').expect(200);
    enableTwoFactor(user.userId);

    const signedOut = agent(app);
    const login = await signInWithSecurityKey(signedOut, authenticator, {
      userHandle: user.userId,
    });
    assert.equal(login.statusCode, 200);
    assert.equal(login.body.success, false);
    assert.equal(login.body.requiresTwoFactor, true);
    await signedOut.get('/api/auth/me').expect(401);
  });

  test('rejects unknown keys, replayed challenges, and mismatched user handles', async () => {
    const user = await createTestUser(ctx.db, { username: 'webauthn_rejects' });
    const other = await createTestUser(ctx.db, { username: 'webauthn_other' });
    const authenticator = createVirtualAuthenticator();
    const unregistered = createVirtualAuthenticator();
    const client = agent(app);
    await loginAs(client, user);
    await registerSecurityKey(client, authenticator, 'Main key');
    await client.post('/api/auth/logout').expect(200);

    const unknown = await signInWithSecurityKey(agent(app), unregistered);
    assert.equal(unknown.statusCode, 401);

    const wrongHandle = await signInWithSecurityKey(agent(app), authenticator, {
      userHandle: other.userId,
    });
    assert.equal(wrongHandle.statusCode, 401);

    const replayClient = agent(app);
    const optionsRes = await replayClient
      .post('/api/auth/webauthn/login/options')
      .set('Origin', ORIGIN)
      .send({})
      .expect(200);
    const assertion = authenticator.authenticate({
      options: optionsRes.body.options,
      origin: ORIGIN,
    });
    await replayClient
      .post('/api/auth/webauthn/login/verify')
      .set('Origin', ORIGIN)
      .send({ response: assertion })
      .expect(200);
    const replayed = await replayClient
      .post('/api/auth/webauthn/login/verify')
      .set('Origin', ORIGIN)
      .send({ response: assertion });
    assert.equal(replayed.statusCode, 400);
  });

  test('security key endpoints require a session', async () => {
    await request(app).get('/api/account/security-keys').expect(401);
    await request(app).post('/api/account/security-keys/register/options').expect(401);
  });
});
