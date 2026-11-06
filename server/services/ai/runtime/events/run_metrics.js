'use strict';

const db = require('../../../../db/database');
const { parseJsonObject } = require('../../../../utils/text');
const { EVENT_TYPES } = require('./event_types');
const { listEvents } = require('./run_event_store');
const { inferTaskKind } = require('../../task_models');
const { resolveToolMeta } = require('../../tools/metadata');

const T = EVENT_TYPES;

function isoMs(event) {
  return Date.parse(event.payload?.timestamp || '') || 0;
}

function sum(events, pick) {
  return events.reduce((total, event) => total + (Number(pick(event)) || 0), 0);
}

function ofType(events, ...types) {
  return events.filter((event) => types.includes(event.eventType));
}

/**
 * One run's summary, computed from its ledger: the numbers the Runs tab shows
 * and the eval gate compares. Latency splits as queue + model + tool + sandbox +
 * delivery, so a slow run names what was slow.
 */
function summarizeRunEvents(events, { usage = [], run = null } = {}) {
  const started = events[0] ? isoMs(events[0]) : 0;
  const ended = events.length ? isoMs(events[events.length - 1]) : started;

  const modelResponses = ofType(events, T.MODEL_RESPONSE);
  const loopResponses = modelResponses.filter((event) => (event.payload?.phase || 'model_turn') === 'model_turn');
  const toolResults = ofType(events, T.TOOL_RESULT);
  const suppressed = ofType(events, T.TOOL_SUPPRESSED);
  const recalls = ofType(events, T.MEMORY_RECALL).filter((event) => event.payload?.recalled !== false);
  const compactions = ofType(events, T.CONTEXT_COMPACTED);
  const deliveries = ofType(events, T.DELIVERY_SENT, T.DELIVERY_FAILED, T.DELIVERY_SUPPRESSED);
  const selections = ofType(events, T.TOOLS_SELECTED);
  const initialSelection = selections.find((event) => event.payload?.kind === 'initial') || null;
  const contextBuilt = ofType(events, T.CONTEXT_BUILT)[0] || null;
  const firstAction = ofType(events, T.TOOL_CALL, T.DELIVERY_SENT)[0] || null;

  const toolMs = sum(toolResults, (event) => event.payload?.duration_ms);
  const sandboxMs = sum(toolResults, (event) => event.payload?.sandbox_ms);
  const modelMs = sum(modelResponses, (event) => event.payload?.duration_ms);
  const deliveryMs = sum(ofType(events, T.DELIVERY_SENT), (event) => event.payload?.duration_ms);
  const queueMs = Number(contextBuilt?.payload?.startup_ms) || 0;

  const tokens = usage.reduce((totals, row) => ({
    input: totals.input + (Number(row.input_tokens) || 0),
    output: totals.output + (Number(row.output_tokens) || 0),
    reasoning: totals.reasoning + (Number(row.reasoning_tokens) || 0),
    cachedRead: totals.cachedRead + (Number(row.cached_read_tokens) || 0),
    cacheWrite: totals.cacheWrite + (Number(row.cache_write_tokens) || 0),
    total: totals.total + (Number(row.total_tokens) || 0),
  }), { input: 0, output: 0, reasoning: 0, cachedRead: 0, cacheWrite: 0, total: 0 });

  const toolNames = toolResults.map((event) => event.payload?.tool?.name).filter(Boolean);
  const finalDelivery = deliveries.filter((event) => event.payload?.purpose === 'final');
  const memoryTokens = sum(recalls, (event) => event.payload?.tokens);
  const contextSections = contextBuilt?.payload?.sections || {};
  const peakPromptTokens = Math.max(0, ...ofType(events, T.MODEL_REQUEST).map((event) => Number(event.payload?.context?.estimated_tokens) || 0));

  return {
    schema_version: 1,
    status: run?.status || null,
    task_class: inferTaskKind(toolNames) || (toolNames.length ? 'general' : 'answer'),
    prompt_version: contextBuilt?.payload?.prompt_version || null,
    duration_ms: Math.max(0, ended - started),
    first_action_ms: firstAction && started ? Math.max(0, isoMs(firstAction) - started) : null,
    latency: {
      queue_ms: queueMs,
      model_ms: modelMs,
      tool_ms: Math.max(0, toolMs - sandboxMs),
      sandbox_ms: sandboxMs,
      delivery_ms: deliveryMs,
    },
    turns: loopResponses.length,
    side_calls: modelResponses.length - loopResponses.length,
    retries: sum(modelResponses, (event) => event.payload?.retry_count),
    tools: {
      calls: toolResults.length,
      failed: toolResults.filter((event) => event.payload?.outcome?.status === 'failed').length,
      suppressed: suppressed.length,
      used: [...new Set(toolNames)],
      duplicate_calls: duplicateCallCount(toolResults),
      suppressed_then_ran: suppressedThenRan(suppressed, toolResults),
    },
    selection: initialSelection ? {
      catalog_size: initialSelection.payload?.selection?.catalog_size ?? null,
      eligible_count: initialSelection.payload?.selection?.eligible_count ?? null,
      active_count: initialSelection.payload?.selection?.active_count ?? null,
      activated_later: selections.filter((event) => event.payload?.kind === 'activate').length,
      searched: selections.filter((event) => event.payload?.kind === 'search').length,
      ...selectionRecall(initialSelection, toolNames),
    } : null,
    context: {
      total_tokens: Number(contextSections.total_tokens) || 0,
      system_tokens: Number(contextSections.system_tokens) || 0,
      tool_tokens: (Number(contextSections.tool_schema_tokens) || 0) + (Number(contextSections.tool_catalog_tokens) || 0),
      history_tokens: Number(contextSections.history_tokens) || 0,
      memory_tokens: Number(contextSections.memory_tokens) || 0,
    },
    tokens,
    prompt: { peak_estimated_tokens: peakPromptTokens },
    memory: {
      recalls: recalls.length,
      tokens: memoryTokens,
      share_of_prompt: peakPromptTokens > 0 ? Number((memoryTokens / peakPromptTokens).toFixed(4)) : 0,
      writes: sum(ofType(events, T.MEMORY_WRITE), (event) => event.payload?.count),
    },
    outcome: taskOutcome({ status: run?.status, events, toolResults }),
    compactions: compactions.length,
    recoveries: ofType(events, T.RECOVERY_TRIGGERED).length,
    checkpoints: ofType(events, T.CHECKPOINT_CREATED).length,
    permissions_denied: ofType(events, T.PERMISSION_DECISION).filter((event) => event.payload?.decision === 'deny').length,
    delivery: {
      sent: ofType(events, T.DELIVERY_SENT).length,
      failed: ofType(events, T.DELIVERY_FAILED).length,
      suppressed: ofType(events, T.DELIVERY_SUPPRESSED).length,
      ambiguous: ofType(events, T.DELIVERY_FAILED).filter((event) => event.payload?.ambiguous === true).length,
      final_sent: finalDelivery.filter((event) => event.eventType === T.DELIVERY_SENT).length,
    },
  };
}

