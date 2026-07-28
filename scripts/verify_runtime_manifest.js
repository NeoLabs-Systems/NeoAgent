#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { verifyRuntimeManifest } = require('../lib/setup/runtime_manifest');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : '';
  if (!value || value.startsWith('--')) {
    throw new Error(`--${name} is required.`);
  }
  return path.resolve(value);
}

const manifestPath = argument('manifest');
const signaturePath = argument('signature');
const valid = verifyRuntimeManifest(
  fs.readFileSync(manifestPath),
  fs.readFileSync(signaturePath, 'utf8').trim(),
  process.env.NEOAGENT_RUNTIME_SIGNING_PUBLIC_KEY,
);
if (!valid) {
  const error = new Error(
    'The runtime manifest signature does not match the configured public key.',
  );
  error.code = 'RUNTIME_MANIFEST_SIGNATURE_INVALID';
  throw error;
}
