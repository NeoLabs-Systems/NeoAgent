'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const express = require('express');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');
const {
  GENERIC_ERROR_MESSAGE,
  looksTechnical,
  nonAdminErrorMessage,
  redactResponseBody,
} = require('../../server/utils/public_error');
const { publicErrorCode } = require('../../server/utils/http_error');

const RAW = 'SqliteError: no such table: secrets at /Users/x/app/db.js:3';

test('messages written for people are not treated as technical', () => {
  for (const text of [
    'Please enter a task name.',
    'Agent not found.',
    'Rate limit exceeded for agent:run. Retry in 3s.',
    'Password is too weak: add a number.',
    'Configure at least one provider first.',
    'Invalid API key.',
  ]) {
    assert.equal(looksTechnical(text), false, text);
  }
});

test('exception text, paths, codes and payloads are technical', () => {
  for (const text of [
    RAW,
    'TypeError: x is not a function',
    'connect ECONNREFUSED 127.0.0.1:5432',
    '400 invalid_request_error: bad schema',
    'Upstream responded with HTTP 502',
    '{"error":"boom"}',
    'first line\nsecond line',
    'failed reading [path]',
    'x'.repeat(301),
  ]) {
    assert.equal(looksTechnical(text), true, text);
  }
});

test('non-admin text keeps written messages only', () => {
  const written = Object.assign(new Error('That name is taken.'), { status: 409 });
  const coded = Object.assign(new Error('No computer slots left.'), { code: 'COMPUTER_CAPACITY' });
  assert.equal(nonAdminErrorMessage(written), 'That name is taken.');
  assert.equal(nonAdminErrorMessage(coded), 'No computer slots left.');
  assert.equal(nonAdminErrorMessage(new Error('Model overloaded on upstream')), GENERIC_ERROR_MESSAGE);
  assert.equal(nonAdminErrorMessage(Object.assign(new Error(RAW), { status: 400 })), GENERIC_ERROR_MESSAGE);
  assert.equal(nonAdminErrorMessage('The line dropped.'), 'The line dropped.');
  assert.equal(nonAdminErrorMessage(null), GENERIC_ERROR_MESSAGE);
});

test('system error codes are not public, product codes are', () => {
  assert.equal(publicErrorCode({ code: 'ENOENT' }), undefined);
  assert.equal(publicErrorCode({ code: 'SQLITE_BUSY' }), undefined);
  assert.equal(publicErrorCode({ code: 'ERR_INVALID_URL' }), undefined);
  assert.equal(publicErrorCode({ code: 'EMAIL_TAKEN' }), 'EMAIL_TAKEN');
});

test('response bodies are redacted without touching other data', () => {
  const body = {
    error: 'Please pick a name.',
    items: [{ name: 'a', last_error: RAW }, { name: 'b', lastError: 'Sign in again.' }],
    when: new Date(0),
  };
  const redacted = redactResponseBody(body, 400);
  assert.equal(redacted.error, 'Please pick a name.');
  assert.equal(redacted.items[0].last_error, GENERIC_ERROR_MESSAGE);
  assert.equal(redacted.items[1].lastError, 'Sign in again.');
  assert.equal(redacted.when, body.when);
  assert.equal(body.items[0].last_error, RAW, 'the original stays intact');

  const failure = redactResponseBody({ error: 'Plain words', message: RAW, code: 'COMPUTER_CAPACITY' }, 503);
  assert.deepEqual(failure, { error: GENERIC_ERROR_MESSAGE, code: 'COMPUTER_CAPACITY' });
});

let ctx;
let app;
let admin;
let member;

before(async () => {
  ctx = createTestRuntime();
  admin = await createTestUser(ctx.db, { username: 'visibility_admin' });
  member = await createTestUser(ctx.db, { username: 'visibility_member' });
  ({ app } = createTestApp());
  const failing = express.Router();
  failing.get('/boom', (req, res) => res.status(500).json({ error: RAW }));
  failing.get('/thrown', () => { throw new Error(RAW); });
  app.use('/api/__test', failing);
  app.use((err, req, res, next) => res.status(500).json({ error: err.message }));
});

after(() => teardownTestRuntime(ctx));

test('a 500 reaches admins with its cause and everyone else without', async () => {
  const anonymous = await agent(app).get('/api/__test/boom');
  assert.equal(anonymous.statusCode, 500);
  assert.equal(anonymous.body.error, GENERIC_ERROR_MESSAGE);

  const memberAgent = agent(app);
  await loginAs(memberAgent, member);
  const seenByMember = await memberAgent.get('/api/__test/boom');
  assert.equal(seenByMember.body.error, GENERIC_ERROR_MESSAGE);

  const thrown = await memberAgent.get('/api/__test/thrown');
  assert.equal(thrown.body.error, GENERIC_ERROR_MESSAGE);

  const adminAgent = agent(app);
  await loginAs(adminAgent, admin);
  const seenByAdmin = await adminAgent.get('/api/__test/boom');
  assert.equal(seenByAdmin.body.error, RAW);
});

test('another spelling of the API prefix cannot skip the API protections', async () => {
  const memberAgent = agent(app);
  await loginAs(memberAgent, member);
  for (const url of ['/API/__test/boom', '/Api/__test/boom', '/aPI/__test/thrown']) {
    const response = await memberAgent.get(url);
    assert.equal(response.statusCode, 404, url);
    assert.doesNotMatch(JSON.stringify(response.body), /SqliteError/, url);
  }

  const crossSite = await memberAgent.post('/API/__test/boom').set('Origin', 'https://evil.example');
  assert.equal(crossSite.statusCode, 404);
});

test('stored run failures are hidden from non-admins and kept for admins', async () => {
  const { resolveAgentId } = require('../../server/services/agents/manager');
  const insertRun = (user, id) => {
    ctx.db.prepare(`INSERT INTO agent_runs (id, user_id, agent_id, title, status, error)
      VALUES (?, ?, ?, 'Run', 'failed', ?)`).run(id, user.userId, resolveAgentId(user.userId), RAW);
  };
  insertRun(member, 'run-member');
  insertRun(admin, 'run-admin');

  const memberAgent = agent(app);
  await loginAs(memberAgent, member);
  const memberList = await memberAgent.get('/api/agents');
  assert.equal(memberList.body.runs[0].error, GENERIC_ERROR_MESSAGE);
  const memberDetail = await memberAgent.get('/api/agents/run-member/steps');
  assert.equal(memberDetail.body.run.error, GENERIC_ERROR_MESSAGE);

  const adminAgent = agent(app);
  await loginAs(adminAgent, admin);
  const adminDetail = await adminAgent.get('/api/agents/run-admin/steps');
  assert.equal(adminDetail.body.run.error, RAW);
});
