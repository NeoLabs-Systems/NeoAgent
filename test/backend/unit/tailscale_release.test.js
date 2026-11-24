'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const { tailscaleInstallScript } = require('../../../server/services/runtime/tailscale_release');

const STEPS = ['curl', 'sha256sum', 'tar', 'install'];

// Runs the script as the QEMU bootstrap does, without `set -e`, with every
// external step replaced by a stub, so nothing is downloaded or installed.
function runInstall({ failing, script = tailscaleInstallScript() }) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ts-install-test-'));
  try {
    const bin = path.join(dir, 'bin');
    const log = path.join(dir, 'steps.log');
    fs.mkdirSync(bin);
    for (const step of STEPS) {
      const stub = `#!/bin/sh\necho ${step} >> "${log}"\n[ "${failing}" != "${step}" ]\n`;
      fs.writeFileSync(path.join(bin, step), stub, { mode: 0o755 });
    }
    const result = spawnSync('bash', ['-c', `set -uo pipefail\n${script}\necho finished`], {
      encoding: 'utf8',
      env: { ...process.env, PATH: `${bin}:${process.env.PATH}` },
    });
    const ran = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n') : [];
    return { ...result, ran };
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('all steps run when each one succeeds', () => {
  const { status, stdout, ran } = runInstall({ failing: 'none' });
  assert.equal(status, 0);
  assert.match(stdout, /finished/);
  assert.deepEqual(ran, STEPS);
});

for (const [index, step] of STEPS.entries()) {
  test(`a failed ${step} stops the install`, () => {
    const { status, stdout, stderr, ran } = runInstall({ failing: step });
    assert.equal(status, 1);
    assert.doesNotMatch(stdout, /finished/);
    assert.match(stderr, /Error: Tailscale .* failed\./);
    assert.deepEqual(ran, STEPS.slice(0, index + 1));
  });
}

test('the one-line form used by the Docker build behaves the same', () => {
  const script = tailscaleInstallScript().split('\n').join(' ');
  assert.deepEqual(runInstall({ failing: 'none', script }).ran, STEPS);
  const failed = runInstall({ failing: 'sha256sum', script });
  assert.equal(failed.status, 1);
  assert.deepEqual(failed.ran, ['curl', 'sha256sum']);
});
