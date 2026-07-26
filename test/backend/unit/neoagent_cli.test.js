'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const {
  parseProviderChoices,
  scanForInstalledInstance,
} = require('../../../lib/manager');

function createFixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-cli-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return {
    root,
    databaseFile: path.join(root, 'data', 'neoagent.db'),
    macServiceFile: path.join(root, 'com.neoagent.plist'),
    linuxServiceFile: path.join(root, 'neoagent.service'),
  };
}

test('installation scan does not treat an empty runtime directory as an installed instance', (t) => {
  const fixture = createFixture(t);
  fs.mkdirSync(path.dirname(fixture.databaseFile), { recursive: true });

  const result = scanForInstalledInstance({
    platform: 'linux',
    ...fixture,
    serverProcesses: [],
  });

  assert.equal(result.installed, false);
  assert.deepEqual(result.evidence, []);
});

test('installation scan recognizes runtime data, system services, and running servers', (t) => {
  const fixture = createFixture(t);
  fs.mkdirSync(path.dirname(fixture.databaseFile), { recursive: true });
  fs.writeFileSync(fixture.databaseFile, '');
  fs.writeFileSync(fixture.linuxServiceFile, '');

  const result = scanForInstalledInstance({
    platform: 'linux',
    ...fixture,
    serverProcesses: [{ pid: 4321 }],
  });

  assert.equal(result.installed, true);
  assert.deepEqual(
    result.evidence.map((item) => item.type),
    ['runtime-data', 'systemd-service', 'running-server'],
  );
});

test('installation scan uses the platform-specific service registration', (t) => {
  const fixture = createFixture(t);
  fs.writeFileSync(fixture.macServiceFile, '');

  const macResult = scanForInstalledInstance({
    platform: 'macos',
    ...fixture,
    serverProcesses: [],
  });
  const linuxResult = scanForInstalledInstance({
    platform: 'linux',
    ...fixture,
    serverProcesses: [],
  });

  assert.equal(macResult.installed, true);
  assert.equal(linuxResult.installed, false);
});

test('provider wizard accepts unique comma-separated choices and rejects invalid input', () => {
  assert.deepEqual(parseProviderChoices('1, 3, 1'), [1, 3]);
  assert.deepEqual(parseProviderChoices('0'), []);
  assert.deepEqual(parseProviderChoices(''), []);
  assert.throws(
    () => parseProviderChoices('1,8', 7),
    /Choose provider numbers from 1 to 7/,
  );
});

test('bare CLI invocation shows status instead of reinstalling an existing instance', (t) => {
  const fixture = createFixture(t);
  fs.mkdirSync(path.dirname(fixture.databaseFile), { recursive: true });
  fs.writeFileSync(fixture.databaseFile, '');

  const result = spawnSync(
    process.execPath,
    [path.resolve(__dirname, '../../../bin/neoagent.js')],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        NEOAGENT_HOME: fixture.root,
      },
    },
  );
  const output = `${result.stdout}\n${result.stderr}`;

  assert.equal(result.status, 0, output);
  assert.match(output, /Existing NeoAgent installation found/);
  assert.match(output, /NeoAgent Status/);
  assert.doesNotMatch(output, /\nDependencies\n/);
});
