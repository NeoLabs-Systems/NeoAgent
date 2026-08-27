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
});
