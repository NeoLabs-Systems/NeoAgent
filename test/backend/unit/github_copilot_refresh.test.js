'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { GithubCopilotProvider } = require('../../../server/services/ai/providers/githubCopilot');

const originalFetch = global.fetch;

afterEach(() => {
  global.fetch = originalFetch;
});

test('Copilot token refresh is shared without letting one caller cancel everyone', async () => {
  let resolveFetch;
  let capturedSignal = null;
  let calls = 0;
  global.fetch = (_url, options) => {
    calls += 1;
    capturedSignal = options.signal;
    return new Promise((resolve) => {
      resolveFetch = resolve;
    });
  };
  const provider = new GithubCopilotProvider({ apiKey: 'github-access-token' });
  const controller = new AbortController();
  const cancelledWaiter = provider._refreshCopilotToken(controller.signal);
  const survivingWaiter = provider._refreshCopilotToken();
  await new Promise((resolve) => setImmediate(resolve));

  const reason = new Error('first run stopped');
  controller.abort(reason);
  await assert.rejects(cancelledWaiter, (error) => error === reason);
  assert.equal(capturedSignal.aborted, false);

  resolveFetch({
    ok: true,
    status: 200,
    headers: { get: () => null },
    text: async () => JSON.stringify({
      token: 'copilot-session-token',
      expires_at: Math.floor(Date.now() / 1000) + 1800,
    }),
  });
  await survivingWaiter;

  assert.equal(calls, 1);
  assert.equal(provider.copilotToken, 'copilot-session-token');
  assert.equal(provider.client.apiKey, 'copilot-session-token');
});
