'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, ownerRepo, summaryParts } = require('./shared');

// Commits are listed in branch order, newest first; author dates can be old
// after a rebase, so position rather than time decides what is new.
module.exports = {
  type: 'github_commit_pushed',
  label: 'GitHub Commit Pushed',
  providerKey: 'github',
  appKey: 'repos',
  configHint: '{ connectionId, repo: "owner/repo", branch?: default branch when empty }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'github', 'repos'),
      repo: ownerRepo(config),
      branch: normalizeTrimmedText(config.branch, 200),
    };
  },
  summarize(config = {}) {
    return summaryParts('GitHub commits', [config.repo, config.branch && `branch: ${config.branch}`]);
  },
  poll: {
    intervalMinutes: 2,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const result = await tool('github_list_commits', {
        owner_repo: config.repo,
        sha: config.branch || undefined,
        max_results: 20,
      });
      return (Array.isArray(result) ? result : [])
        .filter((item) => item?.sha)
        .reverse()
        .map((item) => ({
          fingerprint: `github_commit:${config.connectionId}:${config.repo}:${config.branch}:${item.sha}`,
          timestamp: item.commit?.committer?.date || new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'github',
              event: 'commit_pushed',
              repo: config.repo,
              branch: config.branch || null,
              sha: item.sha,
              message: item.commit?.message || '',
              author: item.author?.login || item.commit?.author?.name || null,
              url: item.html_url || null,
            },
          },
        }));
    },
  },
};
