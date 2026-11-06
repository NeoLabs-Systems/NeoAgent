'use strict';

const assert = require('node:assert/strict');
const { after, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const runtime = createTestRuntime();
after(() => teardownTestRuntime(runtime));

const { MessagingManager } = require('../../../server/services/messaging/manager');
const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');

// Only the lookup is under test: the routes are stand-ins for connected platforms.
function managerWith(routes) {
  const manager = Object.create(MessagingManager.prototype);
  manager.platforms = new Map(routes);
  return manager;
}

test('only a verified chat counts as the owner\'s own, on any platform', async () => {
  const user = await createTestUser(runtime.db, { username: 'owner_routes' });
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const agentId = resolveAgentId(user.userId, null);
  const key = (platform) => `${user.userId}:${agentId}:${platform}`;
  runtime.db.prepare(
    `INSERT INTO messaging_identity_links (platform, external_id, chat_id, user_id, agent_id) VALUES ('telegram', 'tg-7', 'dm-7', ?, ?)`,
  ).run(user.userId, agentId);

  const manager = managerWith([
    [key('telegram'), { isSharedRoute: true }],
    [key('discord'), { isSharedRoute: true }],
    [key('slack'), {}],
    [key('signal'), { ownerChatId: () => 'self-signal' }],
  ]);
  assert.equal(manager.ownerDestination(user.userId, null, 'telegram'), 'dm-7', 'a link made from the owner\'s own chat');
  assert.equal(manager.ownerDestination(user.userId, null, 'discord'), null, 'a shared bot nobody linked');
  assert.equal(manager.ownerDestination(user.userId, null, 'slack'), null, 'a connection that cannot tell which chat is the owner\'s');
  assert.equal(manager.ownerDestination(user.userId, null, 'signal'), 'self-signal');
  assert.equal(manager.ownerDestination(user.userId, null, 'matrix'), null, 'not connected');
});

test('a WhatsApp number is the owner\'s only in self-chat mode', () => {
  const connection = Object.create(WhatsAppPlatform.prototype);
  connection.sock = { user: { id: '491700000000:12@s.whatsapp.net', lid: '212000000000@lid' } };
  connection.selfChatMode = false;
  assert.equal(connection.ownerChatId(), null, 'it may be the agent\'s own number');
  connection.selfChatMode = true;
  assert.match(connection.ownerChatId(), /^491700000000@s\.whatsapp\.net$/);
});
