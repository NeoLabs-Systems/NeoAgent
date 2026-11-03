'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');

test('public AI status reflects routing service, not environment keys', () => {
  const original = Module._load;
  Module._load = function (request, parent, isMain) {
    if (parent?.filename.endsWith('/services/public_status.js') && request === '../db/database') return { prepare: () => ({ get: () => ({ ok: 1 }) }) };
    if (parent?.filename.endsWith('/services/public_status.js') && request === './runtime/validation') return { getRuntimeValidation: () => ({ ready: true }) };
    return original.apply(this, arguments);
  };
  try {
    const { buildPublicStatus } = require('../../../server/services/public_status');
    const status = buildPublicStatus({ locals: { agentEngine: {}, memoryManager: {}, runtimeManager: { computerBackend: {} }, messagingManager: {}, integrationManager: {}, mcpClient: {}, taskRuntime: {}, voiceRuntimeManager: {} } });
    const ai = status.components.find((item) => item.name === 'AI Gateway');
    assert.equal(ai.status, 'operational');
    assert.doesNotMatch(ai.description, /no public provider configuration/);
    assert.equal(buildPublicStatus({ locals: {} }).components.find((item) => item.name === 'AI Gateway').status, 'degraded');
  } finally { Module._load = original; }
});
