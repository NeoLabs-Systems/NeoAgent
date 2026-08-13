'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  PINNED_IMAGES,
  buildQemuArgs,
  normalizeArchitecture,
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
  }
  assert.notEqual(PINNED_IMAGES.x64.sha512, PINNED_IMAGES.arm64.sha512);
});

test('ARM64 computer uses virtio-gpu for the VNC desktop', () => {
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
    assert.match(joined, /-device virtio-gpu-pci,xres=1280,yres=720/);
    assert.match(joined, /if=pflash,unit=0,format=raw,readonly=on/);
    assert.match(joined, /if=pflash,unit=1,format=qcow2/);
    assert.doesNotMatch(joined, /ramfb/);
  } finally {
    if (previousFirmware === undefined) delete process.env.NEOAGENT_QEMU_EFI_FIRMWARE;
    else process.env.NEOAGENT_QEMU_EFI_FIRMWARE = previousFirmware;
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
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
  assert.doesNotMatch(args[args.indexOf('-append') + 1], /console=tty0/);
});
