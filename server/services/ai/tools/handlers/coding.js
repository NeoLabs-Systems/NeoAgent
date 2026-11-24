'use strict';

const { repoDiff } = require('../../../workspace/repo_diff');
const { repoOverview } = require('../../../workspace/repo_inspect');
const { runProjectTests } = require('../../../workspace/run_tests');
const { createWorkspaceShell } = require('../../../workspace/workspace_shell');

const NO_COMPUTER = 'This needs a computer to run commands on, and none is available.';

// What the run's checkpoints recorded it changed, per repository.
function runRepositories(ctx) {
  const repositories = ctx.engine?.getRunMeta?.(ctx.runId)?.session?.checkpoints?.repositories;
  if (!repositories) return [];
  return [...repositories].map(([root, repository]) => ({
    root,
    paths: [...repository.paths].map(([file, state]) => ({ path: file, source: state.source })),
  }));
}

async function withShell(ctx, work) {
  try {
    const shell = await createWorkspaceShell(ctx);
    if (!shell) return { error: NO_COMPUTER };
    return await work(shell);
  } catch (err) {
    return { error: err.message };
  }
}

const handlers = {
  repo_overview(args, ctx) {
    return withShell(ctx, (shell) => repoOverview(shell, args));
  },

  repo_diff(args, ctx) {
    return withShell(ctx, (shell) => repoDiff(shell, args, runRepositories(ctx)));
  },

  run_tests(args, ctx) {
    return withShell(ctx, (shell) => runProjectTests(shell, args, {
      userId: ctx.userId,
      runId: ctx.runId,
      stepId: ctx.stepId,
      artifactStore: ctx.artifactStore,
    }));
  },
};

module.exports = { handlers };
