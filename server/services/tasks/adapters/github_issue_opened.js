'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeTrimmedText,
} = require('../security');

const OWNER_REPO_PATTERN = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

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
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'github',
      appKey: 'repos',
    });
    const repo = normalizeTrimmedText(config.repo || config.owner_repo, 200);
    if (!OWNER_REPO_PATTERN.test(repo)) {
      throw new Error('GitHub repository is required in the format "owner/repo".');
    }
    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      repo,
      author: normalizeTrimmedText(config.author || config.creator, 100).replace(/^@/, ''),
      assignee: normalizeTrimmedText(config.assignee, 100).replace(/^@/, ''),
      labels: normalizeLabels(config.labels),
      query: normalizeTrimmedText(config.query, 200),
    };
  },
  summarize(config = {}) {
    const parts = ['GitHub Issues'];
    if (config.repo) parts.push(config.repo);
    if (config.author) parts.push(`author: ${config.author}`);
    if (config.assignee) parts.push(`assignee: ${config.assignee}`);
    if (config.labels) parts.push(`labels: ${config.labels}`);
    if (config.query) parts.push(`contains: ${config.query}`);
    return parts.join(' · ');
  },
};
