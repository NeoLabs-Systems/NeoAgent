'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const { createUniqueCopier, findDataDirectory, isQemuDataDirectory } = require('../../../scripts/stage_qemu_runtime');

test('portable QEMU staging recognizes a dependency after patching its copy', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-stage-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const sourceDirectory = path.join(root, 'source');
  const outputDirectory = path.join(root, 'output');
  fs.mkdirSync(sourceDirectory);
  const source = path.join(sourceDirectory, 'libexample.so.1');
  fs.writeFileSync(source, 'original library');

  const copyUnique = createUniqueCopier();
  const staged = copyUnique(source, outputDirectory);
  fs.appendFileSync(staged, ' patched rpath');

  assert.equal(copyUnique(source, outputDirectory), staged);
  assert.equal(fs.readFileSync(staged, 'utf8'), 'original library patched rpath');
});

test('portable QEMU staging still rejects distinct libraries with one name', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-collision-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const firstDirectory = path.join(root, 'first');
  const secondDirectory = path.join(root, 'second');
  const outputDirectory = path.join(root, 'output');
  fs.mkdirSync(firstDirectory);
  fs.mkdirSync(secondDirectory);
  const first = path.join(firstDirectory, 'libexample.so.1');
  const second = path.join(secondDirectory, 'libexample.so.1');
  fs.writeFileSync(first, 'first library');
  fs.writeFileSync(second, 'second library');

  const copyUnique = createUniqueCopier();
  copyUnique(first, outputDirectory);

  assert.throws(
    () => copyUnique(second, outputDirectory),
    /Portable QEMU dependency name collision: libexample\.so\.1/,
  );
});

test('portable QEMU staging recognizes a Windows-style share firmware directory', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-share-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const binary = path.join(root, 'qemu-system-x86_64.exe');
  const share = path.join(root, 'share');
  fs.writeFileSync(binary, 'qemu');
  fs.mkdirSync(share);
  fs.writeFileSync(path.join(share, 'bios.bin'), 'bios');

  assert.equal(isQemuDataDirectory(share), true);
  assert.equal(isQemuDataDirectory(root), false);
  assert.equal(findDataDirectory(binary), path.resolve(share));
});

test('portable QEMU staging prefers share/qemu over an empty share directory', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-share-qemu-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const binary = path.join(root, 'qemu-system-x86_64');
  const share = path.join(root, 'share');
  const nested = path.join(share, 'qemu');
  fs.writeFileSync(binary, 'qemu');
  fs.mkdirSync(nested, { recursive: true });
  fs.writeFileSync(path.join(nested, 'edk2-aarch64-code.fd'), 'firmware');

  assert.equal(isQemuDataDirectory(share), false);
  assert.equal(findDataDirectory(binary), path.resolve(nested));
});

test('portable QEMU staging accepts a firmware directory with ROM files only', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-qemu-rom-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const firmware = path.join(root, 'share');
  fs.mkdirSync(firmware);
  fs.writeFileSync(path.join(firmware, 'efi-virtio.rom'), 'rom');

  assert.equal(isQemuDataDirectory(firmware), true);
  assert.equal(isQemuDataDirectory(root), false);
});
