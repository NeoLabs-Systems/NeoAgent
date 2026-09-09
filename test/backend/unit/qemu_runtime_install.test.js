'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const {
  hostQemuInstallPlan,
  packagedQemuExecutableCandidates,
  restoreQemuComputerRuntime,
  stagedQemuRuntimeDirectory,
} = require('../../../lib/qemu_runtime_install');

function writeExecutable(filePath) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, '#!/bin/sh\nexit 0\n');
  fs.chmodSync(filePath, 0o755);
}

test('macOS and Linux install plans match the packaged installer packages', () => {
  assert.deepEqual(hostQemuInstallPlan('macos').args, ['install', 'qemu']);
  const linux = hostQemuInstallPlan('linux', 'x64');
  assert.ok(linux.args.includes('qemu-system-x86'));
  assert.ok(linux.args.includes('qemu-utils'));
  const linuxArm = hostQemuInstallPlan('linux', 'arm64');
  assert.ok(linuxArm.args.includes('qemu-system-arm'));
});

test('the activated package is a QEMU search location', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-package-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, 'app'), { recursive: true });
  fs.writeFileSync(path.join(root, 'app', 'current.json'), JSON.stringify({ version: '3.4.6' }));
  const binary = path.join(
    root,
    'app',
    'versions',
    '3.4.6',
    'app',
    'computer-runtime',
    'qemu',
    'bin',
    'qemu-img',
  );
  writeExecutable(binary);

  assert.deepEqual(packagedQemuExecutableCandidates('qemu-img', root), [binary]);
  assert.deepEqual(packagedQemuExecutableCandidates('qemu-img', path.join(root, 'missing')), []);
});

test('repair copies the activated QEMU runtime into the user computer-runtime', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-restore-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const architecture = process.arch === 'arm64' ? 'arm64' : 'x64';
  const systemName = architecture === 'arm64' ? 'qemu-system-aarch64' : 'qemu-system-x86_64';
  const packaged = path.join(root, 'app', 'versions', '3.4.6', 'app', 'computer-runtime', 'qemu');
  fs.mkdirSync(path.join(root, 'app'), { recursive: true });
  fs.writeFileSync(path.join(root, 'app', 'current.json'), JSON.stringify({ version: '3.4.6' }));
  writeExecutable(path.join(packaged, 'bin', systemName));
  writeExecutable(path.join(packaged, 'bin', 'qemu-img'));

  const restored = restoreQemuComputerRuntime({
    runtimeHome: root,
    architecture,
    runOrThrow() {
      throw new Error('host QEMU install should not run when a packaged runtime exists');
    },
  });

  assert.equal(restored.action, 'copied');
  assert.equal(restored.directory, stagedQemuRuntimeDirectory(root));
  assert.equal(
    fs.readFileSync(path.join(restored.directory, 'bin', 'qemu-img'), 'utf8'),
    fs.readFileSync(path.join(packaged, 'bin', 'qemu-img'), 'utf8'),
  );
});

test('resolver finds QEMU from the activated packaged runtime when brew is absent', (t) => {
  if (process.platform === 'win32') {
    t.skip('Windows executable suffix is covered by packaged-path tests');
    return;
  }
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-resolve-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const architecture = process.arch === 'arm64' ? 'arm64' : 'x64';
  const systemName = architecture === 'arm64' ? 'qemu-system-aarch64' : 'qemu-system-x86_64';
  fs.mkdirSync(path.join(root, 'app'), { recursive: true });
  fs.writeFileSync(path.join(root, 'app', 'current.json'), JSON.stringify({ version: '9.9.9' }));
  const binary = path.join(
    root,
    'app',
    'versions',
    '9.9.9',
    'app',
    'computer-runtime',
    'qemu',
    'bin',
    systemName,
  );
  writeExecutable(binary);
  writeExecutable(path.join(path.dirname(binary), 'qemu-img'));

  const script = `
    process.env.NEOAGENT_HOME = ${JSON.stringify(root)};
    delete process.env.NEOAGENT_QEMU_SYSTEM_BINARY;
    delete process.env.NEOAGENT_QEMU_IMG_BINARY;
    const { resolveQemuSystemBinary, resolveQemuImgBinary } = require(${JSON.stringify(
      path.resolve(__dirname, '../../../server/services/runtime/qemu_vm_manager.js'),
    )});
    process.stdout.write(JSON.stringify({
      system: resolveQemuSystemBinary(),
      img: resolveQemuImgBinary(),
    }));
  `;
  const result = spawnSync(process.execPath, ['-e', script], {
    encoding: 'utf8',
    env: {
      ...process.env,
      PATH: '/usr/bin:/bin',
      NEOAGENT_HOME: root,
    },
  });
  assert.equal(result.status, 0, result.stderr);
  const resolved = JSON.parse(result.stdout);
  assert.equal(resolved.system, binary);
  assert.equal(resolved.img, path.join(path.dirname(binary), 'qemu-img'));
});
