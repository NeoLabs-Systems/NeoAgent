'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  getAndroidHealth,
  getBrowserHealth,
  getFileHealth,
  summarizeCapabilityHealth,
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

test('browser capability health surfaces the computer lastError when the VM is down', async () => {
  const health = await getBrowserHealth(
    7,
    {
      locals: {
        runtimeManager: {
          getCapabilitySnapshot: () => ({
            computer: {
              state: 'error',
              lastError: 'QEMU exited (1).\ncould not set up host forwarding',
            },
            browser: {
              activeBackend: 'cloud-computer',
              vmInitialized: true,
            },
          }),
        },
      },
    },
    {},
  );

  assert.equal(health.healthy, false);
  assert.match(health.summary, /QEMU exited \(1\)/);
  assert.match(health.summary, /host forwarding/);
});

test('capability summary lists only capabilities that need attention', () => {
  const summary = summarizeCapabilityHealth({
    providers: [{ id: 'openai', healthy: true, configured: true }],
    capabilities: {
      command: { configured: true, healthy: true, summary: 'Shell command execution is available.' },
      search: { configured: false, healthy: false, summary: 'Brave Search API key is not configured.' },
      integrations: { configured: true, healthy: false, summary: 'Google: not connected on this server' },
      browser: { configured: true, healthy: false, summary: 'VM failed to boot.' },
      android: { configured: true, healthy: true, degraded: true, summary: 'adb missing.' },
    },
  });
  assert.equal(summary, 'browser: unhealthy - VM failed to boot.\nandroid: degraded - adb missing.');
});

test('integration notes are served once per run with the tools that need them', () => {
  const { describeIntegrationsForRun } = require('../../../server/services/ai/loop/run_state');
  const requested = [];
  const runMeta = { userId: 1, agentId: 'main' };
  const engine = {
    getRunMeta: () => runMeta,
    app: {
      locals: {
        integrationManager: {
          summarizeConnectedProviders: (userId, agentId, keys) => {
            requested.push(keys);
            return keys.map((key) => `${key} notes`).join('\n');
          },
        },
      },
    },
  };
  const tools = [{ name: 'read_file' }, { name: 'weather_now', integration: 'weather' }];
  assert.equal(describeIntegrationsForRun(engine, 'run-1', tools), 'weather notes');
  assert.equal(describeIntegrationsForRun(engine, 'run-1', tools), '');
  assert.deepEqual(requested, [['weather']]);
});
