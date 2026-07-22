'use strict';

const { v4: uuidv4 } = require('uuid');
const db = require('../../../db/database');
const { globalHooks } = require('../hooks');
const { summarizeForLog } = require('../logFormat');
const {
  inferToolFailureMessage,
  resolveDeclaredToolAccess,
} = require('../toolEvidence');

function getAvailableTools(_engine, app, options = {}) {
  const { getAvailableTools: loadAvailableTools } = require('../tools');
  return loadAvailableTools(app, options);
}

async function executeTool(engine, toolName, args, context) {
  const { executeTool: runTool } = require('../tools');
  return runTool(toolName, args, context, engine);
}

function isReadOnlyToolCall(toolCall, toolDefinition = null) {
  const name = String(toolCall?.function?.name || '');
  let toolArgs = {};
  try {
    toolArgs = typeof toolCall?.function?.arguments === 'string'
      ? JSON.parse(toolCall.function.arguments || '{}')
      : (toolCall?.function?.arguments || {});
  } catch {
    return false;
  }

  const declaredAccess = resolveDeclaredToolAccess(toolDefinition, toolArgs);
  if (declaredAccess === 'read') return true;
  if (declaredAccess === 'write') return false;

  const readOnly = new Set([
    'read_file',
    'read_files',
    'list_directory',
    'search_files',
    'code_navigate',
    'query_structured_data',
    'memory_recall',
    'memory_read',
    'session_search',
    'web_search',
    'list_tasks',
    'list_skills',
    'list_subagents',
    'read_health_data',
  ]);
  if (name === 'http_request') {
    return String(toolArgs.method || 'GET').toUpperCase() === 'GET';
  }
  return readOnly.has(name);
}

