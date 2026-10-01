'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { compactToolResult } = require('../toolResult');
const { resolveToolResultLimits } = require('../loopPolicy');
const { sanitizeModelOutput } = require('../outputSanitizer');
const {
  classifyToolExecution,
  gatheredNewEvidence,
  inferToolFailureMessage,
} = require('../toolEvidence');
const { globalHooks } = require('../hooks');
const { recordToolOutput } = require('../../security/run_trust');
const { scrubInvisible, scrubInvisibleDeep } = require('../../../utils/untrusted_text');
const { scheduleToolCalls } = require('../loop/tool_scheduler');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');

// Control tools that never change anything outside the run, so Plan mode lets
// them through.
const PLAN_MODE_SAFE_CONTROL_TOOLS = new Set([
  'search_tools',
  'activate_tools',
  'request_user_input',
  'send_interim_update',
]);

// A send_message purpose the model declares as the end of its work.
const TERMINAL_SEND_PURPOSES = new Set(['final_result', 'blocker', 'no_response']);

function wireToolCall(call) {
  return call.raw?.function?.name
    ? call.raw
    : {
      id: call.id,
      type: 'function',
      function: { name: call.name, arguments: JSON.stringify(call.arguments || {}) },
    };
}

// Bookkeeping the delivery paths and the task runtime read after a
// send_message: what reached the chat, and whether the model chose silence.
function recordSentMessage(session, call, result) {
  const runMeta = session.engine.getRunMeta(session.runId);
  if (!runMeta) return '';
  const sent = String(
    call.arguments?.content
    || call.arguments?.message
    || call.arguments?.text
    || result?.content
    || '',
  ).trim();
  const noResponse = sent === '[NO RESPONSE]'
    || result?.reason === 'no_response'
    || call.arguments?.purpose === 'no_response';
  if (noResponse) {
    runMeta.noResponse = true;
    if (runMeta.deliveryState) runMeta.deliveryState.noResponse = true;
    return '';
  }
  if (!sent) return '';
  runMeta.lastSentMessage = sent;
  runMeta.messagingSent = true;
  if (!Array.isArray(runMeta.sentMessages)) runMeta.sentMessages = [];
  runMeta.sentMessages.push(sent);
  if (result?.staged === true) {
    runMeta.proactiveMessageStaged = true;
    runMeta.stagedProactiveMessage = runMeta.deliveryState?.stagedProactiveMessage || {
      platform: call.arguments?.platform,
      to: call.arguments?.to,
      content: sent,
      purpose: call.arguments?.purpose,
    };
  }
  return sent;
}

