'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  clearSetupState,
  createInstallPlan,
  findAvailablePort,
  normalizeSetupProfile,
  parseSetupArguments,
  readSetupState,
  writeSetupState,
} = require('../../../lib/setup/profiles');
const {
  SetupEventWriter,
} = require('../../../lib/setup/events');

test('setup profiles normalize aliases and reject conflicting flags', () => {
  assert.equal(normalizeSetupProfile('quickstart'), 'quick');
  assert.equal(normalizeSetupProfile('complete'), 'full');
  assert.deepEqual(parseSetupArguments(['--quick', '--json']), {
    profile: 'quick',
    resume: false,
    json: true,
    nonInteractive: false,
    runtimePackage: false,
    deferOptionalSections: false,
  });
  assert.throws(
    () => parseSetupArguments(['--quick', '--full']),
    (error) => error.code === 'SETUP_PROFILE_CONFLICT',
  );
});

test('setup state persists only the non-secret resume contract', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-setup-state-'));
  const stateFile = path.join(directory, 'setup-state.json');
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));

  writeSetupState(stateFile, {
    profile: 'full',
    stage: 'providers',
    status: 'pending',
    completedSections: ['core'],
    apiKey: 'must-not-be-written',
    resumeValues: {
      PORT: '4444',
      PUBLIC_URL: 'https://neoagent.example',
      OPENAI_API_KEY: 'must-not-be-written',
    },
  });
  const raw = fs.readFileSync(stateFile, 'utf8');
  assert.equal(raw.includes('must-not-be-written'), false);
  assert.deepEqual(readSetupState(stateFile).completedSections, ['core']);
  assert.deepEqual(readSetupState(stateFile).resumeValues, {
    PORT: '4444',
    PUBLIC_URL: 'https://neoagent.example',
  });
  clearSetupState(stateFile);
  assert.equal(fs.existsSync(stateFile), false);
});

test('findAvailablePort skips a listener and install plan records the result', async (t) => {
  const listener = net.createServer();
  await new Promise((resolve) => listener.listen(0, '127.0.0.1', resolve));
  t.after(() => listener.close());
  const busyPort = listener.address().port;
  const available = await findAvailablePort(busyPort, { attempts: 20 });
  assert.notEqual(available, busyPort);

  const plan = createInstallPlan({
    profile: 'quick',
    port: available,
    platform: 'test',
    runtimePackage: true,
  });
  assert.equal(plan.profile, 'quick');
  assert.equal(plan.port, available);
  assert.equal(plan.installOptionalCapabilities, false);
  assert.equal(plan.runtimePackage, true);
});

test('JSON setup events expose a stable machine-readable contract', () => {
  let output = '';
  const writer = new SetupEventWriter({
    profile: 'quick',
    json: true,
    output: { write: (value) => { output += value; } },
  });
  writer.start('download', 'Downloading NeoAgent', 0.2);
  writer.complete('download', 'Download complete', 0.4);
  const events = output.trim().split('\n').map((line) => JSON.parse(line));
  assert.equal(events.length, 2);
  assert.equal(events[0].schemaVersion, 1);
  assert.equal(events[0].runId, events[1].runId);
  assert.equal(events[1].stage, 'download');
  assert.equal(events[1].state, 'completed');
  assert.throws(
    () => writer.start('unknown-stage', 'Invalid'),
    (error) => error.code === 'SETUP_EVENT_STAGE_INVALID',
  );
});
