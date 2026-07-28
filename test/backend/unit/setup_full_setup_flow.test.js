'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const fullSetupModule = path.resolve(
  __dirname,
  '../../../lib/setup/full_setup.js',
);

function runFullSetupFlow(envFile, answers) {
  const program = `
    const { runFullSetup } = require(${JSON.stringify(fullSetupModule)});
    const answers = ${JSON.stringify(answers)};
    runFullSetup({
      io: {
        ask: async () => answers.shift(),
        askSecret: async () => { throw new Error('unexpected secret prompt'); },
        heading: () => {},
        logInfo: () => {},
        logOk: () => {},
      },
    }).then(
      (result) => process.stdout.write(JSON.stringify({ result })),
      (error) => {
        process.stdout.write(JSON.stringify({
          error: { code: error.code, message: error.message },
        }));
        process.exitCode = 2;
      },
    );
  `;
  return spawnSync(process.execPath, ['-e', program], {
    encoding: 'utf8',
    env: {
      ...process.env,
      NEOAGENT_HOME: path.dirname(envFile),
      NEOAGENT_ENV_FILE: envFile,
    },
  });
}

test('full setup validates first and atomically preserves unmanaged config', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-full-'));
  const envFile = path.join(directory, '.env');
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.writeFileSync(envFile, '# retained\nCUSTOM_VALUE=keep\n');

  const child = runFullSetupFlow(envFile, [
    '4444',
    '',
    'false',
    'false',
    'self_hosted',
    'stable',
    '',
    'Y',
    'n',
    'n',
    'n',
    'Y',
  ]);
  assert.equal(child.status, 0, child.stderr);
  const output = JSON.parse(child.stdout);
  assert.deepEqual(output.result.completedSections, ['core', 'network']);
  const saved = fs.readFileSync(envFile, 'utf8');
  assert.match(saved, /^# retained\nCUSTOM_VALUE=keep\n/m);
  assert.match(saved, /^PORT=4444$/m);
  assert.match(saved, /^SESSION_SECRET=.+$/m);
  assert.doesNotMatch(saved, /^OPENAI_API_KEY=/m);
  assert.deepEqual(
    fs.readdirSync(directory).sort(),
    ['.env', 'agent-data', 'data'],
  );
});

test('full setup cancellation leaves existing configuration unchanged', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-cancel-'));
  const envFile = path.join(directory, '.env');
  const original = '# retained\nPORT=3333\n';
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.writeFileSync(envFile, original);

  const child = runFullSetupFlow(envFile, [
    '4444',
    '',
    'false',
    'false',
    'self_hosted',
    'stable',
    '',
    'q',
  ]);
  assert.equal(child.status, 2);
  assert.equal(JSON.parse(child.stdout).error.code, 'SETUP_CANCELLED');
  assert.equal(fs.readFileSync(envFile, 'utf8'), original);
});
