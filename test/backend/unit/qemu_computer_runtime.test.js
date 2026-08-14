'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { test } = require('node:test');

const {
  PINNED_IMAGES,
  QemuVMManager,
  buildQemuArgs,
  findOrphanedVmPids,
  getSparseDiskLiabilityBytes,
  normalizeArchitecture,
  resolveQemuImgBinary,
} = require('../../../server/services/runtime/qemu_vm_manager');

test('QEMU computer exposes display and guest agent only on loopback', () => {
  const args = buildQemuArgs({
    architecture: 'x64',
    accelerators: ['kvm'],
    memoryMb: 1536,
    cpus: 1,
    systemDisk: '/runtime/user/system.qcow2',
    dataDisk: '/runtime/user/data.qcow2',
    seedImage: '/runtime/user/seed.img',
    guestAgentPort: 8421,
    hostAgentPort: 18421,
    vncDisplay: 10,
    websocketPort: 16080,
    qmpSocket: '/runtime/user/qmp.sock',
  });
  const joined = args.join(' ');

  assert.match(joined, /hostfwd=tcp:127\.0\.0\.1:18421-:8421/);
  assert.match(joined, /127\.0\.0\.1:10,websocket=127\.0\.0\.1:16080/);
  assert.match(joined, /unix:\/runtime\/user\/qmp\.sock/);
  assert.doesNotMatch(joined, /0\.0\.0\.0/);
  assert.match(joined, /system\.qcow2/);
  assert.match(joined, /data\.qcow2/);
  assert.match(joined, /usb-kbd/);
  assert.match(joined, /usb-tablet/);
  assert.match(joined, /-device virtio-vga,xres=1280,yres=720/);
  assert.match(joined, /order=c,menu=off,reboot-timeout=0,splash-time=0,strict=on/);
  assert.equal(args.filter((argument) => argument === '-accel').length, 1);
});

