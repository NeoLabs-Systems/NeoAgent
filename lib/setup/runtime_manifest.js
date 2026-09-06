'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { SETUP_CONTRACT } = require('./contract');

const RUNTIME_SIGNING_PUBLIC_KEY_FILE = path.join(
  __dirname,
  'runtime_signing_public_key.txt',
);

function normalizeArtifactMetadata(value) {
  const platform = String(value?.platform || '').trim();
  const architecture = String(value?.architecture || '').trim();
  const assetName = String(value?.assetName || '').trim();
  const sha256 = String(value?.sha256 || '').trim().toLowerCase();
  const sizeBytes = Number(value?.sizeBytes);
  if (
    !platform
    || !architecture
    || !SETUP_CONTRACT.runtimeTargets[platform]?.includes(architecture)
    || !/^[0-9A-Za-z][0-9A-Za-z._-]*$/.test(assetName)
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

function normalizeRuntimeVersion(value) {
  const version = String(value || '').trim().replace(/^v/, '');
  if (!/^[0-9A-Za-z][0-9A-Za-z.+_-]*$/.test(version)) {
    const error = new Error('A valid runtime manifest version is required.');
    error.code = 'RUNTIME_MANIFEST_VERSION_REQUIRED';
    throw error;
  }
  return version;
}

function createRuntimeManifest(version, metadata) {
  const normalizedVersion = normalizeRuntimeVersion(version);
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
    schemaVersion: SETUP_CONTRACT.schemaVersion,
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

function normalizeRuntimeSigningPublicKey(value) {
  const encoded = String(value || '').trim();
  if (!encoded) {
    const error = new Error('A runtime signing public key is required.');
    error.code = 'RUNTIME_SIGNING_KEY_REQUIRED';
    throw error;
  }
  const der = publicKeyFromBase64(encoded).export({
    format: 'der',
    type: 'spki',
  });
  const raw = der.subarray(-32);
  if (raw.length !== 32) {
    const error = new Error(
      'Runtime signing public key must be a raw 32-byte Ed25519 key.',
    );
    error.code = 'RUNTIME_SIGNING_KEY_INVALID';
    throw error;
  }
  return raw.toString('base64');
}

function canonicalRuntimeSigningPublicKey() {
  let raw;
  try {
    raw = fs.readFileSync(RUNTIME_SIGNING_PUBLIC_KEY_FILE, 'utf8');
  } catch {
    const error = new Error('The embedded runtime signing public key is missing.');
    error.code = 'RUNTIME_SIGNING_KEY_REQUIRED';
    throw error;
  }
  return normalizeRuntimeSigningPublicKey(raw);
}

function assertRuntimeSigningKeypair(
  privateKeyBase64,
  publicKeyBase64 = canonicalRuntimeSigningPublicKey(),
) {
  const expected = normalizeRuntimeSigningPublicKey(publicKeyBase64);
  const probe = Buffer.from('neoagent-runtime-signing-probe\n');
  const signature = signRuntimeManifest(probe, privateKeyBase64);
  if (!verifyRuntimeManifest(probe, signature, expected)) {
    const error = new Error(
      'The runtime signing private key does not match the embedded public key.',
    );
    error.code = 'RUNTIME_SIGNING_KEY_MISMATCH';
    throw error;
  }
  return expected;
}

module.exports = {
  RUNTIME_SIGNING_PUBLIC_KEY_FILE,
  assertRuntimeSigningKeypair,
  canonicalRuntimeSigningPublicKey,
  createRuntimeManifest,
  normalizeArtifactMetadata,
  normalizeRuntimeSigningPublicKey,
  normalizeRuntimeVersion,
  serializeRuntimeManifest,
  signRuntimeManifest,
  verifyRuntimeManifest,
};
