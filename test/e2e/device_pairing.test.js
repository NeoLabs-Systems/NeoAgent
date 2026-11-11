'use strict';

const crypto = require('crypto');
const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

let ctx;
let app;
let owner;
let other;

function hashCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function expire(code) {
  ctx.db.prepare("UPDATE user_device_pairings SET expires_at = datetime('now', '-1 second') WHERE code_hash = ?")
    .run(hashCode(code));
}

before(async () => {
  ctx = createTestRuntime();
  app = createTestApp().app;
  owner = agent(app);
  other = agent(app);
  await loginAs(owner, await createTestUser(ctx.db, { username: 'pair_owner' }));
  await loginAs(other, await createTestUser(ctx.db, { username: 'pair_other' }));
});

after(() => teardownTestRuntime(ctx));

test('only a signed-in session can create or read pairing codes', async () => {
  await request(app).post('/api/account/pairing').send({}).expect(401);
  await request(app).get('/api/account/pairing/whatever').expect(401);
});

test('a pairing code is long, short-lived and only stored hashed', async () => {
  const { body } = await owner.post('/api/account/pairing').send({}).expect(200);
  const { code, expiresAt, server, qrPayload } = body;
  assert.match(code, /^[A-Za-z0-9_-]{32,}$/);
  const qr = new URL(qrPayload);
  assert.equal(qr.protocol, 'neoagent:');
  assert.equal(qr.host, 'pair');
  assert.equal(qr.searchParams.get('server'), server);
  assert.equal(qr.searchParams.get('code'), code);

  const row = ctx.db.prepare('SELECT * FROM user_device_pairings WHERE code_hash = ?').get(hashCode(code));
  assert.ok(row, 'the hash is stored');
  assert.equal(row.expires_at, expiresAt);
  const lifetime = ctx.db.prepare('SELECT (julianday(expires_at) - julianday(created_at)) * 86400 AS s FROM user_device_pairings WHERE id = ?')
    .get(row.id).s;
  assert.ok(Math.abs(lifetime - 300) < 2, `lives 5 minutes, got ${lifetime}`);

  const status = await owner.get(`/api/account/pairing/${code}`).expect(200);
  assert.deepEqual(status.body, { status: 'pending' });
  await other.get(`/api/account/pairing/${code}`).expect(404);
});

test('the QR carries the public URL with its base path', async () => {
  const config = app.locals.httpRuntimeConfig;
  const previous = config.publicUrl;
  config.publicUrl = 'https://example.com/neo/';
  try {
    const { body } = await owner.post('/api/account/pairing').send({}).expect(200);
    assert.equal(body.server, 'https://example.com/neo');
    assert.equal(new URL(body.qrPayload).searchParams.get('server'), 'https://example.com/neo');
  } finally {
    config.publicUrl = previous;
  }
});

test('redeeming signs the phone in once and tells the screen which phone', async () => {
  const { body: start } = await owner.post('/api/account/pairing').send({}).expect(200);
  const phone = agent(app);

  const res = await phone.post('/api/auth/pair').send({ code: start.code, name: 'Pixel 9' }).expect(200);
  assert.equal(res.body.user.username, 'pair_owner');
  const me = await phone.get('/api/auth/me').expect(200);
  assert.equal(me.body.user.username, 'pair_owner');

  const status = await owner.get(`/api/account/pairing/${start.code}`).expect(200);
  assert.deepEqual(status.body, { status: 'used', device: { name: 'Pixel 9' } });

  const again = await agent(app).post('/api/auth/pair').send({ code: start.code, name: 'Thief' }).expect(410);
  assert.equal(again.body.code, 'EXPIRED_TOKEN');
});

test('expired and unknown codes are refused the same way', async () => {
  const { body: start } = await owner.post('/api/account/pairing').send({}).expect(200);
  expire(start.code);
  const status = await owner.get(`/api/account/pairing/${start.code}`).expect(200);
  assert.equal(status.body.status, 'expired');
  const expired = await request(app).post('/api/auth/pair').send({ code: start.code }).expect(410);
  assert.equal(expired.body.code, 'EXPIRED_TOKEN');
  await request(app).post('/api/auth/pair').send({ code: 'x'.repeat(43) }).expect(410);
  await request(app).post('/api/auth/pair').send({}).expect(410);
});

test('an account can only hold a few open codes at once', async () => {
  ctx.db.prepare('DELETE FROM user_device_pairings').run();
  for (let i = 0; i < 5; i += 1) {
    await other.post('/api/account/pairing').send({}).expect(200);
  }
  const res = await other.post('/api/account/pairing').send({}).expect(429);
  assert.equal(res.body.code, 'TOO_MANY_PAIRING_CODES');
});
