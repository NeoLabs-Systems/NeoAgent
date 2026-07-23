'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  fetchTriggerRows,
} = require('../../../server/services/tasks/integration_runtime');

test('integration trigger polling forwards caller cancellation to the provider', async () => {
  const controller = new AbortController();
  let executionOptions = null;
  const integrationManager = {
    executeTool(_userId, _toolName, _args, _agentId, options) {
      executionOptions = options;
      return new Promise((_, reject) => {
        options.signal.addEventListener('abort', () => reject(options.signal.reason), {
          once: true,
        });
      });
    },
  };

  const pending = fetchTriggerRows({
    integrationManager,
    userId: null,
    agentId: null,
    triggerType: 'slack_message_received',
    config: { connectionId: 7, channel: 'C123' },
    signal: controller.signal,
  });
  await new Promise((resolve) => setImmediate(resolve));

  const reason = new Error('poller stopped');
  controller.abort(reason);
  await assert.rejects(pending, (error) => error === reason);
  assert.equal(executionOptions.signal, controller.signal);
});
