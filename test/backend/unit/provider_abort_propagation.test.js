'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { AnthropicProvider } = require('../../../server/services/ai/providers/anthropic');
const { GithubCopilotProvider } = require('../../../server/services/ai/providers/githubCopilot');
const { GoogleProvider } = require('../../../server/services/ai/providers/google');
const { GrokProvider } = require('../../../server/services/ai/providers/grok');
const {
  refreshGrokOAuthAccessToken,
} = require('../../../server/services/ai/providers/grokOauth');
const { NvidiaProvider } = require('../../../server/services/ai/providers/nvidia');
const { OllamaProvider } = require('../../../server/services/ai/providers/ollama');
const { OpenAIProvider } = require('../../../server/services/ai/providers/openai');
const { OpenAICodexProvider } = require('../../../server/services/ai/providers/openaiCodex');
const { OpenRouterProvider } = require('../../../server/services/ai/providers/openrouter');
const {
  refreshClaudeCodeAccessToken,
} = require('../../../server/services/ai/providers/claudeCode');

function waitForAbort(signal) {
  return new Promise((_, reject) => {
    const rejectAbort = () => {
      const error = signal.reason instanceof Error ? signal.reason : new Error('provider aborted');
      error.name = 'AbortError';
      reject(error);
    };
    if (signal.aborted) rejectAbort();
    else signal.addEventListener('abort', rejectAbort, { once: true });
  });
}

function openAIStyleProvider(Provider) {
  const provider = new Provider({ apiKey: 'test-key' });
  let capturedSignal;
  provider.client = {
    chat: {
      completions: {
        create(_params, options) {
          capturedSignal = options.signal;
          return waitForAbort(capturedSignal);
        },
      },
    },
  };
  return { provider, getSignal: () => capturedSignal };
}

function anthropicProvider() {
  const provider = new AnthropicProvider({ apiKey: 'test-key' });
  let capturedSignal;
  const capture = (_params, options) => {
    capturedSignal = options.signal;
    return waitForAbort(capturedSignal);
  };
  provider.client = { messages: { create: capture, stream: capture } };
  return { provider, getSignal: () => capturedSignal };
}

function googleProvider() {
  const provider = new GoogleProvider({ apiKey: 'test-key' });
  let capturedSignal;
  const capture = (request) => {
    capturedSignal = request.config.abortSignal;
    return waitForAbort(capturedSignal);
  };
  provider.genAI = {
    models: {
      generateContent: capture,
      generateContentStream: capture,
    },
  };
  return { provider, getSignal: () => capturedSignal };
}

function codexProvider() {
  const provider = new OpenAICodexProvider({ apiKey: 'test-key' });
  let capturedSignal;
  provider.client = {
    responses: {
      create(_params, options) {
        capturedSignal = options.signal;
        return waitForAbort(capturedSignal);
      },
    },
  };
  return { provider, getSignal: () => capturedSignal };
}

async function assertProviderOperationAborts(factory, mode) {
  const { provider, getSignal } = factory();
  const controller = new AbortController();
  const options = { model: 'test-model', signal: controller.signal };
  const messages = [{ role: 'user', content: 'Hello' }];
  const pending = mode === 'chat'
    ? provider.chat(messages, [], options)
    : provider.stream(messages, [], options).next();

  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(getSignal(), controller.signal);
  controller.abort(new Error('provider aborted'));
  await assert.rejects(pending, /provider aborted/);
}

test('chat and stream providers forward the run AbortSignal', async (t) => {
  const providers = [
    ['anthropic', anthropicProvider],
    ['google', googleProvider],
    ['grok', () => openAIStyleProvider(GrokProvider)],
    ['nvidia', () => openAIStyleProvider(NvidiaProvider)],
    ['openai', () => openAIStyleProvider(OpenAIProvider)],
    ['openai-codex', codexProvider],
    ['openrouter', () => openAIStyleProvider(OpenRouterProvider)],
  ];

  for (const [name, factory] of providers) {
    await t.test(name, async () => {
      await assertProviderOperationAborts(factory, 'chat');
      await assertProviderOperationAborts(factory, 'stream');
    });
  }
});

test('Ollama model discovery and pulls stop when the run is aborted', async () => {
  const originalFetch = global.fetch;
  const provider = new OllamaProvider({ baseUrl: 'http://ollama.test' });
  const controller = new AbortController();
  let calls = 0;
  let pullSignal;

  global.fetch = async (_url, options) => {
    calls += 1;
    if (calls === 1) return { json: async () => ({ models: [] }) };
    pullSignal = options.signal;
    return waitForAbort(pullSignal);
  };

  try {
    const pending = provider.ensureModel('missing-model', controller.signal);
    await new Promise((resolve) => setImmediate(resolve));
    assert.ok(pullSignal);
    assert.equal(pullSignal.aborted, false);
    controller.abort(new Error('ollama aborted'));
    await assert.rejects(pending, /ollama aborted/);
    assert.equal(pullSignal.aborted, true);
  } finally {
    global.fetch = originalFetch;
  }
});

test('OAuth provider token refreshes forward the run AbortSignal', async () => {
  for (const refresh of [refreshClaudeCodeAccessToken, refreshGrokOAuthAccessToken]) {
    const controller = new AbortController();
    let capturedSignal;
    const fetchImpl = (_url, options) => {
      capturedSignal = options.signal;
      return waitForAbort(capturedSignal);
    };
    const pending = refresh('refresh-token', fetchImpl, controller.signal);
    await new Promise((resolve) => setImmediate(resolve));
    assert.ok(capturedSignal);
    assert.notEqual(capturedSignal, controller.signal);
    controller.abort(new Error('oauth refresh aborted'));
    await assert.rejects(pending, /oauth refresh aborted/);
    assert.equal(capturedSignal.aborted, true);
  }
});

test('OAuth provider token refresh responses are size bounded', async () => {
  const oversizedBody = 'x'.repeat(300 * 1024);
  const fetchImpl = async () => new Response(oversizedBody, { status: 200 });

  for (const refresh of [refreshClaudeCodeAccessToken, refreshGrokOAuthAccessToken]) {
    await assert.rejects(
      refresh('refresh-token', fetchImpl),
      (error) => error.code === 'PROVIDER_OAUTH_RESPONSE_TOO_LARGE',
    );
  }
});

test('GitHub Copilot caller can stop waiting without cancelling shared refresh', async () => {
  const originalFetch = global.fetch;
  const provider = new GithubCopilotProvider({ apiKey: 'test-key' });
  const controller = new AbortController();
  let capturedSignal;
  let resolveFetch;

  global.fetch = (_url, options) => {
    capturedSignal = options.signal;
    return new Promise((resolve) => {
      resolveFetch = resolve;
    });
  };

  try {
    const pending = provider._refreshCopilotToken(controller.signal);
    await new Promise((resolve) => setImmediate(resolve));
    assert.ok(capturedSignal);
    assert.notEqual(capturedSignal, controller.signal);
    controller.abort(new Error('copilot refresh aborted'));
    await assert.rejects(pending, /copilot refresh aborted/);
    assert.equal(capturedSignal.aborted, false);
    resolveFetch(new Response(JSON.stringify({
      token: 'shared-token',
      expires_at: Math.floor(Date.now() / 1000) + 1800,
    }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    }));
    await provider._refreshPromise;
  } finally {
    global.fetch = originalFetch;
  }
});
