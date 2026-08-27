'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  SOURCE_REPOSITORY_URL,
  defaultSourceInstallDirectory,
  inspectSourceDirectory,
  isCanonicalSourceRemote,
  prepareSourceInstallation,
} = require('../../../lib/source_install');

function createCheckout(directory) {
  fs.mkdirSync(path.join(directory, '.git'), { recursive: true });
  fs.mkdirSync(path.join(directory, 'bin'), { recursive: true });
  fs.mkdirSync(path.join(directory, 'server', 'public'), { recursive: true });
  fs.writeFileSync(path.join(directory, 'bin', 'neoagent.js'), '');
  fs.writeFileSync(path.join(directory, 'server', 'public', 'index.html'), '');
  fs.writeFileSync(path.join(directory, 'com.neoagent.plist'), '');
  fs.writeFileSync(path.join(directory, 'package.json'), JSON.stringify({ version: '4.0.0' }));
}

function successfulRun(calls) {
  return (command, args, options = {}) => {
    calls.push({ command, args, cwd: options.cwd });
    if (command === 'git' && args[0] === 'clone') {
      createCheckout(args[2]);
    }
    if (command === 'git' && args.join(' ') === 'remote get-url origin') {
      return { status: 0, stdout: `${SOURCE_REPOSITORY_URL}\n`, stderr: '' };
    }
    if (command === 'git' && args.join(' ') === 'rev-parse --abbrev-ref HEAD') {
      return { status: 0, stdout: 'main\n', stderr: '' };
    }
    if (command === 'git' && args[0] === 'tag' && args[2].includes('-beta.')) {
      return { status: 0, stdout: 'v4.1.0-beta.0\n', stderr: '' };
    }
    if (command === 'git' && args[0] === 'tag') {
      return { status: 0, stdout: 'v4.0.0\n', stderr: '' };
    }
    if (command === 'git' && args[0] === 'show-ref') {
      return { status: 1, stdout: '', stderr: '' };
    }
    return { status: 0, stdout: '', stderr: '' };
  };
}

test('source install path supports an explicit migration directory', () => {
  assert.equal(
    defaultSourceInstallDirectory({ NEOAGENT_SOURCE_DIR: '/tmp/neoagent-source' }),
    path.resolve('/tmp/neoagent-source'),
  );
});

test('source install recognizes canonical HTTPS and SSH remotes', () => {
  assert.equal(isCanonicalSourceRemote(SOURCE_REPOSITORY_URL), true);
  assert.equal(
    isCanonicalSourceRemote('git@github.com:NeoLabs-Systems/NeoAgent.git'),
    true,
  );
  assert.equal(
    isCanonicalSourceRemote('https://github.com/NeoLabs-Systems/AnotherProject.git'),
    false,
  );
});

test('source install refuses occupied non-Git directories', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-source-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const sourceDirectory = path.join(root, 'NeoAgent');
  fs.mkdirSync(sourceDirectory);
  fs.writeFileSync(path.join(sourceDirectory, 'unrelated.txt'), 'keep');
  assert.equal(inspectSourceDirectory(sourceDirectory), 'occupied');
  assert.throws(
    () => prepareSourceInstallation({
      run: () => assert.fail('no command should run for an occupied directory'),
      releaseChannel: 'stable',
      sourceDirectory,
    }),
    /already exists and is not a NeoAgent Git checkout/,
  );
  assert.equal(fs.readFileSync(path.join(sourceDirectory, 'unrelated.txt'), 'utf8'), 'keep');
});

test('source install clones, selects the beta branch, installs, and links', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-source-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const sourceDirectory = path.join(root, 'NeoAgent');
  const calls = [];
  const result = prepareSourceInstallation({
    run: successfulRun(calls),
    releaseChannel: 'beta',
    sourceDirectory,
  });
  assert.equal(result.createdCheckout, true);
  assert.equal(result.targetBranch, 'beta');
  assert.equal(result.version, '4.0.0');
  assert.ok(calls.some((call) => call.command === 'git' && call.args[0] === 'clone'));
  assert.ok(calls.some((call) => call.command === 'git' && call.args.join(' ') === 'checkout -b beta --track origin/beta'));
  assert.ok(calls.some((call) => call.command === 'npm' && call.args[0] === 'install'));
  assert.ok(calls.some((call) => call.command === 'npm' && call.args[0] === 'link'));
});

test('source install does not mutate an existing checkout with local changes', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-source-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const sourceDirectory = path.join(root, 'NeoAgent');
  createCheckout(sourceDirectory);
  const calls = [];
  const run = successfulRun(calls);
  assert.throws(
    () => prepareSourceInstallation({
      run: (command, args, options) => {
        if (command === 'git' && args.join(' ') === 'status --porcelain') {
          return { status: 0, stdout: ' M local.txt\n', stderr: '' };
        }
        return run(command, args, options);
      },
      releaseChannel: 'stable',
      sourceDirectory,
    }),
    /has local changes/,
  );
  assert.equal(calls.some((call) => call.command === 'npm'), false);
});
