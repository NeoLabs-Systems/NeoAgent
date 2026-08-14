'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  createCloudInitUserData,
  guestPayloadDigest,
  stageGuestPayload,
} = require('../../../server/services/runtime/guest_bootstrap');

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

test('guest payload identity is deterministic for cloud-init restart persistence', () => {
  const first = guestPayloadDigest('browser_cli');
  const second = guestPayloadDigest('browser_cli');
  assert.match(first, /^[a-f0-9]{64}$/);
  assert.equal(first, second);
  assert.notEqual(first, guestPayloadDigest('android'));
});

test('computer cloud-init starts one owned desktop after cloud-init without an ordering deadlock', () => {
  const userData = createCloudInitUserData({
    guestToken: 'test-token',
    guestPayloadBase64: 'dGVzdA==',
    runtimeProfile: 'browser_cli',
  });

  assert.match(userData, /\[LightDM\]\s+start-default-seat=true\s+logind-check-graphical=false/);
  assert.match(userData, /xserver-command=X -nolisten tcp vt1/);
  assert.doesNotMatch(userData, /xserver-command=X -core/);
  assert.match(userData, /systemctl set-default graphical\.target/);
  assert.match(userData, /chvt 1/);
  assert.match(userData, /getty@tty1/);
  assert.match(userData, /virtio_gpu/);
  assert.match(userData, /bochs/);
  assert.match(userData, /tint2 -c \/etc\/xdg\/tint2\/tint2rc/);
  assert.match(userData, /chown neo:neo \/home\/neo/);
  assert.match(userData, /After=cloud-final\.service/);
  // /home/neo is a separate disk: an agent started before it is mounted writes into a
  // directory the mount then hides, which is how the desktop screenshot lost its target.
  assert.match(userData, /RequiresMountsFor=\/home\/neo/);
  assert.match(userData, /WantedBy=cloud-init\.target/);
  assert.match(userData, /systemctl restart --no-block neoagent-guest-agent\.service/);
  assert.doesNotMatch(userData, /systemctl restart neoagent-guest-agent\.service/);
});
