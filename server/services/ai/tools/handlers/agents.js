'use strict';

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
    const { agentId, app, engine, runId, triggerSource, userId } = ctx;
    try {
    if (triggerSource === 'agent_delegation') {
      return { error: 'Nested agent delegation is disabled in v1.' };
    }
    if (!engine || typeof engine.delegateToAgent !== 'function') {
      return { error: 'Agent delegation is not available.' };
    }
    return await engine.delegateToAgent({
      userId,
      parentAgentId: agentId,
      parentRunId: runId,
      target: args.agent,
      task: args.task,
      context: args.context || '',
      app,
      allowExternalSideEffects: args.allow_external_side_effects === true,
    });
    } catch (err) {
    return { error: `delegate_to_agent failed: ${err.message}` };
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
