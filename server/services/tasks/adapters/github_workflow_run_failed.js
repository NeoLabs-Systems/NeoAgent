'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, ownerRepo, summaryParts, timeCursor } = require('./shared');

// A run finishes long after it starts, so the cursor is when it last changed:
// that is when it failed, and a failed re-run counts again.
module.exports = {
  type: 'github_workflow_run_failed',
  label: 'GitHub Workflow Run Failed',
  providerKey: 'github',
  appKey: 'repos',
  configHint: '{ connectionId, repo: "owner/repo", workflow?: workflow file name or ID, branch? }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'github', 'repos'),
      repo: ownerRepo(config),
      workflow: normalizeTrimmedText(config.workflow || config.workflow_id, 200),
      branch: normalizeTrimmedText(config.branch, 200),
    };
  },
  summarize(config = {}) {
    return summaryParts('GitHub failed runs', [config.repo, config.workflow, config.branch && `branch: ${config.branch}`]);
  },
  poll: {
    intervalMinutes: 2,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool, config }) {
      const result = await tool('github_list_workflow_runs', {
        owner_repo: config.repo,
        workflow_id: config.workflow || undefined,
        branch: config.branch || undefined,
        status: 'failure',
        max_results: 20,
      });
      return (Array.isArray(result) ? result : [])
        .map((run) => ({
          fingerprint: timeCursor(run.updated_at, run.id),
          timestamp: run.updated_at,
          context: {
            triggerEvent: {
              provider: 'github',
              event: 'workflow_run_failed',
              repo: config.repo,
              runId: run.id,
              workflow: run.name || null,
              branch: run.head_branch || null,
              commit: run.head_sha || null,
              commitMessage: run.head_commit?.message || null,
              actor: run.actor?.login || null,
              attempt: run.run_attempt || 1,
              url: run.html_url || null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
