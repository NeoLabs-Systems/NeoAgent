'use strict';

// Git facts behind `neoagent update`: is a newer version waiting on the
// release channel's branch, what changed, and how to go back if it fails.

const { compareVersions } = require('../../runtime/release_channel');

const FETCH_TIMEOUT_MS = 8000;
const MAX_CHANGES = 8;

// Commits a person would not call a change: release bookkeeping and merges.
const HOUSEKEEPING = /^(chore|ci|build|test)(\(.+\))?:|\[skip ci\]|^Merge /i;

function createUpdateGit(run) {
  function git(args, options = {}) {
    const result = run('git', args, options);
    return result.status === 0 ? String(result.stdout || '').trim() : null;
  }

  function fetchRemote() {
    return git(['fetch', 'origin', '--tags', '--quiet'], { timeout: FETCH_TIMEOUT_MS }) !== null;
  }

  function head() {
    return { sha: git(['rev-parse', 'HEAD']), branch: git(['rev-parse', '--abbrev-ref', 'HEAD']) };
  }

  function versionAt(ref) {
    try {
      return JSON.parse(git(['show', `${ref}:package.json`]) || '{}').version || null;
    } catch {
      return null;
    }
  }

  // What the last fetch brought for the branch. An older version only counts
  // when the person asked to switch channel explicitly.
  function pendingUpdate(branch, { allowOlder = false } = {}) {
    const remoteRef = `origin/${branch}`;
    const current = head();
    const ahead = Number(git(['rev-list', '--count', `HEAD..${remoteRef}`]) || 0);
    if (ahead === 0 && current.branch === branch) return null;
    const version = versionAt(remoteRef);
    if (!allowOlder && compareVersions(version, versionAt('HEAD')) < 0) return null;
    return { branch, remoteRef, version };
  }

  function changesBetween(from, to) {
    const log = git(['log', '--no-merges', '--format=%s', `${from}..${to}`]);
    if (!log) return [];
    return log.split('\n')
      .map((subject) => subject.trim())
      .filter((subject) => subject && !HOUSEKEEPING.test(subject))
      .slice(0, MAX_CHANGES);
  }

  // Puts the checkout back exactly where it was before an update began.
  function restore({ sha, branch }) {
    if (branch && branch !== 'HEAD' && git(['checkout', '--force', branch]) === null) return false;
    return git(['reset', '--hard', sha]) !== null;
  }

  return {
    changesBetween,
    fetchRemote,
    head,
    pendingUpdate,
    restore,
  };
}

module.exports = {
  createUpdateGit,
};
