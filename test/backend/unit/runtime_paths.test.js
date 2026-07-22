'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  removeEnvValue,
  upsertEnvValue,
} = require('../../../runtime/paths');

test('runtime env updates are sanitized and atomically replace the target', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-runtime-paths-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const envFile = path.join(directory, '.env');
  fs.writeFileSync(envFile, 'FIRST=one\nTOKEN=old\n', { mode: 0o600 });

  upsertEnvValue(envFile, 'TOKEN', 'new\r\nINJECTED=value');
  assert.equal(
    fs.readFileSync(envFile, 'utf8'),
    'FIRST=one\nTOKEN=newINJECTED=value\n',
  );
  assert.deepEqual(
    fs.readdirSync(directory).sort(),
    ['.env'],
  );
  if (process.platform !== 'win32') {
    assert.equal(fs.statSync(envFile).mode & 0o777, 0o600);
  }

  assert.equal(removeEnvValue(envFile, 'TOKEN'), true);
  assert.equal(fs.readFileSync(envFile, 'utf8'), 'FIRST=one\n');
  assert.throws(
    () => upsertEnvValue(envFile, 'INVALID-KEY', 'value'),
    /Invalid environment variable name/,
  );
});
