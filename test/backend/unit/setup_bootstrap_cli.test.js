'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  assertSafeArchiveEntry,
  currentRuntime,
  runtimeHome,
  safeExtract,
  selectArtifact,
  validateDownloadUrl,
  verifyManifest,
} = require('../../../lib/setup/bootstrap_cli');

test('bootstrap uses a native per-user runtime path', () => {
  assert.equal(
    runtimeHome({ NEOAGENT_HOME: '/tmp/neoagent-test-home' }),
    path.resolve('/tmp/neoagent-test-home'),
  );
});

test('bootstrap selects only the exact platform and architecture artifact', () => {
  const selected = selectArtifact({
    schemaVersion: 1,
    artifacts: [{
      platform: {
        darwin: 'macos',
        win32: 'windows',
        linux: 'linux',
      }[process.platform],
      architecture: process.arch,
      assetName: 'runtime.zip',
      sha256: 'a'.repeat(64),
      sizeBytes: 42,
    }],
  });
  assert.equal(selected.assetName, 'runtime.zip');
});

test('bootstrap verifies raw Ed25519 public keys', () => {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  const bytes = Buffer.from('{"schemaVersion":1}\n');
  const signature = crypto.sign(null, bytes, privateKey).toString('base64');
  const rawPublicKey = publicKey.export({
    format: 'der',
    type: 'spki',
  }).subarray(-32).toString('base64');
  assert.doesNotThrow(() => verifyManifest(bytes, signature, rawPublicKey));
  assert.throws(
    () => verifyManifest(Buffer.from('changed'), signature, rawPublicKey),
    (error) => error.code === 'SETUP_MANIFEST_SIGNATURE_INVALID',
  );
});

test('bootstrap recognizes a complete activated runtime', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-bootstrap-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const version = '3.4.0';
  const directory = path.join(root, 'app', 'versions', version);
  const nodePath = process.platform === 'win32'
    ? path.join(directory, 'node', 'node.exe')
    : path.join(directory, 'node', 'bin', 'node');
  const cliPath = path.join(directory, 'app', 'bin', 'neoagent.js');
  fs.mkdirSync(path.dirname(nodePath), { recursive: true });
  fs.mkdirSync(path.dirname(cliPath), { recursive: true });
  fs.writeFileSync(nodePath, '');
  fs.writeFileSync(cliPath, '');
  fs.mkdirSync(path.join(root, 'app'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'app', 'current.json'),
    JSON.stringify({ schemaVersion: 1, version }),
  );
  assert.equal(currentRuntime(root).version, version);
});

test('bootstrap extraction rejects paths outside staging', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-zip-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  assert.throws(
    () => assertSafeArchiveEntry('../outside.txt', path.join(root, 'extract')),
    (error) => error.code === 'SETUP_RUNTIME_ARCHIVE_INVALID',
  );
});

test('bootstrap accepts only HTTPS runtime download URLs', () => {
  assert.equal(
    validateDownloadUrl('https://github.com/NeoLabs-Systems/NeoAgent').protocol,
    'https:',
  );
  assert.throws(
    () => validateDownloadUrl('http://github.com/NeoLabs-Systems/NeoAgent'),
    (error) => error.code === 'SETUP_DOWNLOAD_URL_INVALID',
  );
});
