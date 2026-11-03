'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const manualTask = (taskConfig) => ({
  name: 'Report',
  triggerType: 'manual',
  triggerConfig: {},
  prompt: 'Report back.',
  enabled: false,
  taskConfig,
});

describe('task destinations on a shared account', () => {
  let ctx;
  let user;
  let agentId;
  let runtime;
  let store;
  let targets;

  function linkTelegram(senderId = '555', forAgent = agentId) {
    const { code } = store.createLinkCode('telegram', user.userId, forAgent);
    store.redeemLinkCode('telegram', code, {
      externalId: senderId,
      chatId: `dm_${senderId}`,
      displayName: 'Sam',
    });
  }

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db);
    const { resolveAgentId } = require('../../../server/services/agents/manager');
    const { TaskRuntime } = require('../../../server/services/tasks/runtime');
    const { TaskDeliveryTargetService } = require('../../../server/services/tasks/delivery_targets');
    store = require('../../../server/services/messaging/shared_store');
    agentId = resolveAgentId(user.userId, null);
    runtime = new TaskRuntime(null, null, null);
    targets = new TaskDeliveryTargetService({ app: { locals: {} } });
  });

  afterEach(() => teardownTestRuntime(ctx));

  test('a task can report to the owner\'s own chat, in any form of its id', async () => {
    linkTelegram();
    for (const to of ['dm_555', '555']) {
      const task = await runtime.createTask(user.userId, {
        ...manualTask({ notifyPlatform: 'telegram', notifyTo: to }),
        agentId,
      });
      assert.equal(task.taskConfig.notifyTo, to);
    }
  });

  test('a new task cannot name anyone else', async () => {
    linkTelegram();
    await assert.rejects(
      runtime.createTask(user.userId, {
        ...manualTask({ notifyPlatform: 'telegram', notifyTo: 'dm_777' }),
        agentId,
      }),
      /can only deliver to your own chat/,
    );
    assert.equal(runtime.listTasks(user.userId, { agentId }).length, 0);
  });

  test('an existing task cannot be pointed at anyone else', async () => {
    linkTelegram();
    const task = await runtime.createTask(user.userId, { ...manualTask({}), agentId });
    await assert.rejects(
      runtime.updateTask(task.id, user.userId, {
        taskConfig: { notifyPlatform: 'telegram', notifyTo: 'dm_777' },
      }),
      /can only deliver to your own chat/,
    );
  });

  test('a personal connection can still name anyone', async () => {
    const task = await runtime.createTask(user.userId, {
      ...manualTask({ notifyPlatform: 'telegram', notifyTo: 'dm_777' }),
      agentId,
    });
    assert.equal(task.taskConfig.notifyTo, 'dm_777');
  });

  test('a shared account on one platform leaves other platforms free', async () => {
    linkTelegram();
    const task = await runtime.createTask(user.userId, {
      ...manualTask({ notifyPlatform: 'whatsapp', notifyTo: '491799999999' }),
      agentId,
    });
    assert.equal(task.taskConfig.notifyTo, '491799999999');
  });

  test('another agent of the same person is not limited by this agent\'s link', async () => {
    const { createAgent } = require('../../../server/services/agents/manager');
    const other = createAgent(user.userId, { displayName: 'Research' }).id;
    linkTelegram();
    const task = await runtime.createTask(user.userId, {
      ...manualTask({ notifyPlatform: 'telegram', notifyTo: 'dm_777' }),
      agentId: other,
    });
    assert.equal(task.taskConfig.notifyTo, 'dm_777');
  });

  describe('a task saved before the switch to a shared account', () => {
    let task;

    beforeEach(async () => {
      task = await runtime.createTask(user.userId, {
        ...manualTask({ notifyPlatform: 'telegram', notifyTo: 'dm_777' }),
        agentId,
      });
      linkTelegram();
    });

    test('shows the owner\'s own chat as its destination', () => {
      const [listed] = runtime.listTasks(user.userId, { agentId });
      assert.equal(listed.taskConfig.notifyPlatform, 'telegram');
      assert.equal(listed.taskConfig.notifyTo, 'dm_555');
    });

    test('reports to the owner\'s own chat when it runs', () => {
      const row = ctx.db.prepare('SELECT * FROM scheduled_tasks WHERE id = ?').get(task.id);
      assert.deepEqual(
        runtime._resolveNotifyTarget(user.userId, agentId, row, JSON.parse(row.task_config), {}),
        { platform: 'telegram', to: 'dm_555' },
      );
    });

    test('can still be renamed, also when the editor resends its config', async () => {
      const renamed = await runtime.updateTask(task.id, user.userId, { name: 'Renamed' });
      assert.equal(renamed.name, 'Renamed');
      const resaved = await runtime.updateTask(task.id, user.userId, {
        name: 'Again',
        prompt: 'Report back.',
        taskConfig: { notifyPlatform: 'telegram', notifyTo: 'dm_777' },
      });
      assert.equal(resaved.name, 'Again');
    });

    test('cannot swap to a different stranger', async () => {
      await assert.rejects(
        runtime.updateTask(task.id, user.userId, {
          taskConfig: { notifyPlatform: 'telegram', notifyTo: 'dm_888' },
        }),
        /can only deliver to your own chat/,
      );
    });

    test('can be set to the default channel or the owner', async () => {
      const toDefault = await runtime.updateTask(task.id, user.userId, {
        prompt: 'Report back.',
        taskConfig: {},
      });
      assert.equal(toDefault.taskConfig.notifyTo, undefined);
      const toOwner = await runtime.updateTask(task.id, user.userId, {
        prompt: 'Report back.',
        taskConfig: { notifyPlatform: 'telegram', notifyTo: 'dm_555' },
      });
      assert.equal(toOwner.taskConfig.notifyTo, 'dm_555');
    });

    test('recovers if the person goes back to their own account', () => {
      store.unlinkIdentity('telegram', user.userId);
      assert.equal(runtime.listTasks(user.userId, { agentId })[0].taskConfig.notifyTo, 'dm_777');
    });
  });

  describe('the destination list', () => {
    function recordChat(platform, chatId, name) {
      ctx.db.prepare(
        'INSERT INTO messages (user_id, agent_id, role, content, platform, platform_chat_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)',
      ).run(user.userId, agentId, 'user', 'hi', platform, chatId, JSON.stringify({ senderName: name }));
    }

    function saveDefault(platform, chatId) {
      const insert = ctx.db.prepare('INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)');
      insert.run(user.userId, agentId, 'last_platform', JSON.stringify(platform));
      insert.run(user.userId, agentId, 'last_chat_id', JSON.stringify(chatId));
    }

    test('offers only the owner\'s chat on the shared platform', async () => {
      recordChat('telegram', 'dm_777', 'Old contact');
      recordChat('telegram', '-900', 'Old group');
      saveDefault('telegram', 'dm_777');
      linkTelegram();
      const list = await targets.listTargets(user.userId, { agentId });
      assert.deepEqual(list.map((target) => [target.platform, target.to, target.label]), [
        ['telegram', 'dm_555', 'Sam'],
      ]);
    });

    test('leaves other platforms as they were', async () => {
      recordChat('whatsapp', '491799999999@s.whatsapp.net', 'A contact');
      linkTelegram();
      const list = await targets.listTargets(user.userId, { agentId });
      assert.deepEqual(list.map((target) => target.platform).sort(), ['telegram', 'whatsapp']);
    });

    test('respects the platform filter and search', async () => {
      recordChat('whatsapp', '491799999999@s.whatsapp.net', 'A contact');
      linkTelegram();
      const whatsapp = await targets.listTargets(user.userId, { agentId, platform: 'whatsapp' });
      assert.deepEqual(whatsapp.map((target) => target.platform), ['whatsapp']);
      const searched = await targets.listTargets(user.userId, { agentId, q: 'sam' });
      assert.deepEqual(searched.map((target) => target.to), ['dm_555']);
    });

    test('changes nothing without a shared account', async () => {
      recordChat('telegram', 'dm_777', 'A contact');
      const list = await targets.listTargets(user.userId, { agentId });
      assert.deepEqual(list.map((target) => target.to), ['dm_777']);
    });
  });
});
