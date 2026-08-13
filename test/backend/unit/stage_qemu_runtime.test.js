'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const { createUniqueCopier } = require('../../../scripts/stage_qemu_runtime');

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
