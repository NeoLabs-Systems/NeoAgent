const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const {
  ensureSecureRuntimeEnv,
} = require('./paths');

test('ensureSecureRuntimeEnv generates runtime secrets when missing', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-runtime-'));
  const envFile = path.join(tempDir, '.env');
  const env = {};

  const result = ensureSecureRuntimeEnv({
    envFile,
    env,
    logger: null,
  });

  const content = fs.readFileSync(envFile, 'utf8');
  assert.match(content, /^SESSION_SECRET=/m);
  assert.match(content, /^NEOAGENT_VM_GUEST_TOKEN=/m);
  assert.equal(result.changes.includes('SESSION_SECRET'), true);
  assert.equal(result.changes.includes('NEOAGENT_VM_GUEST_TOKEN'), true);
  assert.ok(String(env.SESSION_SECRET || '').length >= 64);
  assert.ok(String(env.NEOAGENT_VM_GUEST_TOKEN || '').length >= 64);
});
