'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { compactToolResult, toRetainedText } = require('../toolResult');
const { coerceToolArgs, missingRequiredArgs } = require('../tools/coerce_args');
const { resolveToolResultLimits } = require('../loopPolicy');
const { sanitizeModelOutput } = require('../outputSanitizer');
const {
  classifyToolExecution,
  gatheredNewEvidence,
  inferToolFailureMessage,
} = require('../toolEvidence');
const { recordToolOutput } = require('../../security/run_trust');
const { getCategoryForTool } = require('../../security/tool_categories');
const { scrubInvisible, scrubInvisibleDeep } = require('../../../utils/untrusted_text');
const { scheduleToolCalls } = require('../loop/tool_scheduler');
const { createServiceLogger } = require('../../../utils/logger');
const { globalHooks } = require('../hooks');
const { renderFragment } = require('../prompts/registry');
const { parseTestOutput } = require('../test_output');
const {
  isParallelSafeCall,
  isReadOnlyCall,
  resolveToolMeta,
  runToolRefusal,
} = require('../tools/metadata');
const { EVENT_TYPES } = require('./events/event_types');
const { argsDigest, redactArgs } = require('./events/redact');
const { noteChangedPath } = require('./task_state');
const { reviewOperation } = require('./operations');
const { ensureCheckpoint, recordMutation } = require('./workspace_checkpoint');
const { fetchWorkspaceFileArgs } = require('../../files/workspace_file_args');

const logger = createServiceLogger('Runtime');

// A send_message purpose the model declares as the end of its work.
const TERMINAL_SEND_PURPOSES = new Set(['final_result', 'blocker', 'no_response']);

// Saves a payload the compacted tool result had to cut, so the model can read
// the rest with read_artifact instead of stopping at the cut.
function retainFullResult(session, call, stepId, payload) {
  const store = session.app?.locals?.artifactStore;
  if (!store) return null;
  const text = toRetainedText(payload);
  try {
    const artifact = store.createTextArtifact(session.userId, {
      kind: 'tool-result',
      filenameBase: call.name,
      contentType: 'text/plain; charset=utf-8',
      content: text,
      metadata: { runId: session.runId, stepId, tool: call.name },
    });
    return { artifactId: artifact.artifactId, totalLines: text.split('\n').length };
  } catch (error) {
    logger.warn('Could not retain a cut tool result:', error?.message || error);
    return null;
  }
}

function wireToolCall(call) {
  return call.raw?.function?.name
    ? call.raw
    : {
      id: call.id,
      type: 'function',
      function: { name: call.name, arguments: JSON.stringify(call.arguments || {}) },
    };
}

// What a send_message put in front of the user, for the run's terminal answer.
function sentMessageText(session, call, result) {
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
    const delivery = session.engine.getRunMeta(session.runId)?.delivery;
    if (delivery) delivery.noResponse = true;
    return '';
  }
  return sent;
}

function publish(session, eventType, payload, extra = {}) {
  return session.eventBus.publish({
    runId: session.runId,
    userId: session.userId,
    agentId: session.agentId,
    eventType,
    payload,
    ...extra,
  });
}

/**
 * The policy gate. Permission lives here and not in the model: the model may
 * propose a call, but nothing it read can raise what the call is allowed to do.
 * Repeats are stopped here too, so neither ever reaches a tool.
 */
// What this run may do at all, checked for every call. Hiding a tool from the model
// is not a limit: a model can name any tool.
function dispatchRefusal(session, planned) {
  const { call, meta, isReadOnly } = planned;
  const { engine, runId, options } = session;
  const runMeta = engine.getRunMeta(runId);
  const refusal = runToolRefusal(runMeta?.toolCatalog, options, call.name, call.arguments);
  if (refusal) return refusal;
  const touchesWorkspace = meta.stateScope === 'workspace' || meta.group === 'shell' || call.name === 'delegate_to_agent';
  if (!isReadOnly && touchesWorkspace && engine.hasWritingSubagent?.(runId)) {
    return 'A sub-agent of this run is changing the workspace. Wait for it before changing anything.';
  }
  // Named without being turned on: there is no reason to spend a turn on that.
  if (!runMeta?.activeTools?.some((tool) => tool?.name === call.name)) engine.activateToolsForRun?.(runId, [call.name]);
  return null;
}

