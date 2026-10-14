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
    scannerMetadata: { deviceLabel: 'Android app', deviceClass: 'mobile' },
  }).expect(200);
  assert.equal(preview.body.status, 'pending');

  const scanned = await request(app)
    .post(`/api/auth/qr-login/challenge/${challenge.body.challengeId}/status`)
    .send({ token: challenge.body.pollToken })
    .expect(200);
  assert.equal(scanned.body.status, 'scanned');
  assert.equal(scanned.body.scannedBy.label, 'Android app');
  assert.equal(scanned.body.requestedDevice.label, 'macOS');
  assert.equal(scanned.body.approval, undefined);

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

async function startChallenge(requester) {
  const challenge = await requester.post('/api/auth/qr-login/challenge').send({}).expect(200);
  return {
    id: challenge.body.challengeId,
    pollToken: challenge.body.pollToken,
    secret: new URL(challenge.body.qrPayload).searchParams.get('secret'),
  };
}

test('a phone declining a scanned QR login ends it for the waiting screen', async () => {
  const approverUser = await createTestUser(ctx.db, { username: 'qr_decliner' });
  const approver = agent(app);
  await loginAs(approver, approverUser);
  const challenge = await startChallenge(agent(app));

  await approver.post('/api/account/qr-login/resolve').send({
    challengeId: challenge.id,
    secret: challenge.secret,
  }).expect(200);
  await approver.post('/api/account/qr-login/decline').send({
    challengeId: challenge.id,
    secret: challenge.secret,
  }).expect(200);

  const status = await request(app)
    .post(`/api/auth/qr-login/challenge/${challenge.id}/status`)
    .send({ token: challenge.pollToken })
    .expect(200);
  assert.equal(status.body.status, 'declined');
  await approver.post('/api/account/qr-login/approve').send({
    challengeId: challenge.id,
    secret: challenge.secret,
  }).expect(409);
});

test('the signing-in screen cancelling makes a late approval fail', async () => {
  const approverUser = await createTestUser(ctx.db, { username: 'qr_late' });
  const approver = agent(app);
  await loginAs(approver, approverUser);
  const challenge = await startChallenge(agent(app));

  await request(app)
    .post(`/api/auth/qr-login/challenge/${challenge.id}/cancel`)
    .send({ token: challenge.pollToken })
    .expect(200);
  await approver.post('/api/account/qr-login/resolve').send({
    challengeId: challenge.id,
    secret: challenge.secret,
  }).expect(409);
  await approver.post('/api/account/qr-login/approve').send({
    challengeId: challenge.id,
    secret: challenge.secret,
  }).expect(409);
});

test('a held status check answers as soon as the phone scans', async () => {
  const approverUser = await createTestUser(ctx.db, { username: 'qr_fast' });
  const approver = agent(app);
  await loginAs(approver, approverUser);
  const challenge = await startChallenge(agent(app));

  const started = Date.now();
  const held = request(app)
    .post(`/api/auth/qr-login/challenge/${challenge.id}/status`)
    .send({ token: challenge.pollToken, knownStatus: 'pending' })
    .then((res) => res);
  await new Promise((resolve) => setTimeout(resolve, 150));
  await approver.post('/api/account/qr-login/resolve').send({
    challengeId: challenge.id,
    secret: challenge.secret,
  }).expect(200);

  const status = await held;
  assert.equal(status.status, 200);
  assert.equal(status.body.status, 'scanned');
  assert.equal(status.body.longPoll, true);
  assert.ok(Date.now() - started < 5000);
});
