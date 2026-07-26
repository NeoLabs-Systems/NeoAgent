'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { runProcess } = require('../../../server/services/android/process');

test('Android subprocess runner captures successful output', async () => {
  const result = await runProcess(process.execPath, ['-e', 'process.stdout.write("ready")']);

  assert.equal(result.exitCode, 0);
  assert.equal(result.stdout, 'ready');
  assert.equal(result.stderr, '');
});

test('Android subprocess runner terminates commands at the deadline', async () => {
  await assert.rejects(
    runProcess(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], { timeoutMs: 100 }),
    (error) => error.code === 'PROCESS_TIMEOUT' && error.timeoutMs === 100,
  );
});

test('Android subprocess runner bounds command output', async () => {
  await assert.rejects(
    runProcess(
      process.execPath,
      ['-e', 'process.stdout.write("x".repeat(4096))'],
      { maxOutputBytes: 1024 },
    ),
    (error) => error.code === 'PROCESS_OUTPUT_LIMIT',
  );
});

test('Android subprocess runner forwards cancellation', async () => {
  const controller = new AbortController();
  const command = runProcess(
    process.execPath,
    ['-e', 'setInterval(() => {}, 1000)'],
    { signal: controller.signal, timeoutMs: 5000 },
  );
  const reason = new Error('stop Android subprocess');
  controller.abort(reason);

  await assert.rejects(command, (error) => error === reason);
});
