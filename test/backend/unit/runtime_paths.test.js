'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  ensureSecureRuntimeEnv,
  migrateLegacyDesktopEnv,
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

test('runtime defaults drop the retired admin dashboard credentials', (t) => {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), 'neoagent-runtime-defaults-'),
  );
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const envFile = path.join(directory, '.env');
  fs.writeFileSync(
    envFile,
    [
      'PORT=3333',
      'ADMIN_USERNAME=admin',
      'ADMIN_PASSWORD=old-admin-password',
      'ADMIN_API_KEY=old-admin-api-key',
      '',
    ].join('\n'),
  );
  const warnings = [];

  ensureSecureRuntimeEnv({
    envFile,
    env: {},
    logger: { warn: (message) => warnings.push(message), info() {} },
  });

  const contents = fs.readFileSync(envFile, 'utf8');
  assert.doesNotMatch(contents, /ADMIN_(USERNAME|PASSWORD|API_KEY)=/);
  assert.match(contents, /^PORT=3333$/m);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /neoagent admin/);

  const repeatWarnings = [];
  ensureSecureRuntimeEnv({
    envFile,
    env: {},
    logger: { warn: (message) => repeatWarnings.push(message), info() {} },
  });
  assert.equal(repeatWarnings.length, 0);
});

test('legacy desktop config migrates without rotating persistent identity', (t) => {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), 'neoagent-desktop-config-'),
  );
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const legacyEnvFile = path.join(directory, 'runtime', '.env');
  const envFile = path.join(directory, '.env');
  fs.mkdirSync(path.dirname(legacyEnvFile), { recursive: true });
  fs.writeFileSync(
    legacyEnvFile,
    [
      'PORT=4444',
      'OPENAI_API_KEY=legacy-provider-key',
      'SESSION_SECRET=legacy-session-secret',
      'NEOAGENT_ENCRYPTION_KEY=legacy-encryption-key',
      '',
    ].join('\n'),
  );
  fs.writeFileSync(
    envFile,
    [
      'PORT=3333',
      'SESSION_SECRET=stable-session-secret',
      'NEOAGENT_ENCRYPTION_KEY=stable-encryption-key',
      '',
    ].join('\n'),
  );
  const messages = [];

  assert.equal(
    migrateLegacyDesktopEnv({
      legacyEnvFile,
      envFile,
      logger: (message) => messages.push(message),
    }),
    true,
  );

  const migrated = Object.fromEntries(
    fs.readFileSync(envFile, 'utf8')
      .trim()
      .split('\n')
      .map((line) => {
        const separatorIndex = line.indexOf('=');
        return [line.slice(0, separatorIndex), line.slice(separatorIndex + 1)];
      }),
  );
  assert.equal(migrated.PORT, '4444');
  assert.equal(migrated.OPENAI_API_KEY, 'legacy-provider-key');
  assert.equal(migrated.SESSION_SECRET, 'stable-session-secret');
  assert.equal(migrated.NEOAGENT_ENCRYPTION_KEY, 'stable-encryption-key');
  assert.equal(fs.existsSync(legacyEnvFile), false);
  assert.equal(fs.existsSync(`${legacyEnvFile}.migrated`), true);
  assert.equal(messages.length, 1);
});
