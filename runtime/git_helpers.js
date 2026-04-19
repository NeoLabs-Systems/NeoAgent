'use strict';

function createGitHelpers(run) {
  if (typeof run !== 'function') {
    throw new TypeError('createGitHelpers(run) requires a run function');
  }

  function latestGitTagVersion(pattern) {
    const res = run('git', ['tag', '--list', pattern, '--sort=-v:refname']);
    if (res.status !== 0) return null;
    const tag = String(res.stdout || '')
      .split('\n')
      .map((value) => value.trim())
      .find(Boolean);
    return tag ? tag.replace(/^v/, '') : null;
  }

  function gitWorkingTreeDirty() {
    const res = run('git', ['status', '--porcelain']);
    return res.status === 0 && Boolean(String(res.stdout || '').trim());
  }

  function gitLocalBranchExists(branch) {
    return run('git', ['show-ref', '--verify', '--quiet', `refs/heads/${branch}`]).status === 0;
  }

  function gitRemoteBranchExists(branch) {
    return run('git', ['ls-remote', '--exit-code', '--heads', 'origin', branch]).status === 0;
  }

  return {
    latestGitTagVersion,
    gitWorkingTreeDirty,
    gitLocalBranchExists,
    gitRemoteBranchExists,
  };
}

module.exports = {
  createGitHelpers,
};