// How well the first selection guessed: a tool the run used that was not on the
// first turn cost it a search or an activation. Control tools are how a run gets
// to other tools, not what it set out to use.
function selectionRecall(initialSelection, toolNames) {
  const surfaced = new Set((initialSelection.payload?.candidates || []).map((candidate) => candidate.name));
  const used = [...new Set(toolNames)].filter((name) => resolveToolMeta(name).group !== 'control');
  return {
    tools_used: used.length,
    missed_first_turn: used.filter((name) => !surfaced.has(name)),
  };
}

// What the run can show it did, from tool receipts alone: the model's words play no
// part. "completed" only says the loop ended; this says what came of it. "verified"
// means tests passed after the last file change, nothing more than that.
function taskOutcome({ status, events, toolResults }) {
  const actions = toolResults.filter((event) => event.payload?.receipt?.mutating);
  const tests = toolResults.filter((event) => event.payload?.receipt?.test);
  const lastTest = tests.at(-1) || null;
  // A call outside any repository is not a change anyone saw; counted as one, it
  // marked every shell run "unverified" whatever it did.
  const located = ofType(events, T.WORKSPACE_CHANGED);
  const changes = located.filter((event) => event.payload?.reason !== 'not_a_repository');
  const tracked = changes.filter((event) => !event.payload?.untracked);
  const lastChange = changes.at(-1) || null;
  const restores = ofType(events, T.CHECKPOINT_RESTORED);
  const test = lastTest?.payload.receipt.test || null;
  const evidence = {
    actions: actions.length,
    actions_failed: actions.filter((event) => !event.payload.receipt.ok).length,
    files_changed: new Set(tracked.flatMap((event) => event.payload?.paths || [])).size,
    changes_untracked: changes.length - tracked.length,
    outside_repositories: located.length - changes.length,
    tests_run: tests.length,
    last_test: test,
    messages_sent: ofType(events, T.DELIVERY_SENT).filter((event) => event.payload?.purpose !== 'final').length,
    rolled_back: restores.length > 0,
  };
  const lastAction = actions.at(-1)?.payload.receipt;
  const rolledBackLast = restores.length > 0 && (!lastChange || restores.at(-1).sequenceIndex > lastChange.sequenceIndex);
  let outcome = 'answered';
  if (status && status !== 'completed') outcome = status;
  else if (rolledBackLast) outcome = 'rolled_back';
  else if (test && (test.failed > 0 || test.exit_ok === false)) outcome = 'tests_failing';
  else if (lastAction && !lastAction.ok) outcome = 'action_failed';
  else if (lastChange && (!lastTest || lastTest.sequenceIndex < lastChange.sequenceIndex)) outcome = 'unverified';
  else if (lastChange && test?.passed > 0) outcome = 'verified';
  else if (actions.length) outcome = 'actions_done';
  return { task_outcome: outcome, evidence };
}

