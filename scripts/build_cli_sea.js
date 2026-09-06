#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const esbuild = require('esbuild');
const {
  canonicalRuntimeSigningPublicKey,
} = require('../lib/setup/runtime_manifest');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : '';
  if (!value || value.startsWith('--')) {
    throw new Error(`--${name} is required.`);
  }
  return path.resolve(value);
}

function run(command, args) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    stdio: 'inherit',
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${path.basename(command)} exited with ${result.status}.`);
  }
}

async function main() {
  const output = argument('output');
  const packageVersion = JSON.parse(
    fs.readFileSync(path.resolve(__dirname, '../package.json'), 'utf8'),
  ).version;
  const publicKey = canonicalRuntimeSigningPublicKey();
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-sea-'));
  try {
    const bundle = path.join(temporary, 'bootstrap.cjs');
    const blob = path.join(temporary, 'sea-prep.blob');
    const config = path.join(temporary, 'sea-config.json');
    await esbuild.build({
      entryPoints: [path.resolve(__dirname, '../bin/neoagent-bootstrap.js')],
      outfile: bundle,
      bundle: true,
      platform: 'node',
      format: 'cjs',
      target: 'node20',
      define: {
        BOOTSTRAP_VERSION: JSON.stringify(packageVersion),
        RUNTIME_SIGNING_PUBLIC_KEY: JSON.stringify(publicKey),
      },
    });
    fs.writeFileSync(config, `${JSON.stringify({
      main: bundle,
      output: blob,
      disableExperimentalSEAWarning: true,
      useSnapshot: false,
      useCodeCache: false,
    }, null, 2)}\n`);
    run(process.execPath, ['--experimental-sea-config', config]);
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.copyFileSync(process.execPath, output);
    if (process.platform !== 'win32') fs.chmodSync(output, 0o755);
    if (process.platform === 'darwin') {
      spawnSync('codesign', ['--remove-signature', output], {
        stdio: 'ignore',
      });
    }
    const postject = require.resolve('postject/dist/cli.js');
    run(process.execPath, [
      postject,
      output,
      'NODE_SEA_BLOB',
      blob,
      '--sentinel-fuse',
      'NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2',
      ...(process.platform === 'darwin'
        ? ['--macho-segment-name', 'NODE_SEA']
        : []),
    ]);
    if (process.platform === 'darwin') {
      run('codesign', ['--force', '--sign', '-', output]);
    }
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

main();
