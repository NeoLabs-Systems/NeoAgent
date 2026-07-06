'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

describe('task delivery target discovery', () => {
  let ctx;
  let user;
  let otherUser;
  let agentId;
  let otherAgentId;
  let TaskDeliveryTargetService;
  let createAgent;
  let resolveAgentId;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db);
    otherUser = await createTestUser(ctx.db);
    ({ resolveAgentId, createAgent } = require('../../../server/services/agents/manager'));
    agentId = resolveAgentId(user.userId, null);
    otherAgentId = createAgent(user.userId, { displayName: 'Research' }).id;
    ({ TaskDeliveryTargetService } = require('../../../server/services/tasks/delivery_targets'));
  });

  afterEach(() => {
    teardownTestRuntime(ctx);
  });

  function serviceWith(locals = {}) {
    return new TaskDeliveryTargetService({ app: { locals } });
  }

  test('returns live platform discovery before default and recent targets', async () => {
    const messagingManager = {
      async listAccessTargets(userId, platform, options) {
        assert.equal(userId, user.userId);
        assert.equal(platform, 'whatsapp');
        assert.equal(options.agentId, agentId);
        return [
          {
            source: 'live',
            scope: 'group',
            value: 'family@g.us',
            label: 'Family',
            subtitle: 'WhatsApp group',
          },
        ];
      },
    };

    ctx.db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, 'last_platform', ?), (?, ?, 'last_chat_id', ?)`
    ).run(
      user.userId,
      agentId,
      JSON.stringify('whatsapp'),
      user.userId,
      agentId,
      JSON.stringify('default@g.us'),
    );
    ctx.db.prepare(
      `INSERT INTO messages (user_id, agent_id, role, content, platform, platform_chat_id, metadata)
       VALUES (?, ?, 'user', 'hello', 'whatsapp', 'recent@g.us', ?)`
    ).run(user.userId, agentId, JSON.stringify({ groupName: 'Recent group' }));

    const targets = await serviceWith({ messagingManager }).listTargets(user.userId, { agentId });

    assert.equal(targets[0].source, 'discovered');
    assert.equal(targets[0].to, 'family@g.us');
    assert.deepEqual(
      targets.map((target) => `${target.source}:${target.platform}:${target.to}`),
      [
        'discovered:whatsapp:family@g.us',
        'default:whatsapp:default@g.us',
        'recent:whatsapp:recent@g.us',
      ],
    );
  });

  test('discovers Slack conversations through the integration manager', async () => {
    const integrationManager = {
      async executeTool(userId, toolName, args, scopedAgentId) {
        assert.equal(userId, user.userId);
        assert.equal(scopedAgentId, agentId);
        assert.equal(toolName, 'slack_list_conversations');
        assert.equal(args.types, 'public_channel,private_channel,im,mpim');
        return {
          result: {
            channels: [
              { id: 'C123', name: 'ops', is_private: false },
              { id: 'D123', user: 'U123', is_im: true },
            ],
          },
        };
      },
    };

    const targets = await serviceWith({ integrationManager }).listTargets(user.userId, {
      agentId,
      platform: 'slack',
      q: 'ops',
    });

    assert.equal(targets.length, 1);
    assert.equal(targets[0].platform, 'slack');
    assert.equal(targets[0].to, 'C123');
    assert.equal(targets[0].label, '#ops');
    assert.equal(targets[0].source, 'discovered');
  });

  test('filters by agent and user scope', async () => {
    ctx.db.prepare(
      `INSERT INTO messages (user_id, agent_id, role, content, platform, platform_chat_id, metadata)
       VALUES (?, ?, 'user', 'a', 'discord', 'agent-channel', ?),
              (?, ?, 'user', 'b', 'discord', 'other-agent-channel', ?),
              (?, ?, 'user', 'c', 'discord', 'other-user-channel', ?)`
    ).run(
      user.userId,
      agentId,
      JSON.stringify({ channelName: 'Agent channel' }),
      user.userId,
      otherAgentId,
      JSON.stringify({ channelName: 'Other agent channel' }),
      otherUser.userId,
      agentId,
      JSON.stringify({ channelName: 'Other user channel' }),
    );

    const targets = await serviceWith().listTargets(user.userId, {
      agentId,
      platform: 'discord',
    });

    assert.deepEqual(targets.map((target) => target.to), ['agent-channel']);
  });
});
