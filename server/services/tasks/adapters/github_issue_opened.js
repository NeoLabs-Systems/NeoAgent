'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, ownerRepo, sortByTimestamp, summaryParts } = require('./shared');

function normalizeLabels(value) {
  const raw = Array.isArray(value) ? value : String(value || '').split(',');
  const labels = raw.map((entry) => String(entry || '').trim()).filter(Boolean);
  return Array.from(new Set(labels)).join(',');
}

module.exports = {
  type: 'github_issue_opened',
  label: 'GitHub Issue Opened',
  providerKey: 'github',
  appKey: 'repos',
  configHint: '{ connectionId, repo: "owner/repo", author?, assignee?, labels?: "bug,urgent" (all must match), query?: text in title/body }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'github', 'repos'),
      repo: ownerRepo(config),
      author: normalizeTrimmedText(config.author || config.creator, 100).replace(/^@/, ''),
      assignee: normalizeTrimmedText(config.assignee, 100).replace(/^@/, ''),
      labels: normalizeLabels(config.labels),
      query: normalizeTrimmedText(config.query, 200),
    };
  },
  summarize(config = {}) {
    return summaryParts('GitHub Issues', [
      config.repo,
      config.author && `author: ${config.author}`,
      config.assignee && `assignee: ${config.assignee}`,
      config.labels && `labels: ${config.labels}`,
      config.query && `contains: ${config.query}`,
    ]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      // state=all keeps the checkpoint issue in the list after it is closed, so
      // closing it never makes older issues look new.
      const result = await tool('github_list_issues', {
        owner_repo: config.repo,
        state: 'all',
        creator: config.author || undefined,
        assignee: config.assignee || undefined,
        labels: config.labels || undefined,
        sort: 'created',
        direction: 'desc',
        max_results: 30,
      });
      const issues = Array.isArray(result) ? result : [];
      const query = String(config.query || '').toLowerCase();
      return issues
        // The issues endpoint also returns pull requests.
        .filter((item) => item && !item.pull_request)
        .filter((item) => !query || `${item.title || ''}\n${item.body || ''}`.toLowerCase().includes(query))
        .map((item) => ({
          fingerprint: `github_issue:${config.connectionId}:${config.repo}:${item.number}`,
          timestamp: item.created_at || new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'github',
              repo: config.repo,
              issueNumber: item.number,
              title: item.title || '',
              body: item.body || '',
              author: item.user?.login || null,
              labels: Array.isArray(item.labels) ? item.labels.map((label) => label?.name).filter(Boolean) : [],
              url: item.html_url || null,
            },
          },
        }))
        .sort(sortByTimestamp);
    },
  },
};