async function runToolCall(session, { call, definition, isReadOnly }) {
  const { engine, eventBus, runId, userId, agentId, options } = session;
  const stepId = randomUUID();
  const started = Date.now();
  session.stepIndex += 1;
  const stepIndex = session.stepIndex;
  const stepType = engine.getStepType?.(call.name) || 'tool';
  // What is approved, logged, and run must be what a person can read.
  call.arguments = scrubInvisibleDeep(call.arguments || {});
  const toolArgs = call.arguments;
  const trust = engine.getRunMeta(runId)?.trust || null;

  db.prepare(
    `INSERT INTO agent_steps (
      id, run_id, step_index, type, description, status, tool_name, tool_input, started_at
    ) VALUES (?, ?, ?, ?, ?, 'running', ?, ?, datetime('now'))`,
  ).run(
    stepId,
    runId,
    stepIndex,
    stepType,
    `${call.name}: ${JSON.stringify(toolArgs).slice(0, 200)}`,
    call.name,
    JSON.stringify(toolArgs),
  );
  eventBus.publish({
    runId,
    userId,
    agentId,
    eventType: EVENT_TYPES.TOOL_STARTED,
    stepId,
    payload: { tool: call.name },
    visibility: VISIBILITY.OPERATOR,
  });
  engine.recordRunEvent?.(userId, runId, 'tool_started', {
    stepIndex,
    toolName: call.name,
    toolArgs,
    type: stepType,
  }, { agentId, stepId });
  engine.emit(userId, 'run:tool_start', {
    runId,
    stepId,
    stepIndex,
    toolName: call.name,
    toolArgs,
    type: stepType,
  });
  session.progressBroker.noteToolStarted(call.name);

  let result;
  let errorMessage = null;
  let blocked = false;
  const repetitionGuard = engine.getRunMeta(runId)?.repetitionGuard;
  try {
    if (session.interactionMode === 'plan' && !isReadOnly && !PLAN_MODE_SAFE_CONTROL_TOOLS.has(call.name)) {
      errorMessage = 'Plan mode blocks tools that can mutate state.';
      result = { error: errorMessage, blocked: true, blockedBy: 'cowork_plan_mode' };
      blocked = true;
    } else {
      const hookResult = await globalHooks.run('before_tool_call', {
        runId,
        toolName: call.name,
        toolArgs: call.arguments,
        userId,
        agentId,
        trust,
      });
      if (hookResult?.block === true) {
        errorMessage = hookResult.reason || 'Blocked by policy hook';
        result = { error: errorMessage, blocked: true };
        blocked = true;
      } else if (repetitionGuard?.shouldBlock(call.name, call.arguments, { readOnly: isReadOnly })) {
        const priorFailure = repetitionGuard.lastFailure(call.name, call.arguments);
        errorMessage = priorFailure
          ? `This exact call already failed twice with: ${priorFailure}`
          : 'The same read-only call already returned an unchanged result twice.';
        result = { status: 'blocked', reason: errorMessage };
        blocked = true;
      } else {
        result = await engine.executeTool(call.name, call.arguments, {
          userId,
          agentId,
          runId,
          stepId,
          app: session.app,
          triggerType: session.triggerType,
          triggerSource: session.triggerSource,
          conversationId: session.conversationId,
          deviceTarget: session.deviceTarget,
          workspaceRoot: session.workspaceRoot,
          interactionMode: session.interactionMode,
          source: options.source || null,
          chatId: options.chatId || null,
          isGroup: options.context?.socialIntelligence?.isGroup === true,
          senderId: options.context?.socialIntelligence?.message?.sender || null,
          inboundMessage: options.context?.socialIntelligence?.message || null,
          taskId: options.taskId || null,
          scheduledAt: options.scheduledAt || null,
          deliveryState: options.deliveryState || engine.getRunMeta(runId)?.deliveryState || null,
          stageProactiveMessages: options.stageProactiveMessages === true,
          allowMultipleProactiveMessages: options.allowMultipleProactiveMessages === true
            || options.allow_multiple_messages === true,
          allowExternalSideEffects: options.allowExternalSideEffects === true,
          signal: session.getActiveSignal(),
        });
      }
    }
  } catch (error) {
    errorMessage = error?.message || String(error);
    result = { error: errorMessage };
  }

  // Tools report most failures in the result rather than by throwing.
  const reportedFailure = errorMessage ? '' : inferToolFailureMessage(call.name, result);
  if (reportedFailure) errorMessage = reportedFailure;
  const success = !errorMessage;
  const elapsed = Date.now() - started;

  if (!blocked) recordToolOutput(trust, call.name);

  const execution = classifyToolExecution(call.name, toolArgs, result, errorMessage, definition);
  // A blocked call never ran; observing it would reset the streak and let the
  // next identical call through.
  const observed = blocked
    ? null
    : repetitionGuard?.observe(call.name, call.arguments, result, reportedFailure);
  // A mutation repeated with identical arguments and an identical result
  // changed nothing: the first call already made that change.
  const repeatedMutation = execution.stateChanged && Number(observed?.unchangedCount) >= 2;
  const progressed = !repeatedMutation
    && (execution.stateChanged || gatheredNewEvidence(execution, observed));

  const compacted = compactToolResult(
    call.name,
    toolArgs,
    repeatedMutation
      ? { ...result, repeated_call: 'Identical to your previous call: same arguments, same result, nothing changed.' }
      : result,
    resolveToolResultLimits(call.name, session.guards.policy),
  );
  const commandArtifact = result?.outputArtifact;
  if (commandArtifact?.artifactId) {
    eventBus.publish({
      runId,
      userId,
      agentId,
      eventType: EVENT_TYPES.ARTIFACT_CREATED,
      stepId,
      payload: {
        artifact_id: commandArtifact.artifactId,
        kind: 'command-output',
        byte_size: commandArtifact.byteSize,
        complete: commandArtifact.complete !== false,
      },
      visibility: VISIBILITY.OPERATOR,
    });
  }

  db.prepare(
    `UPDATE agent_steps
     SET status = ?, result = ?, error = ?, screenshot_path = ?, completed_at = datetime('now')
     WHERE id = ?`,
  ).run(
    success ? 'completed' : 'failed',
    JSON.stringify(call.name === 'execute_command' ? compacted : (result ?? null)).slice(0, 20000),
    errorMessage,
    result?.screenshotPath || null,
    stepId,
  );
  eventBus.publish({
    runId,
    userId,
    agentId,
    eventType: success ? EVENT_TYPES.TOOL_COMPLETED : EVENT_TYPES.TOOL_FAILED,
    stepId,
    payload: { tool: call.name, success, error: errorMessage, elapsed_ms: elapsed },
    visibility: VISIBILITY.OPERATOR,
  });
  engine.recordRunEvent?.(userId, runId, success ? 'tool_completed' : 'tool_failed', {
    toolName: call.name,
    status: success ? 'completed' : 'failed',
    durationMs: elapsed,
    error: errorMessage,
  }, { agentId, stepId });
  engine.emit(userId, 'run:tool_end', {
    runId,
    stepId,
    toolName: call.name,
    result: compacted,
    status: success ? 'completed' : 'failed',
    error: errorMessage,
  });
  session.progressBroker.noteToolFinished(call.name);

  const sentMessage = call.name === 'send_message' && success ? recordSentMessage(session, call, result) : '';
  return {
    call,
    success,
    progressed,
    execution,
    sentMessage,
    toolMessage: {
      role: 'tool',
      name: call.name,
      tool_call_id: call.id,
      content: scrubInvisible(typeof compacted === 'string' ? compacted : JSON.stringify(compacted)),
    },
  };
}

