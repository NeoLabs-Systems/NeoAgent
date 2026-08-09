'use strict';

const assert = require('node:assert/strict');
const express = require('express');
const fs = require('node:fs');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');
const { request } = require('../../helpers/supertest');

let app;
let ctx;
let previousAdminApiKey;

before(() => {
  ctx = createTestRuntime();
  previousAdminApiKey = process.env.ADMIN_API_KEY;
  process.env.ADMIN_API_KEY = 'admin-provider-test-key';
  app = express();
  app.use('/admin', require('../../../server/routes/admin'));
});

after(() => {
  if (previousAdminApiKey === undefined) delete process.env.ADMIN_API_KEY;
  else process.env.ADMIN_API_KEY = previousAdminApiKey;
  teardownTestRuntime(ctx);
});

function authorized(method, path) {
  return request(app)[method](path)
    .set('Authorization', 'Bearer admin-provider-test-key');
}

test('admin provider API exposes and persists custom endpoint configuration', async () => {
  const initial = await authorized('get', '/admin/api/providers').expect(200);
  const fields = new Map(initial.body.providers.map((provider) => [provider.key, provider]));
  assert.equal(fields.get('OPENAI_COMPATIBLE_API_KEY')?.type, 'key');
  assert.equal(fields.get('OPENAI_COMPATIBLE_BASE_URL')?.type, 'url');

  await authorized('put', '/admin/api/providers')
    .send({
      key: 'OPENAI_COMPATIBLE_API_KEY',
      value: 'custom-provider-token',
    })
    .expect(200);
  await authorized('put', '/admin/api/providers')
    .send({
      key: 'OPENAI_COMPATIBLE_BASE_URL',
      value: 'https://models.example.test/v1',
    })
    .expect(200);

  assert.equal(process.env.OPENAI_COMPATIBLE_API_KEY, 'custom-provider-token');
  assert.equal(process.env.OPENAI_COMPATIBLE_BASE_URL, 'https://models.example.test/v1');
  const saved = fs.readFileSync(ctx.envFile, 'utf8');
  assert.match(saved, /^OPENAI_COMPATIBLE_API_KEY=custom-provider-token$/m);
  assert.match(saved, /^OPENAI_COMPATIBLE_BASE_URL=https:\/\/models\.example\.test\/v1$/m);

  const configured = await authorized('get', '/admin/api/providers').expect(200);
  const configuredFields = new Map(
    configured.body.providers.map((provider) => [provider.key, provider]),
  );
  assert.equal(configuredFields.get('OPENAI_COMPATIBLE_API_KEY').configured, true);
  assert.notEqual(configuredFields.get('OPENAI_COMPATIBLE_API_KEY').hint, 'custom-provider-token');
  assert.equal(
    configuredFields.get('OPENAI_COMPATIBLE_BASE_URL').hint,
    'https://models.example.test/v1',
  );
});

test('admin provider API rejects invalid custom endpoint URLs', async () => {
  const response = await authorized('put', '/admin/api/providers')
    .send({
      key: 'OPENAI_COMPATIBLE_BASE_URL',
      value: 'file:///tmp/models',
    })
    .expect(400);

  assert.match(response.body.error, /HTTP or HTTPS/);
  assert.equal(process.env.OPENAI_COMPATIBLE_BASE_URL, 'https://models.example.test/v1');

  const embeddedCredentials = await authorized('put', '/admin/api/providers')
    .send({
      key: 'OPENAI_COMPATIBLE_BASE_URL',
      value: 'https://user:password@models.example.test/v1',
    })
    .expect(400);
  assert.match(embeddedCredentials.body.error, /embedded credentials/);
});
