'use strict';

const { retrieveTools } = require('../../tool_retrieval');

const { updateTaskLedger } = require('../../runtime/task_state');

const handlers = {
  async task_ledger(args, ctx) {
    return updateTaskLedger(ctx.engine, ctx.runId, args);
  },

  async search_tools(args, ctx) {
    const { engine, runId } = ctx;
    try {
      const runMeta = engine.getRunMeta?.(runId);
      const closest = runMeta?.toolCatalog
        ? await retrieveTools(runMeta.toolCatalog, args.query, {
          provider: runMeta.session?.model?.providerName || null,
          userId: runMeta.userId,
          agentId: runMeta.agentId,
          signal: runMeta.abortController?.signal || null,
        })
        : [];
      return engine.searchToolsForRun(runId, args.query, args.limit, closest.map((tool) => tool.name));
    } catch (err) {
      return { error: `search_tools failed: ${err.message}` };
    }
  },

  async activate_tools(args, ctx) {
    const { engine, runId } = ctx;
    try {
      return engine.activateToolsForRun(runId, args.names || []);
    } catch (err) {
      return { error: `activate_tools failed: ${err.message}` };
    }
  },

  async background_task(args, ctx) {
    const { engine, runId } = ctx;
    try {
      return engine.manageBackgroundRun(runId, args);
    } catch (err) {
      return { error: `background_task failed: ${err.message}` };
    }
  },
};

module.exports = { handlers };
