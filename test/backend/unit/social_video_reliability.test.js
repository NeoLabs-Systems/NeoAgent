'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { SocialVideoService } = require('../../../server/services/social_video/service');

test('social video cancellation reaches dependency commands and is not shaped as success', async () => {
  const commandSignals = [];
  const service = new SocialVideoService({
    cliExecutor: {
      execute(_command, options) {
        commandSignals.push(options.signal);
        return new Promise((resolve) => {
          options.signal.addEventListener('abort', () => resolve({
            exitCode: null,
            stdout: '',
            stderr: '',
            aborted: true,
          }), { once: true });
        });
      },
    },
  });
  const controller = new AbortController();
  const reason = new Error('agent run stopped');
  const pending = service.extractFromUrl(
    1,
    'https://www.youtube.com/watch?v=abc123',
    { signal: controller.signal },
  );
  await new Promise((resolve) => setImmediate(resolve));
  controller.abort(reason);

  await assert.rejects(pending, (error) => error === reason);
  assert.equal(commandSignals.length, 2);
  assert.ok(commandSignals.every((signal) => signal === controller.signal));
});
