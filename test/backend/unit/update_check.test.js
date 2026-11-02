'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { checkForUpdate, resolvePreferredBranch } = require('../../../runtime/update_check');

// A scripted git: answers by the first matching prefix of the joined args.
function fakeGit(answers) {
  return (_cmd, args) => {
    const key = args.join(' ');
    const hit = Object.entries(answers).find(([prefix]) => key.startsWith(prefix));
    return hit ? { status: 0, stdout: hit[1] } : { status: 1, stdout: '' };
  };
}

const manifest = (version) => JSON.stringify({ version });
const BETA_REF = 'rev-parse --verify --quiet refs/remotes/origin/beta';

const BETA_TAGS = {
  'tag --list v[0-9]*.[0-9]*.[0-9]*-beta': 'v1.1.0-beta.1\n',
  'tag --list v[0-9]*.[0-9]*.[0-9]* --sort': 'v1.1.0-beta.1\nv1.0.0\n',
};

test('stable follows main; beta follows beta when its tags are newer and the branch exists', () => {
  assert.equal(resolvePreferredBranch('stable', fakeGit({})), 'main');
  assert.equal(resolvePreferredBranch('beta', fakeGit({ [BETA_REF]: '', ...BETA_TAGS })), 'beta');
  assert.equal(resolvePreferredBranch('beta', fakeGit({ ...BETA_TAGS })), 'main');
});

test('beta moves to main when a stable release is newer than the newest beta', () => {
  const run = fakeGit({
    [BETA_REF]: '',
    'tag --list v[0-9]*.[0-9]*.[0-9]*-beta': 'v1.0.0-beta.2\n',
    'tag --list v[0-9]*.[0-9]*.[0-9]* --sort': 'v1.0.0-beta.2\nv1.0.0\n',
  });
  assert.equal(resolvePreferredBranch('beta', run), 'main');
});

test('a newer version on the branch is reported with its changes', async () => {
  const run = fakeGit({
    [BETA_REF]: '',
    ...BETA_TAGS,
    'rev-parse --abbrev-ref HEAD': 'beta',
    'rev-parse HEAD': 'aaa',
    'rev-list --count': '2',
    'show origin/beta:package.json': manifest('0.2.0'),
    'show HEAD:package.json': manifest('0.1.0'),
    'log --no-merges': 'Add a thing\nchore: bump',
  });
  const result = await checkForUpdate({ run, channel: 'beta', fetchRemote: async () => true });
  assert.equal(result.checked, true);
  assert.deepEqual(result.update, { version: '0.2.0', branch: 'beta', changes: ['Add a thing'] });
});

test('an unreachable remote is not an answer', async () => {
  const result = await checkForUpdate({ run: fakeGit({}), channel: 'beta', fetchRemote: async () => false });
  assert.deepEqual(result, { checked: false, update: null, reason: 'offline' });
});