test('Debian guest images are architecture-specific and digest pinned', () => {
  assert.equal(normalizeArchitecture('aarch64'), 'arm64');
  assert.equal(normalizeArchitecture('arm64'), 'arm64');
  for (const image of Object.values(PINNED_IMAGES)) {
    assert.match(image.url, /^https:\/\/cloud\.debian\.org\/images\/cloud\/trixie\//);
    assert.match(image.url, /20260810-2566\.qcow2$/);
    assert.match(image.sha512, /^[a-f0-9]{128}$/);
    // genericcloud ships the "cloud" kernel flavour, which has no DRM drivers, so the
    // guest desktop can never paint a framebuffer on it.
    assert.doesNotMatch(image.url, /genericcloud/);
    assert.match(image.url, /debian-13-generic-(amd64|arm64)/);
  }
  assert.notEqual(PINNED_IMAGES.x64.sha512, PINNED_IMAGES.arm64.sha512);
});

test('ARM64 computer uses VGA so VNC has a framebuffer before the guest starts', () => {
  const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-firmware-test-'));
  const firmware = path.join(temporaryRoot, 'firmware.fd');
  const variables = path.join(temporaryRoot, 'variables.qcow2');
  const previousFirmware = process.env.NEOAGENT_QEMU_EFI_FIRMWARE;
  fs.writeFileSync(firmware, 'test firmware');
  fs.writeFileSync(variables, 'test variables');
  process.env.NEOAGENT_QEMU_EFI_FIRMWARE = firmware;
  try {
    const args = buildQemuArgs({
      architecture: 'arm64',
      accelerators: ['hvf'],
      memoryMb: 1536,
      cpus: 1,
      systemDisk: '/runtime/user/system.qcow2',
      dataDisk: '/runtime/user/data.qcow2',
      seedImage: '/runtime/user/seed.img',
      guestAgentPort: 8421,
      hostAgentPort: 18421,
      vncDisplay: 10,
      websocketPort: 16080,
      qmpSocket: '/runtime/user/qmp.sock',
      armFirmwareVariables: variables,
    });
    const joined = args.join(' ');
    assert.match(joined, /-device VGA,edid=on,xres=1280,yres=720/);
    assert.doesNotMatch(joined, /virtio-gpu/);
    assert.match(joined, /if=pflash,unit=0,format=raw,readonly=on/);
    assert.match(joined, /if=pflash,unit=1,format=qcow2/);
    assert.doesNotMatch(joined, /-device ramfb/);
  } finally {
    if (previousFirmware === undefined) delete process.env.NEOAGENT_QEMU_EFI_FIRMWARE;
    else process.env.NEOAGENT_QEMU_EFI_FIRMWARE = previousFirmware;
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
  }
});

test('retired system disks are not charged against the host storage reserve', (t) => {
  const qemuImg = resolveQemuImgBinary();
  if (!qemuImg) {
    t.skip('qemu-img is required');
    return;
  }
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-storage-'));
  try {
    const instanceDir = path.join(root, 'instance');
    fs.mkdirSync(instanceDir);
    const systemDisk = path.join(instanceDir, 'system.qcow2');
    for (const [name, size] of [['system.qcow2', '8G'], ['system.previous.qcow2', '8G'], ['data.qcow2', '4G']]) {
      spawnSync(qemuImg, ['create', '-f', 'qcow2', path.join(instanceDir, name), size], { stdio: 'ignore' });
    }
    const GIB = 1024 ** 3;

    const live = getSparseDiskLiabilityBytes(qemuImg, root);
    assert.ok(live > 11.5 * GIB && live < 12.5 * GIB, `expected the two live disks, got ${live}`);

    const replacing = getSparseDiskLiabilityBytes(qemuImg, root, systemDisk);
    assert.ok(replacing > 3.5 * GIB && replacing < 4.5 * GIB, `expected only the data disk, got ${replacing}`);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('QMP falls back to loopback when a UNIX socket path would be too long', () => {
  const shortPath = '/runtime/user/qmp.sock';
  const longPath = `/${'deep-runtime-home/'.repeat(6)}instance/qmp.sock`;
  assert.ok(Buffer.byteLength(longPath) >= 104);

  const argsFor = (qmpSocket) => buildQemuArgs({
    architecture: 'x64',
    accelerators: ['kvm'],
    memoryMb: 1536,
    cpus: 1,
    systemDisk: '/runtime/user/system.qcow2',
    dataDisk: '/runtime/user/data.qcow2',
    seedImage: '/runtime/user/seed.img',
    guestAgentPort: 8421,
    hostAgentPort: 18421,
    vncDisplay: 10,
    websocketPort: 16080,
    qmpSocket,
  }).join(' ');

  assert.match(argsFor(shortPath), /-qmp unix:\/runtime\/user\/qmp\.sock/);
  assert.match(argsFor(17009), /-qmp tcp:127\.0\.0\.1:17009,server=on,wait=off/);
});

test('every process still serving an instance is reclaimed, and only those', (t) => {
  if (process.platform === 'win32') {
    t.skip('orphan reclaim is POSIX-only');
    return;
  }
  const instanceDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-orphan-'));
  const otherDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-other-'));
  // Stand-ins for QEMU: the match is on the binary name plus this instance's directory.
  const fake = (dir) => spawn(
    process.execPath,
    ['-e', 'setTimeout(() => {}, 30000)', `qemu-system-aarch64 -drive file=${dir}/system.qcow2`],
    { stdio: 'ignore' },
  );
  const first = fake(instanceDir);
  const second = fake(instanceDir);
  const unrelated = fake(otherDir);
  try {
    const found = findOrphanedVmPids(instanceDir);
    assert.deepEqual(
      found.slice().sort((a, b) => a - b),
      [first.pid, second.pid].sort((a, b) => a - b),
      'both processes serving this instance must be found',
    );
    assert.ok(!found.includes(unrelated.pid), 'another computer is never touched');
    assert.deepEqual(findOrphanedVmPids(path.join(os.tmpdir(), 'neoagent-nothing-here')), []);
  } finally {
    for (const child of [first, second, unrelated]) child.kill('SIGKILL');
    fs.rmSync(instanceDir, { recursive: true, force: true });
    fs.rmSync(otherDir, { recursive: true, force: true });
  }
});

test('direct-boot assets from an older boot profile are re-cached, not reused', async () => {
  const instanceDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-direct-boot-'));
  try {
    const kernel = Buffer.from('replacement kernel');
    const initrd = Buffer.from('replacement initramfs');
    fs.writeFileSync(path.join(instanceDir, 'vmlinuz'), 'stale kernel');
    fs.writeFileSync(path.join(instanceDir, 'initrd.img'), 'stale initramfs');
    fs.writeFileSync(path.join(instanceDir, 'direct-boot.json'), JSON.stringify({
      version: 1,
      architecture: normalizeArchitecture(),
      bootProfile: 'a-previous-display',
      kernelSha256: 'stale',
      initrdSha256: 'stale',
    }));

    const manager = new QemuVMManager();
    manager.instances.set('user-1', { instanceDir });
    let requests = 0;
    const encode = (data) => ({
      sha256: crypto.createHash('sha256').update(data).digest('hex'),
      size: data.length,
      content: data.toString('base64'),
    });
    await manager.cacheDirectBootAssets('user-1', {
      request: async () => {
        requests += 1;
        return { release: '6.12.0', kernel: encode(kernel), initrd: encode(initrd) };
      },
    });

    assert.equal(requests, 1);
    assert.equal(fs.readFileSync(path.join(instanceDir, 'vmlinuz'), 'utf8'), 'replacement kernel');
    const marker = JSON.parse(fs.readFileSync(path.join(instanceDir, 'direct-boot.json'), 'utf8'));
    assert.notEqual(marker.bootProfile, 'a-previous-display');
    assert.match(marker.bootProfile, /^[a-f0-9]{16}$/);

    // A marker written by the current boot profile is reused without a second download.
    await manager.cacheDirectBootAssets('user-1', {
      request: async () => {
        requests += 1;
        return { release: '6.12.0', kernel: encode(kernel), initrd: encode(initrd) };
      },
    });
    assert.equal(requests, 1);
  } finally {
    fs.rmSync(instanceDir, { recursive: true, force: true });
  }
});

test('cached direct boot bypasses firmware disk discovery', () => {
  const args = buildQemuArgs({
    architecture: 'x64',
    accelerators: ['kvm'],
    memoryMb: 1536,
    cpus: 2,
    systemDisk: '/runtime/system.qcow2',
    dataDisk: '/runtime/data.qcow2',
    seedImage: '/runtime/cidata.img',
    guestAgentPort: 8421,
    hostAgentPort: 18421,
    vncDisplay: 10,
    websocketPort: 16080,
    qmpSocket: '/runtime/qmp.sock',
    kernelImage: '/runtime/vmlinuz',
    initrdImage: '/runtime/initrd.img',
  });

  assert.deepEqual(args.slice(args.indexOf('-kernel'), args.indexOf('-kernel') + 4), [
    '-kernel',
    '/runtime/vmlinuz',
    '-initrd',
    '/runtime/initrd.img',
  ]);
  assert.match(args[args.indexOf('-append') + 1], /root=\/dev\/vda1/);
  assert.match(args[args.indexOf('-append') + 1], /console=ttyS0/);
  assert.match(args[args.indexOf('-append') + 1], /console=tty0/);
});
