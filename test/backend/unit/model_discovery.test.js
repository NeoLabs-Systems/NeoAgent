'use strict';

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const {
  refreshProviderModelList,
} = require('../../../server/services/ai/model_discovery');

let sequence = 0;

function uniqueProviderId(label) {
  sequence += 1;
  return `test-${label}-${process.pid}-${sequence}`;
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, reject, resolve };
}

describe('model discovery', () => {
  test('coalesces concurrent refreshes for the same provider runtime', async () => {
    const pending = deferred();
    let calls = 0;
    class Provider {
      constructor() {
        this.models = [];
      }

      async listModels() {
        calls += 1;
        return pending.promise;
      }
    }

    const params = {
      providerId: uniqueProviderId('coalesce'),
      factory: { Provider, apiKey: true, baseUrl: true },
      apiKey: 'key',
      baseUrl: 'https://example.test/v1',
    };
    const first = refreshProviderModelList(params);
    const second = refreshProviderModelList(params);
    pending.resolve([{ id: 'model-a' }]);

    const [left, right] = await Promise.all([first, second]);
    assert.equal(calls, 1);
    assert.deepEqual(left, right);
    assert.equal(left[0].id, 'model-a');
  });

  test('keys caches by the full credential and base URL identity', async () => {
    let calls = 0;
    class Provider {
      constructor(config) {
        this.config = config;
        this.models = [];
      }

      async listModels() {
        calls += 1;
        return [{ id: `${this.config.apiKey}@${this.config.baseUrl}` }];
      }
    }

    const providerId = uniqueProviderId('keys');
    const factory = { Provider, apiKey: true, baseUrl: true };
    const first = await refreshProviderModelList({
      providerId,
      factory,
      apiKey: 'abcdefgh-one',
      baseUrl: 'https://one.example/v1',
    });
    const second = await refreshProviderModelList({
      providerId,
      factory,
      apiKey: 'abcdefgh-two',
      baseUrl: 'https://two.example/v1',
    });

    assert.equal(calls, 2);
    assert.notEqual(first[0].id, second[0].id);
  });

  test('lets an aborted caller leave a shared refresh without waiting for the provider', async () => {
    const pending = deferred();
    class Provider {
      constructor() {
        this.models = [];
      }

      async listModels() {
        return pending.promise;
      }
    }

    const controller = new AbortController();
    const result = refreshProviderModelList({
      providerId: uniqueProviderId('abort'),
      factory: { Provider, apiKey: false, baseUrl: false },
      signal: controller.signal,
    });
    controller.abort('request closed');

    await assert.rejects(result, (error) => error.name === 'AbortError');
    pending.resolve([{ id: 'eventual-model' }]);
  });

  test('does not synthesize models when live discovery fails', async () => {
    class Provider {
      constructor() {
        this.models = ['curated-a', 'curated-b'];
      }

      async listModels() {
        throw new Error('temporary network failure');
      }
    }

    const models = await refreshProviderModelList({
      providerId: uniqueProviderId('fallback'),
      factory: { Provider, apiKey: false, baseUrl: false },
    });
    assert.deepEqual(models, []);
  });

  test('keeps the release time and tool support the catalog states', async () => {
    class Provider {
      async listModels() {
        return [
          { id: 'unstated-model' },
          { id: 'openai-style', created: 1_780_000_000 },
          { id: 'anthropic-style', created_at: '2026-05-01T00:00:00Z' },
          { id: 'vendor/agent-model', supported_parameters: ['tools', 'temperature'] },
          { id: 'vendor/chat-only', supported_parameters: ['temperature'] },
        ];
      }
    }

    const models = await refreshProviderModelList({
      providerId: uniqueProviderId('metadata'),
      factory: { Provider, apiKey: false, baseUrl: false },
    });
    const byId = new Map(models.map((model) => [model.id, model]));

    assert.equal(byId.get('unstated-model').createdAt, null);
    assert.equal(byId.get('unstated-model').supportsTools, null);
    assert.equal(byId.get('openai-style').createdAt, 1_780_000_000_000);
    assert.equal(byId.get('anthropic-style').createdAt, Date.parse('2026-05-01T00:00:00Z'));
    assert.equal(byId.get('vendor/agent-model').supportsTools, true);
    assert.equal(byId.get('vendor/chat-only').supportsTools, false);
  });
});
