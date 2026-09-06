'use strict';

// Regression guard for the beta-channel update path: the stable-tag glob
// (v[0-9]*.[0-9]*.[0-9]*) also matches prerelease tags, which made the latest
// beta tag masquerade as the latest stable version. The tie then routed beta
// updates to origin/main, silently skipping every beta release.

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createGitHelpers } = require('../../../runtime/git_helpers');
const { choosePreferredBranchForChannel } = require('../../../runtime/release_channel');

function helpersForTags(tags) {
  return createGitHelpers(() => ({ status: 0, stdout: `${tags.join('\n')}\n` }));
}

test('stable tag lookup skips prerelease tags when asked', () => {
  const helpers = helpersForTags(['v3.4.5-beta.6', 'v3.4.5-beta.5', 'v3.4.4', 'v3.4.3']);

  assert.equal(
    helpers.latestGitTagVersion('v*', { excludePrerelease: true }),
    '3.4.4',
  );
  assert.equal(helpers.latestGitTagVersion('v*'), '3.4.5-beta.6');
});

test('beta channel prefers the beta branch when its tag is newest', () => {
  const helpers = helpersForTags(['v3.4.5-beta.6', 'v3.4.4']);
  const branch = choosePreferredBranchForChannel('beta', {
    stable: helpers.latestGitTagVersion('v*', { excludePrerelease: true }),
    beta: helpers.latestGitTagVersion('v*-beta.*'),
  });

  assert.equal(branch, 'beta');
});

test('beta channel falls back to main once stable overtakes the last beta', () => {
  const branch = choosePreferredBranchForChannel('beta', {
    stable: '3.4.5',
    beta: '3.4.5-beta.6',
  });

  assert.equal(branch, 'main');
});
