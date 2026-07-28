#!/usr/bin/env node
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : '';
  if (!value || value.startsWith('--')) {
    throw new Error(`--${name} is required.`);
  }
  return value;
}

const assetPath = path.resolve(argument('asset'));
const outputPath = path.resolve(argument('output'));
const hash = crypto.createHash('sha256');
hash.update(fs.readFileSync(assetPath));
const metadata = {
  platform: argument('platform'),
  architecture: argument('architecture'),
  assetName: path.basename(assetPath),
  sha256: hash.digest('hex'),
  sizeBytes: fs.statSync(assetPath).size,
};
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(metadata, null, 2)}\n`);