async function reviewCall(session, planned, stepIndex, stepId) {
  const { call, meta, isReadOnly, fingerprint } = planned;
  const { engine, runId, userId, agentId } = session;
  const refusal = dispatchRefusal(session, planned);
  if (refusal) {
    publish(session, EVENT_TYPES.PERMISSION_DECISION, { tool: call.name, decision: 'deny', by: 'run_limits' }, { stepId });
    return { allowed: false, errorMessage: refusal, result: { error: refusal, blocked: true } };
  }
  // A call without an argument its tool requires is a mistake in that call
  // alone: it is answered here, before anything runs, so it never counts
  // against the tool. A discarded call carries its own reason to the tool.
  const missing = typeof call.arguments?._discarded === 'string'
    ? []
    : missingRequiredArgs(call.arguments, planned.definition?.parameters);
  if (missing.length) {
    const sent = Object.keys(call.arguments || {});
    const reason = `${call.name} needs ${missing.join(' and ')}, which this call left out`
      + `${sent.length ? ` (it sent ${sent.join(', ')})` : ''}. Nothing ran; send the call again with ${missing.length > 1 ? 'them' : 'it'}.`;
    publish(session, EVENT_TYPES.TOOL_SUPPRESSED, {
      tool: { name: call.name, call_fingerprint: fingerprint },
      reason: 'missing_arguments',
    }, { stepId });
    return { allowed: false, errorMessage: reason, result: { error: reason } };
  }
  const repeat = reviewOperation(session, planned);
  if (repeat) {
    publish(session, EVENT_TYPES.TOOL_SUPPRESSED, {
      tool: { name: call.name, call_fingerprint: fingerprint },
      reason: repeat.reason,
    }, { stepId });
    return { allowed: false, suppressed: repeat.completed, errorMessage: repeat.completed ? null : repeat.message, result: { status: repeat.reason, reason: repeat.message } };
  }
  const trust = engine.getRunMeta(runId)?.trust || null;
  const category = getCategoryForTool(call.name, call.arguments);

  const hookResult = await globalHooks.run('before_tool_call', {
    runId,
    toolName: call.name,
    toolArgs: call.arguments,
    userId,
    agentId,
    trust,
  });
  if (category || hookResult?.block === true) {
    publish(session, EVENT_TYPES.PERMISSION_DECISION, {
      tool: call.name,
      category,
      decision: hookResult?.block === true ? 'deny' : 'allow',
      by: hookResult?.blocked_by || (hookResult?.approved ? 'owner_approval' : 'policy'),
      tainted: Boolean(trust?.taintSources?.size),
    }, { stepId });
  }
  if (hookResult?.block === true) {
    const reason = hookResult.reason || 'Blocked by policy hook';
    return { allowed: false, errorMessage: reason, result: { error: reason, blocked: true } };
  }

  const guard = engine.getRunMeta(runId)?.repetitionGuard;
  if (!guard) return { allowed: true };

  // Only a remote service fails the same way whatever it is asked: a quota, an
  // outage, a refused account. A tool on the agent's own computer fails because
  // of what it was asked, so its calls are judged one at a time.
  const resting = meta.latencyClass === 'remote' ? guard.toolResting(call.name) : null;
  if (resting) {
    // A wait is worth naming only when the service named it: otherwise the model
    // sleeps it out and repeats a call that cannot work.
    const when = resting.serviceWait
      ? `The service asked to wait about ${Math.ceil(resting.retryInMs / 1000)} seconds.`
      : 'Waiting will not change that.';
    const reason = `${call.name} failed ${resting.count} times in a row with the same error, whatever it was asked: ${resting.failure} `
      + `${when} Do not call it again for this; use another way or tell the owner what is blocked.`;
    publish(session, EVENT_TYPES.TOOL_SUPPRESSED, {
      tool: { name: call.name, call_fingerprint: fingerprint },
      reason: 'tool_resting',
    }, { stepId });
    return { allowed: false, errorMessage: reason, result: { status: 'blocked', reason } };
  }

  const readScope = isReadOnly ? meta.stateScope : null;
  // A repeatable read is what polling looks like: what it reads can change without
  // this run doing anything, so it is only stopped when it fails.
  const blockedAsRead = isReadOnly && !meta.repeatable;
  if (guard.shouldBlock(call.name, call.arguments, { readOnly: blockedAsRead, stateScope: readScope })) {
    const priorFailure = guard.lastFailure(call.name, call.arguments, readScope);
    const reason = priorFailure
      ? `This exact call already failed twice with: ${priorFailure}`
      : 'The same read-only call already returned an unchanged result twice.';
    publish(session, EVENT_TYPES.TOOL_SUPPRESSED, {
      tool: { name: call.name, call_fingerprint: fingerprint },
      reason: priorFailure ? 'repeated_failure' : 'unchanged_result',
    }, { stepId });
    return { allowed: false, errorMessage: reason, result: { status: 'blocked', reason } };
  }

  if (isReadOnly && meta.known && !meta.repeatable) {
    const prior = guard.claimRead(fingerprint, stepIndex);
    if (prior) {
      publish(session, EVENT_TYPES.TOOL_SUPPRESSED, {
        tool: { name: call.name, call_fingerprint: fingerprint },
        reason: 'duplicate_without_state_change',
        previous_step: prior.stepIndex,
      }, { stepId });
      return {
        allowed: false,
        suppressed: true,
        result: {
          status: 'suppressed',
          reason: `This exact call already ran as step ${prior.stepIndex} and nothing it depends on has changed, so that result stands. If it can change on its own, such as a file a running process writes, call it again.`,
        },
      };
    }
    planned.claimedRead = true;
  }
  return { allowed: true };
}

