'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');

const {
  createRuntimeManifest,
  serializeRuntimeManifest,
  signRuntimeManifest,
  verifyRuntimeManifest,
} = require('../../../lib/setup/runtime_manifest');

test('runtime manifest is deterministic and rejects duplicate targets', () => {
  const artifacts = [
    {
      platform: 'windows',
      architecture: 'x64',
      assetName: 'windows.zip',
      sha256: 'b'.repeat(64),
      sizeBytes: 20,
    },
    {
      platform: 'macos',
      architecture: 'arm64',
      assetName: 'macos.zip',
      sha256: 'a'.repeat(64),
      sizeBytes: 10,
    },
  ];
  const manifest = createRuntimeManifest('v3.4.0', artifacts);
  assert.equal(manifest.version, '3.4.0');
  assert.equal(manifest.artifacts[0].platform, 'macos');
  assert.throws(
    () => createRuntimeManifest('3.4.0', [artifacts[0], artifacts[0]]),
    (error) => error.code === 'RUNTIME_MANIFEST_DUPLICATE',
  );
  assert.throws(
    () => createRuntimeManifest('../../outside', artifacts),
    (error) => error.code === 'RUNTIME_MANIFEST_VERSION_REQUIRED',
  );
  assert.throws(
    () => createRuntimeManifest('3.4.0', [{
      ...artifacts[0],
      assetName: '../../outside.zip',
    }]),
    (error) => error.code === 'RUNTIME_MANIFEST_INVALID',
  );
});

test('runtime manifest Ed25519 signature detects tampering', () => {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  const privateKeyBase64 = privateKey.export({
    format: 'der',
    type: 'pkcs8',
  }).toString('base64');
  const publicKeyDer = publicKey.export({
    format: 'der',
    type: 'spki',
  });
  const publicKeyBase64 = publicKeyDer.subarray(-32).toString('base64');
  const manifest = createRuntimeManifest('3.4.0', [{
    platform: 'linux',
    architecture: 'x64',
    assetName: 'linux.zip',
    sha256: 'c'.repeat(64),
    sizeBytes: 30,
  }]);
  const bytes = Buffer.from(serializeRuntimeManifest(manifest));
  const signature = signRuntimeManifest(bytes, privateKeyBase64);
  assert.equal(
    verifyRuntimeManifest(bytes, signature, publicKeyBase64),
    true,
  );
  assert.equal(
    verifyRuntimeManifest(bytes, signature, publicKeyDer.toString('base64')),
    true,
  );
  assert.equal(
    verifyRuntimeManifest(
      Buffer.from(bytes.toString().replace('3.4.0', '3.4.1')),
      signature,
      publicKeyBase64,
    ),
    false,
  );
});
