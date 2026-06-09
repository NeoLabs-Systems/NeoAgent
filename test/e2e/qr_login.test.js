'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

let ctx;
let app;

before(() => {
  ctx = createTestRuntime();
  app = createTestApp().app;
});

after(() => teardownTestRuntime(ctx));

test('full QR login challenge, approval, claim, and reuse rejection flow', async () => {
  const approverUser = await createTestUser(ctx.db, { username: 'qr_approver' });
  const requester = agent(app);
  const approver = agent(app);
  await loginAs(approver, approverUser);

  const challenge = await requester.post('/api/auth/qr-login/challenge').send({
    requestMetadata: { deviceClass: 'desktop', platformLabel: 'macOS' },
  }).expect(200);
  assert.equal(challenge.body.status, 'pending');
  assert.ok(challenge.body.pollToken);
  assert.ok(challenge.body.qrPayload);
  const parsed = new URL(challenge.body.qrPayload);
  const secret = parsed.searchParams.get('secret');

  const pending = await request(app)
    .post(`/api/auth/qr-login/challenge/${challenge.body.challengeId}/status`)
    .send({ token: challenge.body.pollToken })
    .expect(200);
  assert.equal(pending.body.status, 'pending');

  const preview = await approver.post('/api/account/qr-login/resolve').send({
    challengeId: challenge.body.challengeId,
    secret,
  }).expect(200);
  assert.equal(preview.body.status, 'pending');

  await approver.post('/api/account/qr-login/approve').send({
    challengeId: challenge.body.challengeId,
    secret,
    approvalMetadata: { deviceClass: 'mobile' },
  }).expect(200);

  const approved = await requester
    .post(`/api/auth/qr-login/challenge/${challenge.body.challengeId}/status`)
    .send({ token: challenge.body.pollToken })
    .expect(200);
  assert.equal(approved.body.status, 'approved');

  await requester
    .post(`/api/auth/qr-login/challenge/${challenge.body.challengeId}/claim`)
    .send({ token: challenge.body.pollToken })
    .expect(200);
  await requester.get('/api/auth/me').expect(200);
  await requester
    .post(`/api/auth/qr-login/challenge/${challenge.body.challengeId}/claim`)
    .send({ token: challenge.body.pollToken })
    .expect(409);
});
