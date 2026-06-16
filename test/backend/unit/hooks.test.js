'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('AgentHooks.run preserves blocking metadata from hooks', async () => {
  const { AgentHooks } = require('../../../server/services/ai/hooks');
  const hooks = new AgentHooks();

  hooks.register('before_tool_call', async () => ({
    block: true,
    reason: 'User denied',
    blocked_by: 'user_denied',
  }));

  const result = await hooks.run('before_tool_call', {});
  assert.deepEqual(result, {
    block: true,
    reason: 'User denied',
    blocked_by: 'user_denied',
  });
});

test('blocked read-only tool results keep hook reason and blocked_by fields', async () => {
  ctx = createTestRuntime();
  const { executeReadOnlyBatch } = require('../../../server/services/ai/loop/tool_dispatch');
  const { globalHooks } = require('../../../server/services/ai/hooks');

  const hookId = globalHooks.register('before_tool_call', async () => ({
    block: true,
    reason: 'Approval timed out',
    blocked_by: 'approval_timeout',
  }), { id: 'test-block-metadata' });

  try {
    const engine = {
      getRunMeta() {
        return { repetitionGuard: { shouldBlock() { return false; } } };
      },
      getStepType() {
        return 'file';
      },
      emit() {},
      recordRunEvent() {},
    };
    const { results } = await executeReadOnlyBatch(
      engine,
      [{
        id: 'toolcall-1',
        function: {
          name: 'read_file',
          arguments: JSON.stringify({ path: 'README.md' }),
        },
      }],
      {
        userId: 1,
        runId: 'run-hook-blocked',
        agentId: null,
        app: null,
        triggerType: 'chat',
        triggerSource: 'web',
        conversationId: 'conv-hook-blocked',
        startingStepIndex: 0,
        options: {},
      },
    );

    assert.equal(results.length, 1);
    assert.deepEqual(results[0].result, {
      status: 'blocked',
      reason: 'Approval timed out',
      blocked_by: 'approval_timeout',
    });
  } finally {
    globalHooks.deregister('before_tool_call', hookId);
  }
});
