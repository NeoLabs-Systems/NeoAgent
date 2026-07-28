#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {
  createRuntimeManifest,
  serializeRuntimeManifest,
  signRuntimeManifest,
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
const version = argument('version');
const metadata = fs.readdirSync(inputDirectory)
  .filter((name) => name.startsWith('neoagent-runtime-metadata-') && name.endsWith('.json'))
  .map((name) => JSON.parse(fs.readFileSync(path.join(inputDirectory, name), 'utf8')));
const manifest = createRuntimeManifest(version, metadata);
const serialized = serializeRuntimeManifest(manifest);
const signature = signRuntimeManifest(
  Buffer.from(serialized),
  process.env.NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY,
);
fs.writeFileSync(outputPath, serialized);
fs.writeFileSync(`${outputPath}.sig`, `${signature}\n`);
