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
