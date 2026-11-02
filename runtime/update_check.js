'use strict';

// Is a newer version waiting on the release channel? One answer for the
// command line (`neoagent update`, `neoagent status`) and the admin UI.

const { choosePreferredBranchForChannel, getReleaseChannelBranch } = require('./release_channel');
const { createGitHelpers } = require('./git_helpers');
const { createUpdateGit } = require('../lib/cli/updates');

// The branch a channel follows. Beta follows the newest of beta or main by
// release tags, and main alone while no beta branch exists.
function resolvePreferredBranch(channel, run) {
  if (channel === 'stable') return getReleaseChannelBranch(channel);
  const git = createGitHelpers(run);
  // Read from the refs the last fetch brought: no second round trip, and a
  // server never waits on the network here.
  const hasBeta = run('git', ['rev-parse', '--verify', '--quiet', 'refs/remotes/origin/beta']).status === 0;
  const preferred = choosePreferredBranchForChannel(channel, {
    stable: git.latestGitTagVersion('v[0-9]*.[0-9]*.[0-9]*', { excludePrerelease: true }),
    beta: git.latestGitTagVersion('v[0-9]*.[0-9]*.[0-9]*-beta.*'),
  });
  return preferred === 'beta' && !hasBeta ? 'main' : preferred;
}

// `run(cmd, args, options)` is a spawnSync-shaped runner. `fetchRemote` may be
// replaced by an async one so a server never blocks on the network.
async function checkForUpdate({ run, channel, fetchRemote }) {
  const updateGit = createUpdateGit(run);
  const fetched = await (fetchRemote || updateGit.fetchRemote)();
  if (!fetched) return { checked: false, update: null, reason: 'offline' };
  try {
    const branch = resolvePreferredBranch(channel, run);
    const pending = updateGit.pendingUpdate(branch);
    if (!pending) return { checked: true, update: null, branch };
    return {
      checked: true,
      branch,
      update: {
        version: pending.version,
        branch,
        changes: updateGit.changesBetween(updateGit.head().sha, pending.remoteRef),
      },
    };
  } catch (error) {
    return { checked: false, update: null, reason: 'failed', error: error.message };
  }
}

module.exports = { checkForUpdate, resolvePreferredBranch };
