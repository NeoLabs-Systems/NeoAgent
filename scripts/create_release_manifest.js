#!/usr/bin/env node
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const {
  assertRuntimeSigningKeypair,
  canonicalRuntimeSigningPublicKey,
  signRuntimeManifest,
  verifyRuntimeManifest,
} = require('../lib/setup/runtime_manifest');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : '';
  if (!value || value.startsWith('--')) {
    throw new Error(`--${name} is required.`);
  }
  return value;
}

const inputDirectory = path.resolve(argument('input'));
const outputPath = path.resolve(argument('output'));
const version = argument('version').replace(/^v/, '');
const assets = fs.readdirSync(inputDirectory)
  .filter((name) => {
    const file = path.join(inputDirectory, name);
    return fs.statSync(file).isFile()
      && !name.endsWith('.sig')
      && !name.includes('-metadata-')
      && !name.startsWith('neoagent-release-manifest-');
  })
  .sort()
  .map((name) => {
    const bytes = fs.readFileSync(path.join(inputDirectory, name));
    return {
      name,
      sizeBytes: bytes.length,
      sha256: crypto.createHash('sha256').update(bytes).digest('hex'),
    };
  });
if (assets.length === 0) {
  throw new Error('No release assets are available for signing.');
}
const serialized = `${JSON.stringify({
  schemaVersion: 1,
  version,
  assets,
}, null, 2)}\n`;
assertRuntimeSigningKeypair(process.env.NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY);
const signature = signRuntimeManifest(
  Buffer.from(serialized),
  process.env.NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY,
);
if (!verifyRuntimeManifest(
  Buffer.from(serialized),
  signature,
  canonicalRuntimeSigningPublicKey(),
)) {
  throw new Error('Release manifest signature verification failed.');
}
fs.writeFileSync(outputPath, serialized);
fs.writeFileSync(`${outputPath}.sig`, `${signature}\n`);
