'use strict';

const db = require('../../../db/database');
const { sanitizeConversationMessages } = require('../history');
const { sanitizeModelOutput } = require('../outputSanitizer');
const {
  recordModelFailure,
  recordModelSuccess,
  shouldSwitchModel,
} = require('../model_failure_cache');
const { getProviderForUser } = require('../provider_selector');
const { buildBlankOutputGuidance } = require('../loop/blank_recovery');
const { isAbortError } = require('../../../utils/abort');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');
const stateMachine = require('./run_state_machine');
const leases = require('./leases');
const { decisionFromModelResponse, DECISION_KINDS } = require('./decision_engine');
const { isContextOverflowError } = require('./context/context_pressure');
const { getFailureFallbackModelId } = require('./model_fallback');
const { executeToolTurn } = require('./tool_turn');
const { applyTaskModel } = require('./task_model_switch');

const MAX_BLANK_RECOVERIES = 2;
const MAX_TRUNCATION_RETRIES = 2;

function usageTokens(usage) {
  usage = usage || {};
  const input = Number(usage.input_tokens || usage.prompt_tokens || usage.inputTokens || 0) || 0;
  const output = Number(usage.output_tokens || usage.completion_tokens || usage.outputTokens || 0) || 0;
  return Number(usage.total_tokens || usage.totalTokens || 0) || (input + output);
}

// Follow-up messages are steered into a run only while it will still read
// them. Intake closes where the run commits to its answer; a follow-up sent
// after that is refused and starts a run of its own.
function setSteeringIntake(engine, runId, open) {
  const runMeta = engine.getRunMeta(runId);
  if (runMeta) runMeta.steeringClosed = !open;
}

function hasPendingSteering(engine, runId) {
  return Boolean(engine.getRunMeta(runId)?.steeringQueue?.length);
}

// Switches the run to the next model after a provider failure. Returns false
// when there is nothing left to fall back to.
async function switchModel(session, error) {
  const current = session.model;
  const fallbackId = await getFailureFallbackModelId(
    session.userId,
    session.agentId,
    current.modelSelectionId,
    error,
    session.getActiveSignal(),
    session.failedModelIds,
  );
  if (!fallbackId) return false;
  const fallback = await getProviderForUser(
    session.userId,
    session.userMessage,
    session.triggerType === 'subagent',
    fallbackId,
    { ...session.providerStatusConfig, signal: session.getActiveSignal() },
  );
  session.model = {
    provider: fallback.provider,
    providerName: fallback.providerName,
    model: fallback.model,
    modelSelectionId: fallback.modelSelectionId,
  };
  db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
    .run(fallback.modelSelectionId, session.runId);
  return true;
}

// One model request. A context overflow is compacted and retried once; other
// provider failures switch to a fallback model. Returns the model turn, or a
// loop result when the run cannot continue.
async function requestTurn(session) {
  const { engine, eventBus, runId, userId, agentId } = session;
  const signal = session.getActiveSignal();
  let overflowRetried = false;
  while (true) {
    try {
      const turn = await engine.requestModelResponse({
        provider: session.model.provider,
        providerName: session.model.providerName,
        model: session.model.model,
        messages: sanitizeConversationMessages(session.messages),
        tools: session.tools,
        options: { ...session.options, signal, runId, userId, agentId },
        runId,
        iteration: session.iterations,
      });
      recordModelSuccess(userId, agentId, session.model.modelSelectionId);
      return { turn };
    } catch (error) {
      if (isAbortError(error, session.getActiveSignal())) return { aborted: true };
      if (isContextOverflowError(error)) {
        if (overflowRetried || !session.contextPressure.claimOverflowRecovery()) {
          return { result: { type: 'wrap_up', reason: 'context_overflow' } };
        }
        let recovered;
        try {
          recovered = await session.contextPressure.prepare({
            provider: session.model.provider,
            model: session.model.model,
            messages: session.messages,
            tools: session.tools,
            maxOutputTokens: session.options.maxTokens,
            force: true,
            reason: 'provider_overflow',
          });
        } catch (compactionError) {
          if (isAbortError(compactionError, signal)) throw compactionError;
          return { result: { type: 'wrap_up', reason: 'context_overflow' } };
        }
        if (!recovered.changed) return { result: { type: 'wrap_up', reason: 'context_overflow' } };
        session.messages = recovered.messages;
        overflowRetried = true;
        eventBus.publish({
          runId,
          userId,
          agentId,
          eventType: EVENT_TYPES.CONTEXT_OVERFLOW_RECOVERED,
          payload: {
            recovery_count: session.contextPressure.overflowRecoveries,
            before_tokens: recovered.beforeTokens,
            after_tokens: recovered.afterTokens,
          },
          visibility: VISIBILITY.OPERATOR,
        });
        continue;
      }
      recordModelFailure(userId, agentId, session.model.modelSelectionId, error);
      session.failedModelIds.add(session.model.modelSelectionId);
      if (shouldSwitchModel(error) && await switchModel(session, error)) continue;
      throw error;
    }
  }
}

// Pause, stop, and interrupt controls are honored between turns and while a
// turn is in flight. Returns a loop result when the run must end here.
async function honorControls(session, phase) {
  const { engine, runId } = session;
  if (engine.getRunMeta(runId)?.aborted) return { type: 'cancelled' };
  const boundary = await engine.checkpointLifecycle?.(runId, phase, { iteration: session.iterations });
  if (boundary?.action === 'stop' || boundary?.action === 'interrupt') return { type: 'cancelled' };
  return null;
}

