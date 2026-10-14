'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { ISOReader } = require('@gcu/iso9660');

const { writeSeedIsoWithJavascript } = require('../../../server/services/runtime/guest_bootstrap');

const SEED_FILES = {
  'user-data': '#cloud-config\nusers: []\n',
  'meta-data': 'instance-id: neoagent-test\nlocal-hostname: neo\n',
  'startup.nsh': '@echo -off\r\nfs0:\r\n',
};

test('the JS fallback writes a CIDATA seed cloud-init can read, from any working directory', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-seed-iso-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const sourceDir = path.join(root, 'seed');
  fs.mkdirSync(path.join(sourceDir, 'nested'), { recursive: true });
  for (const [name, content] of Object.entries(SEED_FILES)) {
    fs.writeFileSync(path.join(sourceDir, name), content);
  }
  const isoPath = path.join(root, 'cidata.iso');

  // The server's working directory is not the app folder when it runs as a
  // service, so the writer must not depend on it.
  const previousCwd = process.cwd();
  process.chdir(os.tmpdir());
  try {
    writeSeedIsoWithJavascript(sourceDir, isoPath);
  } finally {
    process.chdir(previousCwd);
  }

  const iso = fs.readFileSync(isoPath);
  const reader = new ISOReader(iso.buffer.slice(iso.byteOffset, iso.byteOffset + iso.byteLength));
  assert.equal(reader.volumeId, 'CIDATA');
  assert.deepEqual(reader.list().sort(), ['/meta-data', '/startup.nsh', '/user-data']);
  for (const [name, content] of Object.entries(SEED_FILES)) {
    assert.equal(reader.readText(`/${name}`), content);
  }
});
