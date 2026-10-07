'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, ownerRepo, sortByTimestamp, summaryParts } = require('./shared');

module.exports = {
  type: 'github_pr_opened',
  label: 'GitHub Pull Request Opened',
  providerKey: 'github',
  appKey: 'repos',
  configHint: '{ connectionId, repo: "owner/repo", author?, query?: text in title/body }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'github', 'repos'),
      repo: ownerRepo(config),
      author: normalizeTrimmedText(config.author, 100).replace(/^@/, ''),
      query: normalizeTrimmedText(config.query, 200),
    };
  },
  summarize(config = {}) {
    return summaryParts('GitHub Pull Requests', [
      config.repo,
      config.author && `author: ${config.author}`,
      config.query && `contains: ${config.query}`,
    ]);
  },
  poll: {
    intervalMinutes: 2,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      // state=all keeps the checkpoint pull request listed after it closes.
      const result = await tool('github_list_prs', {
        owner_repo: config.repo,
        state: 'all',
        sort: 'created',
        direction: 'desc',
        max_results: 30,
      });
      const query = String(config.query || '').toLowerCase();
      return (Array.isArray(result) ? result : [])
        .filter((item) => item && (!config.author || item.user?.login === config.author))
        .filter((item) => !query || `${item.title || ''}\n${item.body || ''}`.toLowerCase().includes(query))
        .map((item) => ({
          fingerprint: `github_pr:${config.connectionId}:${config.repo}:${item.number}`,
          timestamp: item.created_at || new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'github',
              event: 'pull_request_opened',
              repo: config.repo,
              number: item.number,
              title: item.title || '',
              body: item.body || '',
              author: item.user?.login || null,
              baseBranch: item.base?.ref || null,
              headBranch: item.head?.ref || null,
              draft: item.draft === true,
              url: item.html_url || null,
            },
          },
        }))
        .sort(sortByTimestamp);
    },
  },
};