/**
 * The agent loop. The model works with tools until it answers without calling
 * one; that answer is what the user receives. The runtime only keeps the loop
 * alive and safe: lifecycle controls, steering, context compaction, provider
 * recovery, and runaway guards.
 */
async function runAgentLoop(session) {
  const { engine, eventBus, runId, userId, agentId, workerId } = session;
  let blankRecoveries = 0;
  let truncationRetries = 0;
  session.baseModelSelectionId = session.model.modelSelectionId;

  while (true) {
    if (engine.getRunMeta(runId)?.aborted) return { type: 'cancelled' };
    if (session.getActiveSignal().aborted) {
      const ended = await honorControls(session, 'signal_boundary');
      if (ended) return ended;
      continue;
    }

    leases.heartbeat(runId, workerId);
    session.progressBroker.noteActivity('loop_tick');
    const run = stateMachine.loadRun(runId);
    if (!run || stateMachine.isTerminal(run)) return { type: 'ended', status: run?.status || 'completed' };

    const control = db.prepare(
      `SELECT action, reason FROM agent_run_controls
       WHERE run_id = ? AND consumed_at IS NULL`,
    ).get(runId);
    if (control?.action === 'pause') {
      const ended = await honorControls(session, 'loop_boundary');
      if (ended) return ended;
      continue;
    }
    if (control?.action === 'stop' || control?.action === 'interrupt') {
      engine.interruptRun?.(runId, control.reason || control.action);
      return { type: 'cancelled' };
    }

    const hookStop = await session.stopForIterationHook(session.iterations + 1);
    if (hookStop) return { type: 'stopped', result: hookStop };

    const stopReason = session.guards.stopReason();
    if (stopReason) return { type: 'wrap_up', reason: stopReason };

    setSteeringIntake(engine, runId, true);
    engine.applyQueuedSteering?.(runId, session.messages, { userId, conversationId: session.conversationId });
    engine.applyQueuedSystemSteering?.(runId, session.messages);

    try {
      const pressure = await session.contextPressure.prepare({
        provider: session.model.provider,
        model: session.model.model,
        messages: session.messages,
        tools: session.tools,
        maxOutputTokens: session.options.maxTokens,
      });
      if (pressure.changed) session.messages = pressure.messages;
    } catch (error) {
      if (isAbortError(error, session.getActiveSignal())) throw error;
      console.warn('[Runtime] Proactive context compaction failed:', error?.message || error);
    }

    session.iterations += 1;
    session.guards.recordModelTurn();
    session.emitPhase('thinking', 'Thinking');
    session.progressBroker.noteActivity('model_started', { iteration: session.iterations });
    eventBus.publish({
      runId,
      userId,
      agentId,
      eventType: EVENT_TYPES.MODEL_STARTED,
      payload: { iteration: session.iterations, model: session.model.modelSelectionId },
      visibility: VISIBILITY.OPERATOR,
    });

    const requested = await requestTurn(session);
    if (requested.aborted) {
      const ended = await honorControls(session, 'model_boundary');
      if (ended) return ended;
      continue;
    }
    if (requested.result) return requested.result;

    const response = requested.turn?.response || {};
    session.totalTokens += usageTokens(response.usage);
    session.progressBroker.noteActivity('model_completed', { iteration: session.iterations });
    const decision = decisionFromModelResponse({
      content: response.content || requested.turn?.streamContent || '',
      toolCalls: response.toolCalls || response.tool_calls || [],
    });

    if (decision.kind === DECISION_KINDS.BLANK) {
      // A blank turn is a provider hiccup, not an answer: nudge, then move to
      // another model, and wrap up only if that keeps happening.
      blankRecoveries += 1;
      if (blankRecoveries > MAX_BLANK_RECOVERIES) return { type: 'wrap_up', reason: 'blank_output' };
      const blankError = new Error('Model returned no content and no tool calls');
      blankError.code = 'MODEL_EMPTY_RESPONSE';
      recordModelFailure(userId, agentId, session.model.modelSelectionId, blankError);
      session.failedModelIds.add(session.model.modelSelectionId);
      await switchModel(session, blankError);
      session.messages.push({ role: 'system', content: buildBlankOutputGuidance(session.toolExecutions) });
      continue;
    }

    if (decision.kind === DECISION_KINDS.ANSWER) {
      // Text cut off at the token limit is an unfinished thought, not an
      // answer; ask for a real continuation a couple of times.
      if (response.truncated && truncationRetries < MAX_TRUNCATION_RETRIES) {
        truncationRetries += 1;
        session.messages.push({
          role: 'system',
          content: 'Your previous output stopped at the token limit mid-thought and was discarded. Keep reasoning brief, then call the tools you need or give a complete answer that fits.',
        });
        continue;
      }
      const content = sanitizeModelOutput(decision.content, { model: session.model.model });
      session.messages.push({ role: 'assistant', content });
      // Follow-ups that arrived while the model wrote this are answered before
      // anything is delivered.
      if (hasPendingSteering(engine, runId)) continue;
      setSteeringIntake(engine, runId, false);
      return { type: 'answer', content };
    }

    truncationRetries = 0;
    const toolTurn = await executeToolTurn(session, decision);
    session.guards.recordToolTurn(toolTurn);
    await applyTaskModel(session, decision.toolCalls);
    if (toolTurn.terminalAnswer !== null && !hasPendingSteering(engine, runId)) {
      setSteeringIntake(engine, runId, false);
      return { type: 'answer', content: toolTurn.terminalAnswer };
    }
    await session.progressBroker.maybePublish({ delta: session.collectProgressDelta() });
  }
}

module.exports = {
  runAgentLoop,
  setSteeringIntake,
};
