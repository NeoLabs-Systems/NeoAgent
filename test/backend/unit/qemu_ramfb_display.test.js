'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { test } = require('node:test');

const FIRMWARE = [
  '/opt/homebrew/share/qemu/edk2-aarch64-code.fd',
  '/usr/share/qemu/edk2-aarch64-code.fd',
].find((candidate) => fs.existsSync(candidate));

function qemuAvailable() {
  const probe = spawnSync(
    process.platform === 'win32' ? 'where' : 'sh',
    process.platform === 'win32' ? ['qemu-system-aarch64'] : ['-c', 'command -v qemu-system-aarch64'],
    { stdio: 'ignore' },
  );
  return probe.status === 0 && Boolean(FIRMWARE) && os.arch() === 'arm64';
}

function qmp(socketPath, command) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(socketPath);
    let buffer = '';
    let ready = false;
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error('QMP timeout'));
    }, 15000);
    const send = (obj) => socket.write(`${JSON.stringify(obj)}\n`);
    socket.on('data', (chunk) => {
      buffer += chunk.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';
      for (const line of lines) {
        if (!line.trim()) continue;
        let msg;
        try { msg = JSON.parse(line); } catch { continue; }
        if (msg.QMP && !ready) {
          send({ execute: 'qmp_capabilities' });
          continue;
        }
        if (msg.return !== undefined && !ready) {
          ready = true;
          send(command);
          continue;
        }
        if (ready && (msg.return !== undefined || msg.error)) {
          clearTimeout(timer);
          socket.end();
          if (msg.error) reject(new Error(JSON.stringify(msg.error)));
          else resolve(msg.return);
        }
      }
    });
    socket.on('error', reject);
  });
}

function ppmNonBlackPixels(file) {
  const buf = fs.readFileSync(file);
  const header = buf.toString('latin1').match(/^P6\n(?:#.*\n)*(\d+) (\d+)\n(\d+)\n/);
  if (!header) throw new Error(`${file} is not a binary PPM screenshot.`);
  const pixels = buf.subarray(header[0].length);
  let nonempty = 0;
  for (let i = 0; i + 2 < pixels.length; i += 3) {
    if (pixels[i] > 8 || pixels[i + 1] > 8 || pixels[i + 2] > 8) nonempty += 1;
  }
  return { width: Number(header[1]), height: Number(header[2]), nonempty };
}

async function capture(device, directory) {
  const iso = '/tmp/neoagent-display-test/alpine-virt-aarch64.iso';
  if (!fs.existsSync(iso)) throw new Error('Alpine virt ISO is missing.');
  const qmpSocket = path.join(directory, `${device}.sock`);
  const dump = path.join(directory, `${device}.ppm`);
  const child = spawn('qemu-system-aarch64', [
    '-machine', 'virt,highmem=on',
    '-cpu', 'host',
    '-accel', 'hvf',
    '-m', '1024',
    '-drive', `if=pflash,format=raw,readonly=on,file=${FIRMWARE}`,
    '-device', device,
    '-display', 'none',
    '-qmp', `unix:${qmpSocket},server=on,wait=off`,
    '-serial', 'null',
    '-cdrom', iso,
    '-boot', 'd',
  ], { stdio: 'ignore' });
  try {
    for (let i = 0; i < 50 && !fs.existsSync(qmpSocket); i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    if (!fs.existsSync(qmpSocket)) throw new Error('QMP did not start.');
    await new Promise((resolve) => setTimeout(resolve, 8000));
    await qmp(qmpSocket, { execute: 'screendump', arguments: { filename: dump } });
    return ppmNonBlackPixels(dump);
  } finally {
    child.kill('SIGTERM');
  }
}

test('ARM VGA has a VNC framebuffer immediately', async (t) => {
  if (!qemuAvailable()) {
    t.skip('qemu-system-aarch64 + HVF firmware are required');
    return;
  }
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-display-'));
  const qmpSocket = path.join(directory, 'vga.sock');
  const dump = path.join(directory, 'vga.ppm');
  const child = spawn('qemu-system-aarch64', [
    '-machine', 'virt,highmem=on',
    '-cpu', 'host',
    '-accel', 'hvf',
    '-m', '512',
    '-drive', `if=pflash,format=raw,readonly=on,file=${FIRMWARE}`,
    '-device', 'VGA',
    '-display', 'none',
    '-qmp', `unix:${qmpSocket},server=on,wait=off`,
    '-serial', 'null',
  ], { stdio: 'ignore' });
  try {
    for (let i = 0; i < 40 && !fs.existsSync(qmpSocket); i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    if (!fs.existsSync(qmpSocket)) throw new Error('QMP did not start.');
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await qmp(qmpSocket, { execute: 'screendump', arguments: { filename: dump } });
    const shot = ppmNonBlackPixels(dump);
    assert.ok(shot.nonempty > 50, `VGA should paint immediately, got ${shot.nonempty}`);
    assert.ok(shot.width > 0);
  } finally {
    child.kill('SIGTERM');
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('ARM ramfb produces a real QEMU framebuffer screenshot', async (t) => {
  if (!qemuAvailable()) {
    t.skip('qemu-system-aarch64 + HVF firmware are required');
    return;
  }
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-display-'));
  try {
    const ramfb = await capture('ramfb', directory);
    assert.ok(ramfb.nonempty > 100, `ramfb should paint firmware/console pixels, got ${ramfb.nonempty}`);
    assert.equal(ramfb.width > 0, true);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
