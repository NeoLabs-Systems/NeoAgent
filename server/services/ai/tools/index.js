'use strict';

const { BUILT_IN_DEFINITIONS } = require('./definitions');
const { handlers } = require('./handlers');
const { createToolContext } = require('./tool_context');
const { compactToolDefinition } = require('./schema');
const { resolveToolMeta, runToolRefusal } = require('./metadata');
const { validateProactiveSendMessageArgs } = require('./handlers/messaging');
const { normalizeScheduleTriggerConfig, resolveTaskTriggerArgs } = require('./handlers/tasks');
const {
  executeIntegratedTool,
  getIntegratedToolDefinitions,
} = require('../integrated_tools');
const { isSystemOneEnabled } = require('../system_one');
const { checkPublicToolCall, getPublicRunScope } = require('../../messaging/public_audience');

function getAvailableTools(app, options = {}) {
  const tools = [
    ...BUILT_IN_DEFINITIONS.filter((tool) => !tool.availableWhen || tool.availableWhen(options)),
    ...getIntegratedToolDefinitions(),
  ];

  const skillRunner = app?.locals?.skillRunner;
  if (skillRunner && !options.publicScope) tools.push(...skillRunner.getToolDefinitions({ userId: options.userId }));
  const integrationManager = app?.locals?.integrationManager;
  const publicScope = options.publicScope || null;
  if (integrationManager && publicScope) {
    // A public run uses the platform's own connection, so its integration
    // tools do not depend on which apps the owner connected for chat.
    tools.push(...integrationManager.getProviderToolDefinitions(publicScope.integration.providerKey));
  } else if (integrationManager && options.userId != null) {
    const integrationTools = integrationManager.getToolDefinitions(options.userId, options.agentId || null) || [];
    tools.push(...integrationTools);
  }

  // browser_act runs on a SystemOne model, so it is only offered while SystemOne is on.
  let visibleTools = isSystemOneEnabled(options.userId, options.agentId || null)
    ? tools
    : tools.filter((tool) => tool.name !== 'browser_act');
  if (options.userId != null) {
    try {
      const { getDelegationTargets, resolveAgentId } = require('../../agents/manager');
      const agentId = resolveAgentId(options.userId, options.agentId || null);
      if (
        options.triggerSource === 'agent_delegation'
        || getDelegationTargets(options.userId, agentId).length === 0
      ) {
        visibleTools = visibleTools.filter((tool) => tool.name !== 'delegate_to_agent');
      }
    } catch {
      // If agent policy cannot be resolved, keep tool discovery resilient.
    }
  }

  const compacted = visibleTools
    .map((tool) => compactToolDefinition(tool, options))
    .filter(Boolean);
  if (publicScope) {
    return compacted.filter((tool) => publicScope.toolNames.has(tool.name));
  }
  if (options.names && Array.isArray(options.names)) {
    const allow = new Set(options.names);
    return compacted.filter((tool) => allow.has(tool.name));
  }
  return compacted;
}

function acquireComputerControl(ctx, toolName) {
  const prerequisites = resolveToolMeta(toolName).prerequisites;
  if (!prerequisites.includes('computer') && !prerequisites.includes('desktop')) return;
  const manager = ctx.runtime();
  if (manager && typeof manager.acquireControl === 'function') {
    manager.acquireControl(
      ctx.userId,
      'agent',
      String(ctx.runId || ctx.stepId || ctx.agentId),
      { deviceTarget: ctx.deviceTarget },
    );
  }
}

// MCP servers and skills own whatever names the built-in registry does not.
async function executeExternalTool(toolName, args, ctx) {
  const { agentId, engine, mcp, runId, sk, userId } = ctx;
  const mcpManager = mcp();
  if (mcpManager) {
    let mcpResult = null;
    try {
      mcpResult = await mcpManager.callToolByName(toolName, args, userId, { agentId });
    } catch (mcpErr) {
      return { error: mcpErr.message, tool: toolName, source: 'mcp' };
    }
    if (mcpResult !== null) return mcpResult;
  }

  const skillRunner = sk();
  if (skillRunner) {
    const skillResult = await skillRunner.executeTool(toolName, args, { userId, agentId, runId });
    if (skillResult !== null) return skillResult;
  }

  // Recoverable dead end: point the model at the real catalog instead
  // of leaving it to guess the same wrong name again.
  let suggestions = [];
  try {
    const search = engine?.searchToolsForRun?.(runId, toolName);
    suggestions = (search?.results || []).map((tool) => tool.name);
  } catch {
    // Suggestions are best-effort; the error below is still actionable.
  }
  return {
    error: `Unknown tool: ${toolName}. It is not part of this run's toolset.`,
    recovery: suggestions.length > 0
      ? `Closest available tools: ${suggestions.join(', ')}. Activate what you need with activate_tools, then retry with the exact name.`
      : 'Use search_tools with a capability description, activate the result with activate_tools, then retry with the exact name.',
  };
}

async function executeTool(toolName, args, context, engine) {
  const runMeta = engine?.getRunMeta?.(context.runId);
  if (runMeta) {
    const refusal = runToolRefusal(runMeta.toolCatalog, runMeta.session?.options || {}, toolName, args);
    if (refusal) return { error: refusal, blocked: true };
  }
  const publicScope = getPublicRunScope(context.runId);
  if (publicScope) {
    const refusal = checkPublicToolCall(publicScope, toolName, args);
    if (refusal) return { error: refusal };
  }
  const ctx = createToolContext(toolName, context, engine, publicScope);

  // The runtime replaced runaway streamed arguments with this marker; the
  // call must fail with the reason rather than run on empty input.
  if (typeof args?._discarded === 'string') {
    return { success: false, error: args._discarded };
  }

  acquireComputerControl(ctx, toolName);

  const integrationManager = ctx.integrations();
  if (integrationManager) {
    const integrationResult = await integrationManager.executeTool(
      ctx.userId,
      toolName,
      args,
      ctx.agentId,
      {
        signal: ctx.signal,
        triggerSource: ctx.triggerSource,
        taskId: ctx.taskId,
        scheduledAt: ctx.scheduledAt,
        publicScope,
      },
    );
    // no_provider_support means official integrations do not own this tool, so
    // it falls through to the built-in, MCP, and skill dispatch below.
    if (integrationResult !== null && integrationResult?.error !== 'no_provider_support') {
      return integrationResult;
    }
  }

  const runtimeManager = ctx.runtime();
  const integratedToolResult = await executeIntegratedTool(toolName, args, {
    userId: ctx.userId,
    agentId: ctx.agentId,
    app: ctx.app,
    cliExecutor: runtimeManager && typeof runtimeManager.getCommandExecutorForUser === 'function'
      ? await runtimeManager.getCommandExecutorForUser(ctx.userId, { deviceTarget: ctx.deviceTarget })
      : null,
    workspaceManager: ctx.wc(),
    artifactStore: ctx.artifactStore,
    signal: ctx.signal,
  });
  if (integratedToolResult !== null) return integratedToolResult;

  const handler = Object.hasOwn(handlers, toolName) ? handlers[toolName] : null;
  if (handler) return handler(args, ctx);
  return executeExternalTool(toolName, args, ctx);
}

module.exports = {
  getAvailableTools,
  executeTool,
  validateProactiveSendMessageArgs,
  resolveTaskTriggerArgs,
  normalizeScheduleTriggerConfig,
};
