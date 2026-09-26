'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const githubIssueOpened = require('../../../server/services/tasks/adapters/github_issue_opened');
const { fetchTriggerRows } = require('../../../server/services/tasks/integration_runtime');

const connectedGithub = {
  getConnectionById: () => ({
    id: 3,
    provider_key: 'github',
    app_key: 'repos',
    status: 'connected',
    account_email: 'neo',
  }),
};

test('github issue trigger normalizes filters and rejects a malformed repo', async () => {
  const config = await githubIssueOpened.validateConfig({
    connectionId: 3,
    repo: 'neo/agent',
    author: '@octocat',
    labels: 'bug, urgent,bug',
    query: 'crash',
  }, { integrationManager: connectedGithub, userId: null });

  assert.deepEqual(config, {
    connectionId: 3,
    accountEmail: 'neo',
    repo: 'neo/agent',
    author: 'octocat',
    assignee: '',
    labels: 'bug,urgent',
    query: 'crash',
  });
  await assert.rejects(
    githubIssueOpened.validateConfig({ connectionId: 3, repo: 'agent' }, {
      integrationManager: connectedGithub,
      userId: null,
    }),
    /owner\/repo/,
  );
});

test('github issue polling filters server-side by author and drops pull requests and non-matching text', async () => {
  let calledWith = null;
  const integrationManager = {
    async executeTool(_userId, toolName, args) {
      calledWith = { toolName, args };
      return [
        { number: 7, title: 'App crash on start', created_at: '2026-09-03T00:00:00Z', user: { login: 'octocat' }, labels: [{ name: 'bug' }] },
        { number: 6, title: 'Fix crash', pull_request: {}, created_at: '2026-09-02T00:00:00Z' },
        { number: 5, title: 'Docs typo', created_at: '2026-09-01T00:00:00Z' },
        { number: 4, title: 'Old', body: 'another CRASH', created_at: '2026-08-01T00:00:00Z' },
      ];
    },
  };

  const rows = await fetchTriggerRows({
    integrationManager,
    userId: null,
    agentId: null,
    triggerType: 'github_issue_opened',
    config: { connectionId: 3, repo: 'neo/agent', author: 'octocat', query: 'crash' },
  });

  assert.equal(calledWith.toolName, 'github_list_issues');
  assert.equal(calledWith.args.owner_repo, 'neo/agent');
  assert.equal(calledWith.args.creator, 'octocat');
  assert.equal(calledWith.args.state, 'all');
  assert.deepEqual(rows.map((row) => row.context.triggerEvent.issueNumber), [4, 7]);
  assert.equal(rows[1].fingerprint, 'github_issue:3:neo/agent:7');
  assert.deepEqual(rows[1].context.triggerEvent.labels, ['bug']);
});