function executeCall(session, call, stepId) {
  const { engine, runId, userId, agentId, options } = session;
  return engine.executeTool(call.name, call.arguments, {
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
    source: options.source || null,
    chatId: options.chatId || null,
    isGroup: options.context?.socialIntelligence?.isGroup === true,
    senderId: options.context?.socialIntelligence?.message?.sender || null,
    inboundMessage: options.context?.socialIntelligence?.message || null,
    taskId: options.taskId || null,
    scheduledAt: options.scheduledAt || null,
    delivery: engine.getRunMeta(runId)?.delivery || null,
    stageProactiveMessages: options.stageProactiveMessages === true,
    allowMultipleProactiveMessages: options.allowMultipleProactiveMessages === true
      || options.allow_multiple_messages === true,
    allowExternalSideEffects: options.allowExternalSideEffects === true,
    signal: session.getActiveSignal(),
  });
}

function observeOutcome(session, planned, result, reportedFailure, blocked) {
  const { call, meta, isReadOnly, fingerprint } = planned;
  const guard = session.engine.getRunMeta(session.runId)?.repetitionGuard;
  if (!guard || blocked) return null;
  if (planned.claimedRead && reportedFailure) guard.releaseRead(fingerprint);
  const observed = guard.observe(call.name, call.arguments, result, reportedFailure, {
    stateScope: isReadOnly ? meta.stateScope : null,
  });
  // A write that came out exactly like the last one changed nothing, so the
  // reads that depend on it still stand.
  const repeated = !isReadOnly && Number(observed?.unchangedCount) >= 2;
  if (!isReadOnly && !repeated) {
    guard.noteStateChanged(meta.stateScope);
    // Sub-agents work in the same workspace.
    if (meta.group === 'agents') guard.noteStateChanged('workspace');
  } else if (meta.sideEffect === 'navigation' && !repeated) {
    guard.noteStateChanged(meta.stateScope);
  }
  return observed;
}

