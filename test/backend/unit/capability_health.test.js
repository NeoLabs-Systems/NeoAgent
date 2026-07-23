'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  getAndroidHealth,
  getBrowserHealth,
} = require('../../../server/services/ai/capabilityHealth');

test('browser capability health never starts or resolves a browser runtime', async () => {
  let providerResolutions = 0;
  const runtimeManager = {
    getSettings: () => ({ browser_backend: 'vm' }),
    getCapabilitySnapshot: () => ({
      browser: {
        preferredBackend: 'vm',
        extensionConnected: false,
        vmInitialized: false,
      },
    }),
    async getBrowserProviderForUser() {
      providerResolutions += 1;
      throw new Error('browser provider must stay lazy');
    },
  };

  const health = await getBrowserHealth(
    7,
    { locals: { runtimeManager } },
    {},
  );

  assert.equal(providerResolutions, 0);
  assert.equal(health.configured, true);
  assert.equal(health.healthy, true);
  assert.equal(health.connected, false);
  assert.match(health.summary, /start on first use/i);
});

test('Android capability health uses a synchronous snapshot without adb or controller creation', async () => {
  let providerResolutions = 0;
  const runtimeManager = {
    getCapabilitySnapshot: () => ({
      android: {
        initialized: false,
        status: null,
      },
    }),
    async getAndroidProviderForUser() {
      providerResolutions += 1;
      throw new Error('Android provider must stay lazy');
    },
  };

  const health = await getAndroidHealth(
    7,
    { locals: { runtimeManager } },
    {},
  );

  assert.equal(providerResolutions, 0);
  assert.equal(health.configured, true);
  assert.equal(health.healthy, true);
  assert.equal(health.connected, false);
  assert.match(health.summary, /first use/i);
});
