'use strict';

const { createAgentForRun } = require('../../../agents/creation');
const { EVENT_TYPES } = require('../../runtime/events/event_types');

const handlers = {
  async spawn_subagent(args, ctx) {
    const { agentId, app, engine, runId, userId } = ctx;
    try {
    return await engine.spawnSubagent(userId, runId, args.task, {
      app,
      model: args.model || null,
      context: args.context || null,
      requiredArtifacts: args.required_artifacts || [],
      allowedTools: Array.isArray(args.tools) ? args.tools : null,
      write: args.write === true,
      maxTurns: args.max_turns,
      maxTokens: args.max_tokens,
      maxSeconds: args.max_seconds,
      selectedTools: args.tools || engine.getActiveTools(runId).map((tool) => tool.name),
      agentId,
    });
    } catch (err) {
    return { error: `Sub-agent failed: ${err.message}` };
    }
  },

  async delegate_to_agent(args, ctx) {
    try {
      return ctx.engine.delegateTask(ctx, args);
    } catch (err) {
      return { error: `delegate_to_agent failed: ${err.message}` };
    }
  },

  async agent_task(args, ctx) {
    try {
      return await ctx.engine.agentTaskAction(ctx, args);
    } catch (err) {
      return { error: `agent_task failed: ${err.message}` };
    }
  },

  async create_agent(args, ctx) {
    const { agentId, engine, runId, userId } = ctx;
    const runMeta = engine.getRunMeta(runId);
    try {
      const result = createAgentForRun({
        userId,
        agentId,
        runId,
        alreadyCreatedInRun: Boolean(runMeta?.createdAgentId),
      }, args);
      if (result.error) return result;
      if (runMeta) runMeta.createdAgentId = result.id;
      engine.recordRunEvent(userId, runId, EVENT_TYPES.AGENT_CREATED, { agent_id: result.id }, { agentId });
      engine.emit(userId, 'agents:changed', { agentId: result.id });
      return {
        created: true,
        agent: { id: result.id, slug: result.slug, name: result.displayName },
        note: 'The user can see, change or archive it in their agent list. Hand it work with delegate_to_agent.',
      };
    } catch (err) {
      return { error: `create_agent failed: ${err.message}` };
    }
  },

  async list_subagents(args, ctx) {
    const { engine, runId } = ctx;
    try {
      return { subagents: engine.listSubagents(runId) };
    } catch (err) {
      return { error: `list_subagents failed for run ${runId}: ${err?.message || String(err)}` };
    }
  },

  async wait_subagent(args, ctx) {
    const { engine, runId } = ctx;
    try {
      return await engine.waitForSubagent(args.handle, {
        parentRunId: runId,
        timeoutMs: args.timeout_ms,
      });
    } catch (err) {
      return {
        error: `wait_subagent failed for run ${runId}, handle ${args.handle || 'unknown'}, timeout ${args.timeout_ms || 'default'}: ${err?.message || String(err)}`
      };
    }
  },

  async cancel_subagent(args, ctx) {
    const { engine, runId } = ctx;
    try {
      return await engine.cancelSubagent(args.handle, { parentRunId: runId });
    } catch (err) {
      return { error: `cancel_subagent failed for run ${runId}, handle ${args.handle || 'unknown'}: ${err?.message || String(err)}` };
    }
  },
};

module.exports = { handlers };
