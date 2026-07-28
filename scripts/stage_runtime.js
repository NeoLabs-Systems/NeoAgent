#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : '';
  if (!value || value.startsWith('--')) {
    throw new Error(`--${name} is required.`);
  }
  return path.resolve(value);
}

const outputDirectory = argument('output');
const nodeExecutable = argument('node');
const repositoryRoot = path.resolve(__dirname, '..');

fs.rmSync(outputDirectory, { recursive: true, force: true });
const appDirectory = path.join(outputDirectory, 'app');
const nodeDirectory = path.join(outputDirectory, 'node');
fs.mkdirSync(appDirectory, { recursive: true });
fs.mkdirSync(nodeDirectory, { recursive: true });

for (const entry of [
  'bin',
  'extensions',
  'lib',
  'runtime',
  'server',
  'com.neoagent.plist',
  'LICENSE',
  'package.json',
  'package-lock.json',
]) {
  const source = path.join(repositoryRoot, entry);
  if (!fs.existsSync(source)) {
    throw new Error(`Runtime source is missing: ${entry}`);
  }
  fs.cpSync(source, path.join(appDirectory, entry), {
    recursive: true,
    force: true,
  });
}

const nodeModules = path.join(repositoryRoot, 'node_modules');
if (!fs.existsSync(nodeModules)) {
  throw new Error('node_modules is required to stage a self-contained runtime.');
}
fs.cpSync(nodeModules, path.join(appDirectory, 'node_modules'), {
  recursive: true,
  force: true,
});

const targetNode = process.platform === 'win32'
  ? path.join(nodeDirectory, 'node.exe')
  : path.join(nodeDirectory, 'bin', 'node');
fs.mkdirSync(path.dirname(targetNode), { recursive: true });
fs.copyFileSync(nodeExecutable, targetNode);
if (process.platform !== 'win32') fs.chmodSync(targetNode, 0o755);

const cliEntry = path.join(appDirectory, 'bin', 'neoagent.js');
if (!fs.existsSync(cliEntry)) {
  throw new Error('The staged runtime is missing bin/neoagent.js.');
}