async function executeReadOnlyBatch(engine, toolCalls, context = {}) {
  const {
    userId,
    runId,
    agentId,
    app,
    triggerType,
    triggerSource,
    conversationId,
    startingStepIndex,
    options = {},
  } = context;
  const prepared = [];
  let nextStepIndex = startingStepIndex;
  for (const toolCall of toolCalls) {
    nextStepIndex += 1;
    let toolArgs = {};
    try { toolArgs = JSON.parse(toolCall.function.arguments || '{}'); } catch {}
    const toolName = toolCall.function.name;
    const repetitionGuard = engine.getRunMeta(runId)?.repetitionGuard;
    if (repetitionGuard?.shouldBlock(toolName, toolArgs)) {
      const result = {
        status: 'blocked',
        reason: 'The same read-only call already returned an unchanged result twice.',
      };
      prepared.push({
        toolCall,
        toolName,
        toolArgs,
        stepIndex: nextStepIndex,
        blocked: true,
        result,
        error: result.reason,
      });
      engine.recordRunEvent(userId, runId, 'repetition_blocked', {
        toolName,
        toolArgs,
        parallel: true,
      }, { agentId });
      continue;
    }
    if (globalHooks.has('before_tool_call')) {
      const hookResult = await globalHooks.run('before_tool_call', {
        toolName,
        toolArgs,
        runId,
        userId,
        agentId,
        iteration: context.iteration,
      });
      if (hookResult.block) {
        prepared.push({
          toolCall,
          toolName,
          toolArgs,
          stepIndex: nextStepIndex,
          blocked: true,
          result: { status: 'blocked', reason: hookResult.reason || 'Blocked by policy.', blocked_by: hookResult.blocked_by || 'policy' },
        });
        continue;
      }
      if (hookResult.toolArgs) toolArgs = hookResult.toolArgs;
    }
    const stepId = uuidv4();
    db.prepare(
      `INSERT INTO agent_steps (
        id, run_id, step_index, type, description, status, tool_name, tool_input, started_at
      ) VALUES (?, ?, ?, ?, ?, 'running', ?, ?, datetime('now'))`
    ).run(
      stepId,
      runId,
      nextStepIndex,
      engine.getStepType(toolName),
      `${toolName}: ${JSON.stringify(toolArgs).slice(0, 200)}`,
      toolName,
      JSON.stringify(toolArgs),
    );
    engine.emit(userId, 'run:tool_start', {
      runId,
      stepId,
      stepIndex: nextStepIndex,
      toolName,
      toolArgs,
      type: engine.getStepType(toolName),
    });
    engine.recordRunEvent(userId, runId, 'tool_started', {
      stepIndex: nextStepIndex,
      toolName,
      toolArgs,
      type: engine.getStepType(toolName),
      parallel: true,
    }, { agentId, stepId });
    prepared.push({ toolCall, toolName, toolArgs, stepId, stepIndex: nextStepIndex });
  }
  engine.recordRunEvent(userId, runId, 'parallel_batch_started', {
    toolNames: prepared.map((item) => item.toolName),
    count: prepared.length,
  }, { agentId });
  const results = await Promise.all(prepared.map(async (item) => {
    if (item.blocked) return item;
    const runMeta = engine.getRunMeta(runId);
    if (!runMeta || runMeta.status !== 'running') {
      const result = { status: 'paused', reason: 'Run paused before this read-only call started.' };
      db.prepare(
        `UPDATE agent_steps SET status = 'paused', result = ?, completed_at = datetime('now') WHERE id = ? AND status = 'running'`,
      ).run(JSON.stringify(result), item.stepId);
      return { ...item, result };
    }
    const startedAt = Date.now();
    try {
      const result = await executeTool(engine, item.toolName, item.toolArgs, {
        userId,
        runId,
        agentId,
        app,
        triggerType,
        triggerSource,
        conversationId,
        source: options.source || null,
        chatId: options.chatId || null,
        taskId: options.taskId || null,
        widgetId: options.widgetId || null,
        deliveryState: options.deliveryState || null,
        allowMultipleProactiveMessages: options.allowMultipleProactiveMessages === true,
        allowExternalSideEffects: false,
        signal: runMeta.abortController?.signal,
      });
      const error = inferToolFailureMessage(item.toolName, result);
      const status = error ? 'failed' : 'completed';
      db.prepare(
        `UPDATE agent_steps
         SET status = ?, result = ?, error = ?, screenshot_path = ?, completed_at = datetime('now')
         WHERE id = ?`
      ).run(
        status,
        JSON.stringify(result).slice(0, 20000),
        error || null,
        result?.screenshotPath || null,
        item.stepId,
      );
      engine.emit(userId, 'run:tool_end', {
        runId,
        stepId: item.stepId,
        toolName: item.toolName,
        result,
        error: error || undefined,
        status,
      });
      engine.recordRunEvent(userId, runId, error ? 'tool_failed' : 'tool_completed', {
        toolName: item.toolName,
        status,
        durationMs: Date.now() - startedAt,
        resultPreview: summarizeForLog(result),
        parallel: true,
      }, { agentId, stepId: item.stepId });
      return { ...item, result, error };
    } catch (err) {
      db.prepare(
        `UPDATE agent_steps SET status = 'failed', error = ?, completed_at = datetime('now') WHERE id = ?`
      ).run(err.message, item.stepId);
      engine.emit(userId, 'run:tool_end', {
        runId,
        stepId: item.stepId,
        toolName: item.toolName,
        error: err.message,
        status: 'failed',
      });
      engine.recordRunEvent(userId, runId, 'tool_failed', {
        toolName: item.toolName,
        status: 'failed',
        error: err.message,
        durationMs: Date.now() - startedAt,
        parallel: true,
      }, { agentId, stepId: item.stepId });
      return { ...item, result: { error: err.message }, error: err.message };
    }
  }));
  engine.recordRunEvent(userId, runId, 'parallel_batch_completed', {
    toolNames: results.map((item) => item.toolName),
    failedCount: results.filter((item) => item.error).length,
  }, { agentId });
  return { results, endingStepIndex: nextStepIndex };
}

module.exports = {
  executeReadOnlyBatch,
  executeTool,
  getAvailableTools,
  isReadOnlyToolCall,
};
