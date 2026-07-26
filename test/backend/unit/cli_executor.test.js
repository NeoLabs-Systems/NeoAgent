'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { CLIExecutor } = require('../../../server/services/cli/executor');

test('CLI execution never starts with an already-aborted signal', async () => {
  const executor = new CLIExecutor();
  const controller = new AbortController();
  controller.abort('stopped');

  const result = await executor.execute('echo should-not-run', { signal: controller.signal });

  assert.equal(result.aborted, true);
  assert.equal(result.pid, null);
  assert.equal(executor.activeProcesses.size, 0);
});

test('CLI execution terminates the managed process when its run is aborted', async () => {
  const executor = new CLIExecutor();
  const controller = new AbortController();
  const startedAt = Date.now();
  const running = executor.execute('sleep 20', { signal: controller.signal });
  setTimeout(() => controller.abort('stopped'), 50);

  const result = await running;

  assert.equal(result.killed, true);
  assert.equal(result.aborted, true);
  assert.ok(Date.now() - startedAt < 2000);
  assert.equal(executor.activeProcesses.size, 0);
});
