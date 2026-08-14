'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  LocalComputerBackend,
  normalizeWorkspacePath,
} = require('../../../server/services/runtime/backends/local-computer');
const { DESKTOP_COMMANDS } = require('../../../server/services/desktop/protocol');

function createRegistry() {
  const calls = [];
  const registry = {
    calls,
    isConnected: () => true,
    getStatus: () => ({
      connected: true,
      selectedDeviceId: 'device-1',
      devices: [{
        deviceId: 'device-1',
        label: 'Workstation',
        online: true,
        paused: false,
        permissions: {
          appApprovals: { files: 'always', shell: 'once' },
        },
        metadata: {},
      }],
    }),
    async dispatch(userId, deviceId, command, payload) {
      calls.push({ userId, deviceId, command, payload });
      if (command === DESKTOP_COMMANDS.EXECUTE_COMMAND) {
        return { stdout: 'ok', stderr: '', exitCode: 0 };
      }
      return { success: true, ...payload };
    },
    async pause() {},
  };
  return registry;
}

test('local workspace paths reuse the unified computer path contract', () => {
  assert.equal(normalizeWorkspacePath('/home/neo/workspace'), '');
  assert.equal(normalizeWorkspacePath('/home/neo/workspace/docs/note.md'), 'docs/note.md');
  assert.equal(normalizeWorkspacePath('docs/note.md'), 'docs/note.md');
});

test('local files, shell, and browser navigation share one connection', async () => {
  const registry = createRegistry();
  const backend = new LocalComputerBackend({ registry });

  await backend.requestGuest(
    7,
    'GET',
    '/workspace/files/content?path=%2Fhome%2Fneo%2Fworkspace%2Fnotes.txt',
  );
  await backend.executeCommand(7, 'pwd', { cwd: '/home/neo/workspace' });
  const browser = await backend.getBrowserProviderForUser(7);
  await browser.navigate('https://example.com');

  assert.deepEqual(registry.calls.map((call) => call.command), [
    DESKTOP_COMMANDS.READ_FILE,
    DESKTOP_COMMANDS.EXECUTE_COMMAND,
    DESKTOP_COMMANDS.OPEN_URI,
  ]);
  assert.equal(registry.calls[0].payload.path, 'notes.txt');
  assert.equal(registry.calls[1].payload.cwd, '__neoagent_workspace__');
  assert.equal(registry.calls[2].payload.uri, 'https://example.com');
});

test('local status exposes app approvals without host access', () => {
  const backend = new LocalComputerBackend({ registry: createRegistry() });
  const status = backend.getStatus(7);

  assert.equal(status.state, 'ready');
  assert.equal(status.provider, 'local');
  assert.deepEqual(status.appApprovals, { files: 'always', shell: 'once' });
  assert.equal(status.capabilities.includes('files'), true);
  assert.equal(status.hostAccess, undefined);
});
