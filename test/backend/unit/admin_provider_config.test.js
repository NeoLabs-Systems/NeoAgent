'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let providers;

before(() => {
  ctx = createTestRuntime();
  providers = require('../../../server/services/admin/providers');
});

after(() => {
  teardownTestRuntime(ctx);
});

function providerMap() {
  return new Map(providers.listProviders().providers.map((provider) => [provider.key, provider]));
}

test('admin provider config exposes and persists custom endpoint configuration', () => {
  const initial = providerMap();
  assert.equal(initial.get('OPENAI_COMPATIBLE_API_KEY')?.type, 'key');
  assert.equal(initial.get('OPENAI_COMPATIBLE_BASE_URL')?.type, 'url');

  providers.updateProvider('OPENAI_COMPATIBLE_API_KEY', 'custom-provider-token');
  providers.updateProvider('OPENAI_COMPATIBLE_BASE_URL', 'https://models.example.test/v1');

  assert.equal(process.env.OPENAI_COMPATIBLE_API_KEY, 'custom-provider-token');
  assert.equal(process.env.OPENAI_COMPATIBLE_BASE_URL, 'https://models.example.test/v1');
  const saved = fs.readFileSync(ctx.envFile, 'utf8');
  assert.match(saved, /^OPENAI_COMPATIBLE_API_KEY=custom-provider-token$/m);
  assert.match(saved, /^OPENAI_COMPATIBLE_BASE_URL=https:\/\/models\.example\.test\/v1$/m);

  const configured = providerMap();
  assert.equal(configured.get('OPENAI_COMPATIBLE_API_KEY').configured, true);
  assert.notEqual(configured.get('OPENAI_COMPATIBLE_API_KEY').hint, 'custom-provider-token');
  assert.equal(configured.get('OPENAI_COMPATIBLE_BASE_URL').hint, 'https://models.example.test/v1');
});

test('admin provider config rejects unknown keys and invalid custom endpoint URLs', () => {
  assert.throws(
    () => providers.updateProvider('SESSION_SECRET', 'x'),
    { status: 400, message: /Unknown provider key/ },
  );
  assert.throws(
    () => providers.updateProvider('OPENAI_COMPATIBLE_BASE_URL', 'file:///tmp/models'),
    { status: 400, message: /HTTP or HTTPS/ },
  );
  assert.throws(
    () => providers.updateProvider('OPENAI_COMPATIBLE_BASE_URL', 'https://user:password@models.example.test/v1'),
    { status: 400, message: /embedded credentials/ },
  );
  assert.equal(process.env.OPENAI_COMPATIBLE_BASE_URL, 'https://models.example.test/v1');
});

test('clearing a provider removes it from the environment', () => {
  providers.updateProvider('OPENAI_COMPATIBLE_API_KEY', '');
  assert.equal(process.env.OPENAI_COMPATIBLE_API_KEY, undefined);
  assert.equal(providerMap().get('OPENAI_COMPATIBLE_API_KEY').configured, false);
});