// A suppressed call that ran anyway later means the guard may have been wrong.
function suppressedThenRan(suppressed, toolResults) {
  return suppressed.filter((event) => toolResults.some((result) => (
    result.sequenceIndex > event.sequenceIndex
    && result.payload?.tool?.name === event.payload?.tool?.name
    && result.payload?.tool?.call_fingerprint === event.payload?.tool?.call_fingerprint
  ))).length;
}

// Equivalent calls that ran without any relevant state changing in between. The
// fingerprint carries the state version, so a re-read after an edit is not one.
function duplicateCallCount(toolResults) {
  const seen = new Set();
  let duplicates = 0;
  for (const event of toolResults) {
    const fingerprint = event.payload?.tool?.call_fingerprint;
    if (!fingerprint) continue;
    if (seen.has(fingerprint)) duplicates += 1;
    seen.add(fingerprint);
  }
  return duplicates;
}

function summarizeRun(runId) {
  const run = db.prepare('SELECT id, status FROM agent_runs WHERE id = ?').get(runId);
  if (!run) return null;
  const usage = db.prepare(
    `SELECT input_tokens, output_tokens, reasoning_tokens, cached_read_tokens, cache_write_tokens, total_tokens
     FROM agent_model_usage WHERE run_id = ?`,
  ).all(runId);
  return summarizeRunEvents(listEvents(runId), { usage, run });
}

function persistRunMetrics(runId) {
  try {
    const metrics = summarizeRun(runId);
    if (!metrics) return null;
    db.prepare('UPDATE agent_runs SET metrics_json = ? WHERE id = ?').run(JSON.stringify(metrics), runId);
    return metrics;
  } catch (error) {
    console.warn('[RunLedger] Could not store run metrics:', error?.message || error);
    return null;
  }
}

// A run still in progress has no stored summary yet, so it is computed live.
function readRunMetrics(row) {
  if (row?.metrics_json) return parseJsonObject(row.metrics_json, {});
  return row?.id ? summarizeRun(row.id) : null;
}

module.exports = {
  persistRunMetrics,
  readRunMetrics,
  summarizeRun,
  summarizeRunEvents,
};
