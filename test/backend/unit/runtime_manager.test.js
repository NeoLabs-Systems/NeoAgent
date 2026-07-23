'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { RuntimeManager } = require('../../../server/services/runtime/manager');

test('desktop CLI commands execute on the companion provider, never the server worker', async () => {
  const calls = [];
  const manager = Object.create(RuntimeManager.prototype);
  manager.shellWorkerPool = {
    async execute() {
      throw new Error('server shell worker must not execute a desktop command');
    },
  };
  manager.getCliProviderForUser = async () => ({
    backend: 'desktop-companion',
    async execute(command, options) {
      calls.push({ command, options });
      return { stdout: 'from companion', stderr: '', exitCode: 0 };
    },
  });

  const result = await manager.executeCliCommand(7, 'pwd', { timeout: 1234 });

  assert.equal(result.backend, 'desktop-companion');
  assert.equal(result.stdout, 'from companion');
  assert.deepEqual(calls, [{ command: 'pwd', options: { timeout: 1234 } }]);
});

test('interactive desktop CLI commands retain their input sequence', async () => {
  const calls = [];
  const manager = Object.create(RuntimeManager.prototype);
  manager.getCliProviderForUser = async () => ({
    backend: 'desktop-companion',
    async execute() {
      throw new Error('interactive command used the non-interactive path');
    },
    async executeInteractive(command, inputs, options) {
      calls.push({ command, inputs, options });
      return { stdout: 'interactive companion', stderr: '', exitCode: 0 };
    },
  });
  const options = { pty: true, inputs: ['yes\n'], timeout: 5000 };

  const result = await manager.executeCliCommand(7, 'confirm', options);

  assert.equal(result.backend, 'desktop-companion');
  assert.deepEqual(calls, [{ command: 'confirm', inputs: ['yes\n'], options }]);
});

test('Android providers are stable per user so concurrent starts share one controller', async () => {
  const created = [];
  const manager = Object.create(RuntimeManager.prototype);
  manager.androidControllers = new Map();
  manager.createAndroidController = (userId) => {
    const controller = { userId };
    created.push(controller);
    return controller;
  };

  const [first, second, other] = await Promise.all([
    manager.getAndroidProviderForUser(7),
    manager.getAndroidProviderForUser('7'),
    manager.getAndroidProviderForUser(8),
  ]);

  assert.equal(first, second);
  assert.notEqual(first, other);
  assert.equal(created.length, 2);
});
