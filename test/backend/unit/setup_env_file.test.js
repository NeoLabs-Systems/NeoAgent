'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  mergeEnvText,
  writeEnvUpdatesAtomic,
} = require('../../../lib/setup/env_file');

test('environment merge preserves comments and unrelated configuration', () => {
  const merged = mergeEnvText(
    '# keep this\nPORT=3333\nCUSTOM_VALUE=preserved\nPORT=duplicate\n',
    { PORT: 4444, SESSION_SECRET: 'generated' },
  );
  assert.equal(merged, [
    '# keep this',
    'PORT=4444',
    'CUSTOM_VALUE=preserved',
    'SESSION_SECRET=generated',
    '',
  ].join('\n'));
});

test('atomic environment writer leaves no staging file', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-env-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const envFile = path.join(directory, '.env');
  fs.writeFileSync(envFile, 'PORT=3333\n');
  writeEnvUpdatesAtomic(envFile, fs.readFileSync(envFile, 'utf8'), {
    PORT: 4444,
  });
  assert.equal(fs.readFileSync(envFile, 'utf8'), 'PORT=4444\n');
  assert.deepEqual(fs.readdirSync(directory), ['.env']);
});