/**
 * Runs one assistant turn's tool calls and appends the calls and results to
 * the transcript. Read-only calls overlap only while they are contiguous in
 * model order; a mutation is a barrier, so read -> edit -> verify-read keeps
 * the order the model asked for.
 */
async function executeToolTurn(session, decision) {
  const { engine, runId } = session;
  session.messages.push({
    role: 'assistant',
    content: decision.content ? sanitizeModelOutput(decision.content, { model: session.model.model }) : '',
    tool_calls: decision.toolCalls.map(wireToolCall),
  });

  const plannedCalls = decision.toolCalls.map((call) => {
    const definition = session.tools.find((tool) => tool?.name === call.name) || null;
    return {
      call,
      definition,
      isReadOnly: Boolean(engine.isReadOnlyToolCall?.(wireToolCall(call), definition)),
    };
  });

  const outcomes = [];
  await scheduleToolCalls(plannedCalls, {
    isParallelSafe: (planned) => planned.isReadOnly,
    execute: (planned) => runToolCall(session, planned),
    maxParallel: session.options.maxParallelToolCalls,
    commit: async (outcome) => {
      outcomes.push(outcome);
      session.toolExecutions.push(outcome.execution);
      session.messages.push(outcome.toolMessage);
    },
  });

  // Newly activated schemas only reach the model if the active set is re-read.
  if (outcomes.some((outcome) => outcome.call.name === 'activate_tools' && outcome.success)) {
    const activeTools = engine.getActiveTools?.(runId);
    if (Array.isArray(activeTools) && activeTools.length) session.tools = activeTools;
  }

  // A turn that only delivers a message the model marked as the end of its
  // work is that run's answer; the message already reached the user.
  const terminalSend = outcomes.length > 0 && outcomes.every((outcome) => (
    outcome.call.name === 'send_message'
    && outcome.success
    && TERMINAL_SEND_PURPOSES.has(String(outcome.call.arguments?.purpose || '').trim().toLowerCase())
  ));

  return {
    progressed: outcomes.some((outcome) => outcome.progressed),
    allFailed: outcomes.length > 0 && outcomes.every((outcome) => !outcome.success),
    awaitingInput: engine.getRunMeta(runId)?.awaitingInput || null,
    // A no_response send is the model choosing silence, which the delivery
    // paths already know as the [NO RESPONSE] answer.
    terminalAnswer: terminalSend
      ? outcomes.map((outcome) => outcome.sentMessage).filter(Boolean).join('\n\n') || '[NO RESPONSE]'
      : null,
  };
}

module.exports = {
  executeToolTurn,
};
