'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  createIntegrationRegistry,
  discoverProviderModules,
} = require('../../../server/services/integrations/registry');

test('official integration registry discovers a provider.js without central registration', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-provider-registry-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const providerDirectory = path.join(root, 'example');
  fs.mkdirSync(providerDirectory);
  fs.writeFileSync(
    path.join(providerDirectory, 'provider.js'),
    `'use strict';
function createExampleProvider() {
  return {
    key: 'example',
    label: 'Example',
    description: 'Example integration.',
    apps: [{ id: 'example', label: 'Example' }],
    getApp(id) { return id === 'example' ? this.apps[0] : null; },
    getEnvStatus() { return { configured: true, missing: [], summary: 'Ready.' }; },
    getToolDefinitions() { return []; },
    supportsTool() { return false; },
    buildSnapshot() { return { apps: [], connection: { connected: false } }; },
  };
}
module.exports = { createExampleProvider };
`,
  );

  assert.deepEqual(discoverProviderModules(root), [
    path.join(providerDirectory, 'provider.js'),
  ]);
  const registry = createIntegrationRegistry({ providerRoot: root });
  assert.equal(registry.list().length, 1);
  assert.equal(registry.get('example').label, 'Example');
});

test('official integration registry rejects duplicate provider keys', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-provider-duplicate-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const directoryName of ['first', 'second']) {
    const directory = path.join(root, directoryName);
    fs.mkdirSync(directory);
    fs.writeFileSync(
      path.join(directory, 'provider.js'),
      `'use strict';
function createDuplicateProvider() {
  return {
    key: 'duplicate',
    label: 'Duplicate',
    description: 'Duplicate integration.',
    apps: [{ id: 'duplicate', label: 'Duplicate' }],
    getApp() { return this.apps[0]; },
    getEnvStatus() { return { configured: true }; },
    getToolDefinitions() { return []; },
    supportsTool() { return false; },
    buildSnapshot() { return { apps: [] }; },
  };
}
module.exports = { createDuplicateProvider };
`,
    );
  }
  assert.throws(
    () => createIntegrationRegistry({ providerRoot: root }),
    /Duplicate official integration provider key/,
  );
});
