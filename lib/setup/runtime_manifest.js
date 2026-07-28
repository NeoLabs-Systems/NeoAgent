'use strict';

const crypto = require('crypto');

function normalizeArtifactMetadata(value) {
  const platform = String(value?.platform || '').trim();
  const architecture = String(value?.architecture || '').trim();
  const assetName = String(value?.assetName || '').trim();
  const sha256 = String(value?.sha256 || '').trim().toLowerCase();
  const sizeBytes = Number(value?.sizeBytes);
  if (
    !platform
    || !architecture
    || !assetName
    || !/^[a-f0-9]{64}$/.test(sha256)
    || !Number.isSafeInteger(sizeBytes)
    || sizeBytes <= 0
  ) {
    const error = new Error('Invalid runtime artifact metadata.');
    error.code = 'RUNTIME_MANIFEST_INVALID';
    throw error;
  }
  return { platform, architecture, assetName, sha256, sizeBytes };
}

function createRuntimeManifest(version, metadata) {
  const normalizedVersion = String(version || '').trim().replace(/^v/, '');
  if (!normalizedVersion) {
    const error = new Error('A runtime manifest version is required.');
    error.code = 'RUNTIME_MANIFEST_VERSION_REQUIRED';
    throw error;
  }
  const artifacts = Array.from(metadata, normalizeArtifactMetadata)
    .sort((left, right) => {
      const platformOrder = left.platform.localeCompare(right.platform);
      return platformOrder || left.architecture.localeCompare(right.architecture);
    });
  if (artifacts.length === 0) {
    const error = new Error('At least one runtime artifact is required.');
    error.code = 'RUNTIME_MANIFEST_EMPTY';
    throw error;
  }
  const seen = new Set();
  for (const artifact of artifacts) {
    const key = `${artifact.platform}:${artifact.architecture}`;
    if (seen.has(key)) {
      const error = new Error(`Duplicate runtime artifact for ${key}.`);
      error.code = 'RUNTIME_MANIFEST_DUPLICATE';
      throw error;
    }
    seen.add(key);
  }
  return {
    schemaVersion: 1,
    version: normalizedVersion,
    artifacts,
  };
}

function serializeRuntimeManifest(manifest) {
  return `${JSON.stringify(manifest, null, 2)}\n`;
}

function privateKeyFromBase64(value) {
  const encoded = String(value || '').trim();
  if (!encoded) {
    const error = new Error('NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY is required.');
    error.code = 'RUNTIME_SIGNING_KEY_REQUIRED';
    throw error;
  }
  return crypto.createPrivateKey({
    key: Buffer.from(encoded, 'base64'),
    format: 'der',
    type: 'pkcs8',
  });
}

function publicKeyFromBase64(value) {
  const encoded = String(value || '').trim();
  if (!encoded) {
    const error = new Error('A runtime signing public key is required.');
    error.code = 'RUNTIME_SIGNING_KEY_REQUIRED';
    throw error;
  }
  const decoded = Buffer.from(encoded, 'base64');
  const rawKey = decoded.length === 32;
  const key = rawKey
    ? Buffer.concat([
        Buffer.from('302a300506032b6570032100', 'hex'),
        decoded,
      ])
    : decoded;
  return crypto.createPublicKey({
    key,
    format: 'der',
    type: 'spki',
  });
}

function signRuntimeManifest(manifestBytes, privateKeyBase64) {
  return crypto.sign(
    null,
    Buffer.from(manifestBytes),
    privateKeyFromBase64(privateKeyBase64),
  ).toString('base64');
}

function verifyRuntimeManifest(manifestBytes, signatureBase64, publicKeyBase64) {
  return crypto.verify(
    null,
    Buffer.from(manifestBytes),
    publicKeyFromBase64(publicKeyBase64),
    Buffer.from(String(signatureBase64 || '').trim(), 'base64'),
  );
}

module.exports = {
  createRuntimeManifest,
  serializeRuntimeManifest,
  signRuntimeManifest,
  verifyRuntimeManifest,
};
