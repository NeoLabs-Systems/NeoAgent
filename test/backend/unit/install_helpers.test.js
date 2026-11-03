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

function flutterRunner(versions, upgradeStatus = 0) {
  const commands = [];
  const runCommand = (command, args) => {
    commands.push(args.join(' '));
    if (args[0] === '--version') {
      return { status: 0, stdout: `Welcome\n{"frameworkVersion":"${versions[0]}"}` };
    }
    if (args[0] === 'upgrade') {
      versions.shift();
      return { status: upgradeStatus };
    }
    return { status: 0 };
  };
  return { commands, runCommand };
}

function requireFlutter(flutterAppDir, version) {
  fs.writeFileSync(
    path.join(flutterAppDir, 'pubspec.yaml'),
    `environment:\n  sdk: ^3.9.2\n  flutter: ">=${version}"\ndependencies:\n  flutter:\n    sdk: flutter\n`,
  );
}

test('an older Flutter is upgraded before the build', (t) => {
  const { flutterAppDir, webClientDir } = bundledClientSetup(t);
  requireFlutter(flutterAppDir, '3.47.9');
  const { commands, runCommand } = flutterRunner(['3.35.5', '3.47.9']);
  const upgrades = [];
  const built = buildBundledWebClientIfPossible({
    flutterAppDir,
    webClientDir,
    commandExistsFn: () => true,
    runCommand,
    onFlutterUpgradeStart: (version) => upgrades.push(version),
    fail: (message) => assert.fail(message),
  });
  assert.equal(built, true);
  assert.deepEqual(upgrades, ['3.47.9']);
  assert.ok(commands.indexOf('upgrade') < commands.indexOf('pub get'));
  assert.ok(commands.some((command) => command.startsWith('build web')));
});

test('a new enough Flutter is left alone', (t) => {
  const { flutterAppDir, webClientDir } = bundledClientSetup(t);
  requireFlutter(flutterAppDir, '3.47.9');
  const { commands, runCommand } = flutterRunner(['3.47.10']);
  buildBundledWebClientIfPossible({
    flutterAppDir,
    webClientDir,
    commandExistsFn: () => true,
    runCommand,
    fail: (message) => assert.fail(message),
  });
  assert.ok(!commands.includes('upgrade'));
});

test('a failed upgrade uses the bundled client when it is current', (t) => {
  const { flutterAppDir, webClientDir } = bundledClientSetup(t);
  requireFlutter(flutterAppDir, '3.47.9');
  const { commands, runCommand } = flutterRunner(['3.35.5', '3.35.5'], 1);
  const built = buildBundledWebClientIfPossible({
    flutterAppDir,
    webClientDir,
    commandExistsFn: () => true,
    runCommand,
    fail: (message) => assert.fail(message),
    requireFreshBuild: true,
    bundledIsCurrent: () => true,
  });
  assert.equal(built, false);
  assert.ok(!commands.includes('pub get'));
});

test('a failed upgrade stops a rebuild when the bundled client is stale', (t) => {
  const { flutterAppDir, webClientDir } = bundledClientSetup(t);
  requireFlutter(flutterAppDir, '3.47.9');
  const { runCommand } = flutterRunner(['3.35.5', '3.35.5'], 1);
  assert.throws(() => buildBundledWebClientIfPossible({
    flutterAppDir,
    webClientDir,
    commandExistsFn: () => true,
    runCommand,
    fail: (message) => { throw new Error(message); },
    requireFreshBuild: true,
    bundledIsCurrent: () => false,
  }), /could not be updated to 3\.47\.9/);
});
