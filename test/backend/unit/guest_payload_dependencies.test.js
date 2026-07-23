'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  stageGuestPayload,
} = require('../../../server/services/runtime/guest_bootstrap');
const {
  runDockerCommand,
} = require('../../../server/services/runtime/guest_image');

function resolveLocalModule(fromFile, request) {
  const base = path.resolve(path.dirname(fromFile), request);
  const candidates = [
    base,
    `${base}.js`,
    `${base}.json`,
    path.join(base, 'index.js'),
  ];
  return candidates.find((candidate) => fs.existsSync(candidate)) || null;
}

function assertDependencyClosure(entryFile) {
  const pending = [entryFile];
  const visited = new Set();
  while (pending.length > 0) {
    const file = pending.pop();
    if (visited.has(file) || path.extname(file) !== '.js') continue;
    visited.add(file);
    const source = fs.readFileSync(file, 'utf8');
    for (const match of source.matchAll(/require\(\s*['"](\.[^'"]+)['"]\s*\)/g)) {
      const dependency = resolveLocalModule(file, match[1]);
      assert.ok(
        dependency,
        `Missing staged dependency ${match[1]} required by ${path.relative(path.dirname(entryFile), file)}`,
      );
      pending.push(dependency);
    }
  }
}

test('browser and Android guest payloads contain their transitive local dependencies', () => {
  const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-guest-payload-test-'));
  try {
    const browserRoot = path.join(temporaryRoot, 'browser');
    stageGuestPayload(browserRoot, 'browser');
    assertDependencyClosure(path.join(browserRoot, 'server/services/browser/controller.js'));

    const androidRoot = path.join(temporaryRoot, 'android');
    stageGuestPayload(androidRoot, 'android');
    assertDependencyClosure(path.join(androidRoot, 'server/services/android/controller.js'));
  } finally {
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
  }
});

test('guest image builds use an asynchronous Docker child process', async () => {
  const child = new EventEmitter();
  child.kill = () => true;
  let invocation = null;
  const result = runDockerCommand(['build', '-t', 'test-image', '/tmp/context'], {
    timeout: 1_000,
    spawnImpl(command, args, options) {
      invocation = { command, args, options };
      setImmediate(() => child.emit('close', 0));
      return child;
    },
  });

  assert.equal(typeof result.then, 'function');
  assert.equal(await result, 0);
  assert.equal(invocation.command, 'docker');
  assert.deepEqual(invocation.args.slice(0, 3), ['build', '-t', 'test-image']);
});