async function runToolCall(session, planned) {
  const { engine, runId, userId } = session;
  const { call, definition, meta } = planned;
  const stepId = randomUUID();
  const started = Date.now();
  session.stepIndex += 1;
  const { stepIndex } = session;
  const stepType = engine.getStepType?.(call.name) || 'tool';
  // What is approved, logged, and run must be what a person can read, in the
  // types the tool declared.
  call.arguments = coerceToolArgs(scrubInvisibleDeep(call.arguments || {}), definition?.parameters);
  const toolArgs = call.arguments;
  const trust = engine.getRunMeta(runId)?.trust || null;
  const guard = engine.getRunMeta(runId)?.repetitionGuard;
  planned.isReadOnly = isReadOnlyCall(meta, toolArgs);
  planned.fingerprint = guard
    ? guard.fingerprint(call.name, toolArgs, meta.stateScope)
    : argsDigest({ name: call.name, args: toolArgs });

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
  const toolIdentity = {
    name: call.name,
    family: definition?.family || meta.group,
    group: meta.group,
    read_only: planned.isReadOnly,
    call_fingerprint: planned.fingerprint,
    args_digest: argsDigest(toolArgs),
  };
  const selection = session.selection?.get(call.name) || null;
  const callEvent = publish(session, EVENT_TYPES.TOOL_CALL, {
    tool: { ...toolIdentity, args_redacted: redactArgs(toolArgs) },
    selection: selection ? { rank: selection.rank, source: selection.source, score: selection.score } : null,
    step_index: stepIndex,
    iteration: session.iterations,
  }, { stepId, parentEventId: session.lastModelEventId || null });
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
  let suppressed = false;
  try {
    const review = await reviewCall(session, planned, stepIndex, stepId);
    if (review.allowed) {
      // Rollback undoing itself would only confuse what the run owns.
      const tracked = !planned.isReadOnly && (meta.group === 'files' || meta.group === 'shell')
        && call.name !== 'workspace_rollback';
      const started = tracked ? await ensureCheckpoint(session, call) : null;
      try {
        const files = await fetchWorkspaceFileArgs({
          userId,
          args: call.arguments,
          fileArgs: meta.fileArgs,
          workspace: session.app?.locals?.computerWorkspaceManager,
          artifactStore: session.app?.locals?.artifactStore,
          deviceTarget: session.deviceTarget,
          signal: session.getActiveSignal(),
        });
        if (files.error) {
          errorMessage = files.error;
          result = { error: files.error };
        } else {
          result = await executeCall(session, { ...call, arguments: files.args }, stepId);
        }
      } finally {
        if (started) await recordMutation(session, started);
      }
    } else {
      ({ result } = review);
      errorMessage = review.errorMessage || null;
      suppressed = review.suppressed === true;
      blocked = true;
    }
  } catch (error) {
    errorMessage = error?.message || String(error);
    result = { error: errorMessage };
  }

  // Tools report most failures in the result rather than by throwing.
  const reportedFailure = errorMessage || suppressed ? '' : inferToolFailureMessage(call.name, result);
  if (reportedFailure) errorMessage = reportedFailure;
  const success = !errorMessage;
  const elapsed = Date.now() - started;

  if (!blocked) recordToolOutput(trust, call.name);
  if (success && !blocked && !planned.isReadOnly && meta.group === 'files') noteChangedPath(session, toolArgs);

  const execution = classifyToolExecution(call.name, toolArgs, result, errorMessage, definition);
  if (!blocked && !planned.isReadOnly) {
    session.evidence = { ...session.evidence, lastActionFailed: success ? null : `${call.name}: ${String(errorMessage).slice(0, 200)}` };
  }
  // A blocked call never ran; observing it would reset the streak and let the
  // next identical call through.
  const observed = observeOutcome(session, planned, result, reportedFailure || (errorMessage && !blocked ? errorMessage : ''), blocked);
  // A mutation repeated with identical arguments and an identical result
  // changed nothing: the first call already made that change.
  const repeatedMutation = execution.stateChanged && Number(observed?.unchangedCount) >= 2;
  const progressed = !blocked && !repeatedMutation
    && (execution.stateChanged || gatheredNewEvidence(execution, observed));

  let testResult = result?.test_result || null;
  if (!testResult && meta.group === 'shell') {
    testResult = parseTestOutput({
      command: toolArgs.command,
      stdout: result?.stdout,
      stderr: result?.stderr,
    });
  }
  if (testResult) {
    session.evidence = { ...session.evidence, lastTestFailed: testResult.failed > 0 ? testResult.summary : null };
    session.lastCheck = `${String(toolArgs.command || result?.command || call.name).slice(0, 120)}: ${testResult.summary}`;
  }

  const compacted = compactToolResult(
    call.name,
    toolArgs,
    repeatedMutation
      ? { ...result, repeated_call: 'Identical to your previous call: same arguments, same result, nothing changed.' }
      : result,
    {
      ...resolveToolResultLimits(call.name, session.guards.policy, definition),
      retainFullResult: (payload) => retainFullResult(session, call, stepId, payload),
    },
  );
  const commandArtifact = result?.outputArtifact;

  db.prepare(
    `UPDATE agent_steps
     SET status = ?, result = ?, error = ?, screenshot_path = ?, completed_at = datetime('now')
     WHERE id = ?`,
  ).run(
    // Cut off by a restart or a stop, it may or may not have taken effect.
    success ? 'completed' : (session.getActiveSignal?.()?.aborted ? 'interrupted' : 'failed'),
    JSON.stringify(call.name === 'execute_command' ? compacted : (result ?? null)).slice(0, 20000),
    errorMessage,
    result?.screenshotPath || null,
    stepId,
  );

  const commandMs = Number(result?.durationMs);
  publish(session, EVENT_TYPES.TOOL_RESULT, {
    tool: {
      ...toolIdentity,
      result_bytes: Buffer.byteLength(JSON.stringify(result ?? null) || ''),
      result_compacted_bytes: Buffer.byteLength(typeof compacted === 'string' ? compacted : JSON.stringify(compacted) || ''),
    },
    duration_ms: elapsed,
    // The receipt: what this call actually did, for the run's task outcome.
    receipt: {
      mutating: !blocked && !planned.isReadOnly,
      ok: !blocked && success,
      ...(testResult ? {
        test: {
          runner: testResult.runner,
          passed: testResult.passed,
          failed: testResult.failed,
          // A report of passes means little from a command that itself failed.
          exit_ok: success && (result?.exitCode === undefined || result.exitCode === 0),
        },
      } : {}),
    },
    // What the command itself took is the tool's time; the rest is the sandbox.
    ...(meta.group === 'shell' && Number.isFinite(commandMs) ? { sandbox_ms: Math.max(0, elapsed - commandMs) } : {}),
    ...(commandArtifact?.artifactId ? { artifact: { id: commandArtifact.artifactId, bytes: commandArtifact.byteSize } } : {}),
    progressed,
    outcome: {
      status: suppressed ? 'suppressed' : (success ? 'success' : 'failed'),
      error: errorMessage ? String(errorMessage).slice(0, 300) : null,
    },
    privacy: { content_stored: false, redaction_policy: 'metadata-default' },
  }, { stepId, parentEventId: callEvent?.eventId || null });
  engine.emit(userId, 'run:tool_end', {
    runId,
    stepId,
    toolName: call.name,
    result: compacted,
    status: success ? 'completed' : 'failed',
    error: errorMessage,
  });
  session.progressBroker.noteToolFinished(call.name);

  const sentMessage = call.name === 'send_message' && success ? sentMessageText(session, call, result) : '';
  return {
    call,
    meta,
    success,
    suppressed,
    progressed,
    execution,
    sentMessage,
    // A text reply in the very chat a messaging run answers. Files can come as a
    // series of sends, so a reply that carries one does not end the run.
    answeredOrigin: Boolean(
      success
      && result?.originDelivery === true
      && session.triggerSource === 'messaging'
      && !call.arguments?.media_path
      && !call.arguments?.media_url,
    ),
    fingerprint: planned.fingerprint,
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
    // Private reasoning goes back to the model that wrote it, so it keeps its
    // train of thought across tool calls. It never reaches a log.
    ...(decision.reasoningState ? { reasoningState: decision.reasoningState } : {}),
    ...(decision.providerContentBlocks ? { providerContentBlocks: decision.providerContentBlocks } : {}),
  });

  const plannedCalls = decision.toolCalls.map((call) => {
    const catalog = engine.getRunMeta(runId)?.toolCatalog || session.tools;
    const definition = catalog.find((tool) => tool?.name === call.name) || null;
    return { call, definition, meta: resolveToolMeta(call.name, definition) };
  });

  const outcomes = [];
  await scheduleToolCalls(plannedCalls, {
    isParallelSafe: (planned) => isParallelSafeCall(planned.meta, planned.call.arguments),
    execute: (planned) => runToolCall(session, planned),
    maxParallel: session.options.maxParallelToolCalls,
    commit: async (outcome) => {
      outcomes.push(outcome);
      session.toolExecutions.push(outcome.execution);
      session.messages.push(outcome.toolMessage);
    },
  });

  // Newly activated schemas only reach the model if the active set is re-read.
  const activeTools = engine.getActiveTools?.(runId);
  if (Array.isArray(activeTools) && activeTools.length) session.tools = activeTools;

  // Coding guidance costs nothing until a run actually touches the workspace.
  if (!session.codingGuidanceSent && outcomes.some((outcome) => ['files', 'shell'].includes(outcome.meta.group))) {
    session.codingGuidanceSent = true;
    session.messages.push({ role: 'system', content: renderFragment('capabilities/coding.md') });
  }

  // A turn that only delivers a message the model marked as the end of its
  // work, or that only replies in the chat the run answers, is that run's
  // answer: the message already reached the user, and a status that is not the
  // end goes through send_interim_update. Without this every chat reply cost a
  // second model call that could only repeat it.
  const terminalSend = outcomes.length > 0 && outcomes.every((outcome) => (
    outcome.call.name === 'send_message'
    && outcome.success
    && (outcome.answeredOrigin
      || TERMINAL_SEND_PURPOSES.has(String(outcome.call.arguments?.purpose || '').trim().toLowerCase()))
  ));

  // A reply sent in the run's own chat stays the run's last word only while
  // the model does nothing else; once it works on, the final answer is new.
  const delivery = engine.getRunMeta(runId)?.delivery;
  if (delivery && terminalSend) delivery.lastWordSent = true;
  else if (delivery?.lastWordSent && !outcomes.some((outcome) => outcome.call.name === 'send_message')) {
    delivery.lastWordSent = false;
  }

  return {
    progressed: outcomes.some((outcome) => outcome.progressed),
    allFailed: outcomes.length > 0 && outcomes.every((outcome) => !outcome.success && !outcome.suppressed),
    actionKey: outcomes.map((outcome) => outcome.fingerprint).sort().join(','),
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
