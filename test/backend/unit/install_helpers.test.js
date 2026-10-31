'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const test = require('node:test');
const {
  buildBundledWebClientIfPossible,
} = require('../../../lib/install_helpers');

test('Flutter web builds disable the WASM dry run', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-web-build-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const flutterAppDir = path.join(root, 'flutter_app');
  const webClientDir = path.join(root, 'server', 'public');
  fs.mkdirSync(flutterAppDir, { recursive: true });

  const commands = [];
  const built = buildBundledWebClientIfPossible({
    flutterAppDir,
    webClientDir,
    commandExistsFn: () => true,
    runCommand: (command, args) => {
      commands.push({ command, args });
      return { status: 0 };
    },
    fail: (message) => assert.fail(message),
  });

  assert.equal(built, true);
  const build = commands.find(({ command, args }) => (
    command === 'flutter' && args[0] === 'build'
  ));
  assert.ok(build);
  assert.ok(build.args.includes('--no-wasm-dry-run'));
});

function bundledClientSetup(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-web-bundled-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const flutterAppDir = path.join(root, 'flutter_app');
  const webClientDir = path.join(root, 'server', 'public');
  fs.mkdirSync(flutterAppDir, { recursive: true });
  fs.mkdirSync(webClientDir, { recursive: true });
  fs.writeFileSync(path.join(webClientDir, 'index.html'), '<html></html>');
  fs.writeFileSync(path.join(webClientDir, 'main.dart.js'), '//');
  return { flutterAppDir, webClientDir };
}

test('without Flutter a fresh install uses the bundled client when it is current', (t) => {
  const { flutterAppDir, webClientDir } = bundledClientSetup(t);
  const built = buildBundledWebClientIfPossible({
    flutterAppDir,
    webClientDir,
    commandExistsFn: () => false,
    runCommand: () => assert.fail('nothing should run'),
    fail: (message) => assert.fail(message),
    requireFreshBuild: true,
    bundledIsCurrent: () => true,
  });
  assert.equal(built, false);
});

test('without Flutter a stale bundled client still requires a rebuild', (t) => {
  const { flutterAppDir, webClientDir } = bundledClientSetup(t);
  assert.throws(() => buildBundledWebClientIfPossible({
    flutterAppDir,
    webClientDir,
    commandExistsFn: () => false,
    runCommand: () => ({ status: 0 }),
    fail: (message) => { throw new Error(message); },
    requireFreshBuild: true,
    bundledIsCurrent: () => false,
  }), /older than the app sources/);
});
