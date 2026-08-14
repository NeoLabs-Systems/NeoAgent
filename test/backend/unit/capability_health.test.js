'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  getAndroidHealth,
  getBrowserHealth,
  getFileHealth,
} = require('../../../server/services/ai/capabilityHealth');

test('browser capability health never starts or resolves a browser runtime', async () => {
  let providerResolutions = 0;
  const runtimeManager = {
    getSettings: () => ({ computer_backend: 'cloud' }),
    getCapabilitySnapshot: () => ({
      browser: {
        activeBackend: 'cloud-computer',
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

test('file capability health names the attached Cowork folder', () => {
  const app = { locals: { workspaceManager: {} } };
  const selected = getFileHealth(app, {}, {
    triggerSource: 'cowork',
    workspaceRoot: '/Users/neo/Projects/Neotastisch-Portfolio',
  });
  assert.match(selected.summary, /Neotastisch-Portfolio/);
  assert.match(selected.summary, /already mounted/);

  const defaultCowork = getFileHealth(app, {}, { triggerSource: 'cowork' });
  assert.match(defaultCowork.summary, /already attached/);

  const web = getFileHealth(app, {}, { triggerSource: 'web' });
  assert.equal(web.summary, 'Per-user workspace access is available.');

  const legacy = getFileHealth(app, {});
  assert.equal(legacy.summary, 'Per-user workspace access is available.');
});
