'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

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
