'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent, request } = require('../helpers/supertest');

const TOKEN = '123456:abcdefghijklmnopqrstuvwxyz';

describe('shared messaging API', () => {
  let ctx;
  let app;
  let owner;
  let member;
  let store;
  let manager;

  async function signedIn(user) {
    const client = agent(app);
    await loginAs(client, user);
    return client;
  }

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    owner = await createTestUser(ctx.db, { username: 'instance_owner' });
    member = await createTestUser(ctx.db, { username: 'instance_member' });
    store = require('../../server/services/messaging/shared_store');
    const { SharedMessagingConnections } = require('../../server/services/messaging/shared_connections');
    // The adapter itself is covered by the unit tests; here only the row matters.
    manager = {
      platforms: new Map(),
      _key: (userId, agentId, platform) => `${userId}:${agentId}:${platform}`,
    };
    manager.shared = new SharedMessagingConnections(manager);
    manager.shared.reconcile = async () => {};
    app.locals.messagingManager = manager;
  });

  after(() => teardownTestRuntime(ctx));

  test('setting up a shared account needs an admin', async () => {
    await request(app).get('/api/admin/messaging').expect(401);
    const client = await signedIn(member);
    await client.get('/api/admin/messaging').expect(403);
    await client.put('/api/admin/messaging/telegram').send({ botToken: TOKEN }).expect(403);
    await client.delete('/api/admin/messaging/telegram').expect(403);
    assert.equal(store.getConnection('telegram'), null);
  });

  test('admins configure an account and never get the token back', async () => {
    const client = await signedIn(owner);
    const empty = await client.get('/api/admin/messaging').expect(200);
    assert.deepEqual(empty.body.connections.map((item) => item.platform), ['telegram', 'whatsapp']);
    assert.equal(empty.body.connections[0].configured, false);

    await client.put('/api/admin/messaging/telegram').send({ botToken: 'nope' }).expect(400);
    await client.put('/api/admin/messaging/slack').send({}).expect(400);

    const saved = await client.put('/api/admin/messaging/telegram').send({ botToken: TOKEN }).expect(200);
    assert.equal(saved.body.connections[0].configured, true);
    assert.ok(!JSON.stringify(saved.body).includes(TOKEN));
  });

  test('users see only an account that is live, and can link to it', async () => {
    const client = await signedIn(member);
    const hidden = await client.get('/api/messaging/shared').expect(200);
    assert.deepEqual(hidden.body.options, []);
    await client.post('/api/messaging/shared/telegram/link').send({}).expect(409);

    store.updateConnectionState('telegram', {
      status: 'connected',
      accountId: 'shared_bot',
      accountLabel: '@shared_bot',
    });
    const offered = await client.get('/api/messaging/shared').expect(200);
    assert.equal(offered.body.options[0].accountLabel, '@shared_bot');
    assert.equal(offered.body.options[0].personalAllowed, true);
    assert.ok(!JSON.stringify(offered.body).includes(TOKEN));

    const started = await client.post('/api/messaging/shared/telegram/link').send({}).expect(200);
    assert.match(started.body.code, /^NEO-[A-HJ-NP-Z2-9]{10}$/);
    assert.equal(started.body.url, `https://t.me/shared_bot?start=${started.body.code}`);
  });

  test('link routes need a session and a supported platform', async () => {
    await request(app).get('/api/messaging/shared').expect(401);
    await request(app).post('/api/messaging/shared/telegram/link').send({}).expect(401);
    const client = await signedIn(member);
    await client.post('/api/messaging/shared/discord/link').send({}).expect(400);
  });

  test('an unlink only ever affects the signed-in user', async () => {
    const { resolveAgentId } = require('../../server/services/agents/manager');
    const agentId = resolveAgentId(owner.userId, null);
    const { code } = store.createLinkCode('telegram', owner.userId, agentId);
    assert.equal(store.redeemLinkCode('telegram', code, { externalId: '100', chatId: 'dm_100' }).linked, true);

    const client = await signedIn(member);
    const result = await client.delete('/api/messaging/shared/telegram/link').expect(200);
    assert.equal(result.body.status, 'not_configured');
    assert.ok(store.findLinkForUser('telegram', owner.userId));
  });

  test('removing the account takes its links with it', async () => {
    const client = await signedIn(owner);
    const removed = await client.delete('/api/admin/messaging/telegram').expect(200);
    assert.equal(removed.body.connections[0].configured, false);
    assert.equal(store.findLinkForUser('telegram', owner.userId), null);
  });
});
