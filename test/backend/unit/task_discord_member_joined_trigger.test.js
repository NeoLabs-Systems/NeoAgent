'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { test } = require('node:test');

const discordMemberJoined = require('../../../server/services/tasks/adapters/discord_member_joined');
const { attachIntegrationEventSources } = require('../../../server/services/tasks/integration_runtime');

const GUILD_ID = '123456789012345678';

test('discord member joined trigger requires a server ID', async () => {
  assert.deepEqual(await discordMemberJoined.validateConfig({ guild_id: ` ${GUILD_ID} ` }), { guildId: GUILD_ID });
  await assert.rejects(discordMemberJoined.validateConfig({}), /server ID/);
  await assert.rejects(discordMemberJoined.validateConfig({ guildId: 'my-server' }), /server ID/);
});

test('discord joins fire only the tasks for that server, one join at a time', async () => {
  const manager = new EventEmitter();
  const fired = [];
  let running = 0;
  const runtime = {
    stopping: false,
    app: { locals: { messagingManager: manager } },
    taskRepository: {
      listEnabledEventTasks(userId, agentId, triggerType) {
        assert.deepEqual([userId, agentId, triggerType], [1, 'main', 'discord_member_joined']);
        return [
          { id: 10, user_id: 1, trigger_config: JSON.stringify({ guildId: GUILD_ID }) },
          { id: 11, user_id: 1, trigger_config: JSON.stringify({ guildId: '999999999999999999' }) },
        ];
      },
    },
    async fireTaskFromTrigger(taskId, userId, payload) {
      running += 1;
      assert.equal(running, 1);
      await new Promise((resolve) => setImmediate(resolve));
      fired.push({ taskId, userId, payload });
      running -= 1;
      return {};
    },
  };

  const cleanups = attachIntegrationEventSources(runtime);
  const join = (memberId) => manager.emit('member_joined', {
    userId: 1,
    agentId: 'main',
    platform: 'discord',
    guildId: GUILD_ID,
    guildName: 'Neo Lab',
    memberId,
    memberUsername: `user${memberId}`,
    memberDisplayName: `User ${memberId}`,
    chatId: `dm_${memberId}`,
    joinedAt: '2026-10-07T10:00:00.000Z',
  });
  join('42');
  join('43');
  await new Promise((resolve) => setTimeout(resolve, 20));

  assert.deepEqual(fired.map((entry) => entry.taskId), [10, 10]);
  assert.equal(fired[0].payload.fingerprint, `discord_member:${GUILD_ID}:42:2026-10-07T10:00:00.000Z`);
  assert.equal(fired[1].payload.context.triggerEvent.dmChatId, 'dm_43');

  for (const cleanup of cleanups) cleanup();
  assert.equal(manager.listenerCount('member_joined'), 0);
});
