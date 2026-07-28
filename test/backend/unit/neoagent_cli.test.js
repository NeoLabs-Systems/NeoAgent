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

test('bare CLI invocation diagnoses an incomplete existing instance without reinstalling', (t) => {
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
  assert.match(output, /installation needs attention/i);
  assert.match(output, /NeoAgent Doctor/);
  assert.doesNotMatch(output, /\nDependencies\n/);
});

test('status --json writes only versioned structured events', (t) => {
  const fixture = createFixture(t);
  const envFile = path.join(fixture.root, '.env');
  fs.writeFileSync(envFile, 'PORT=65530\n');

  const result = spawnSync(
    process.execPath,
    [path.resolve(__dirname, '../../../bin/neoagent.js'), 'status', '--json'],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        NEOAGENT_HOME: fixture.root,
        NEOAGENT_ENV_FILE: envFile,
      },
    },
  );
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, '');
  const events = result.stdout
    .trim()
    .split('\n')
    .map((line) => JSON.parse(line));
  assert.ok(events.length > 0);
  assert.ok(events.every((event) => event.schemaVersion === 1));
  const finalEvent = events.at(-1);
  assert.equal(finalEvent.stage, 'status');
  assert.equal(finalEvent.state, 'ready');
  assert.equal(finalEvent.result.backendUrl, 'http://localhost:65530');
  assert.equal(typeof finalEvent.result.running, 'boolean');
});

test('conflicting setup profiles fail before changes with a stable JSON error', (t) => {
  const fixture = createFixture(t);
  const envFile = path.join(fixture.root, '.env');
  fs.writeFileSync(envFile, 'PORT=65530\n');

  const result = spawnSync(
    process.execPath,
    [
      path.resolve(__dirname, '../../../bin/neoagent.js'),
      'setup',
      '--quick',
      '--full',
      '--json',
    ],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        NEOAGENT_HOME: fixture.root,
        NEOAGENT_ENV_FILE: envFile,
      },
    },
  );
  assert.equal(result.status, 1);
  assert.equal(result.stderr, '');
  const event = JSON.parse(result.stdout.trim());
  assert.equal(event.state, 'failed');
  assert.equal(event.error.code, 'SETUP_PROFILE_CONFLICT');
  assert.equal(event.error.retryable, false);
  assert.equal(fs.existsSync(path.join(fixture.root, 'setup-state.json')), false);
});

test('unattended full setup fails before changes when required values are absent', (t) => {
  const fixture = createFixture(t);
  const result = spawnSync(
    process.execPath,
    [
      path.resolve(__dirname, '../../../bin/neoagent.js'),
      'setup',
      '--full',
      '--non-interactive',
      '--json',
    ],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        NEOAGENT_HOME: fixture.root,
        NEOAGENT_ENV_FILE: path.join(fixture.root, '.env'),
      },
    },
  );
  assert.equal(result.status, 1);
  const event = JSON.parse(result.stdout.trim());
  assert.equal(event.error.code, 'SETUP_REQUIRED_VALUE_MISSING');
  assert.equal(event.error.action, 'fix-input');
  assert.deepEqual(fs.readdirSync(fixture.root), []);
});
