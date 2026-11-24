'use strict';

const db = require('../../../../db/database');
const { parseJsonObject } = require('../../../../utils/text');

function percentile(sorted, share) {
  if (!sorted.length) return null;
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * share))];
}

function spread(values) {
  const sorted = values.filter((value) => Number.isFinite(value)).sort((a, b) => a - b);
  return { p50: percentile(sorted, 0.5), p95: percentile(sorted, 0.95), samples: sorted.length };
}

function rate(part, whole) {
  return whole > 0 ? Number((part / whole).toFixed(4)) : 0;
}

/**
 * What recent runs looked like, from their stored summaries. This answers "which
 * problem dominates" before anyone changes the harness, and it is the production
 * half of what the eval gate checks on fixed tasks.
 */
function buildHarnessReport(userId, agentId, { days = 7, limit = 2000 } = {}) {
  const rows = db.prepare(
    `SELECT status, metrics_json FROM agent_runs
     WHERE user_id = ? AND agent_id = ? AND metrics_json IS NOT NULL
       AND datetime(created_at) >= datetime('now', ?)
     ORDER BY created_at DESC LIMIT ?`,
  ).all(userId, agentId, `-${Math.max(1, Number(days) || 7)} days`, limit);
  const runs = rows.map((row) => ({ status: row.status, ...parseJsonObject(row.metrics_json, {}) }));

  const totals = runs.reduce((sum, run) => ({
    toolCalls: sum.toolCalls + (run.tools?.calls || 0),
    toolFailed: sum.toolFailed + (run.tools?.failed || 0),
    toolSuppressed: sum.toolSuppressed + (run.tools?.suppressed || 0),
    duplicates: sum.duplicates + (run.tools?.duplicate_calls || 0),
    duplicateDeliveries: sum.duplicateDeliveries + (run.delivery?.suppressed || 0),
    failedDeliveries: sum.failedDeliveries + (run.delivery?.failed || 0),
    inputTokens: sum.inputTokens + (run.tokens?.input || 0),
    cachedTokens: sum.cachedTokens + (run.tokens?.cachedRead || 0),
    outputTokens: sum.outputTokens + (run.tokens?.output || 0),
    recoveries: sum.recoveries + (run.recoveries || 0),
    compactions: sum.compactions + (run.compactions || 0),
    recalls: sum.recalls + (run.memory?.recalls || 0),
    memoryTokens: sum.memoryTokens + (run.memory?.tokens || 0),
    denied: sum.denied + (run.permissions_denied || 0),
    ambiguousDeliveries: sum.ambiguousDeliveries + (run.delivery?.ambiguous || 0),
    suppressedThenRan: sum.suppressedThenRan + (run.tools?.suppressed_then_ran || 0),
    toolsUsed: sum.toolsUsed + (run.selection?.tools_used || 0),
    missedFirstTurn: sum.missedFirstTurn + (run.selection?.missed_first_turn?.length || 0),
  }), {
    toolCalls: 0, toolFailed: 0, toolSuppressed: 0, duplicates: 0, duplicateDeliveries: 0, failedDeliveries: 0,
    inputTokens: 0, cachedTokens: 0, outputTokens: 0, recoveries: 0, compactions: 0, recalls: 0, memoryTokens: 0, denied: 0,
    ambiguousDeliveries: 0, suppressedThenRan: 0, toolsUsed: 0, missedFirstTurn: 0,
  });

  const noToolRuns = runs.filter((run) => !run.tools?.calls).length;
  const completed = runs.filter((run) => run.status === 'completed').length;

  return {
    window_days: Math.max(1, Number(days) || 7),
    runs: runs.length,
    success_rate: rate(completed, runs.length),
    latency_ms: {
      total: spread(runs.map((run) => run.duration_ms)),
      first_action: spread(runs.map((run) => run.first_action_ms)),
      model: spread(runs.map((run) => run.latency?.model_ms)),
      tool: spread(runs.map((run) => run.latency?.tool_ms)),
      sandbox: spread(runs.map((run) => run.latency?.sandbox_ms)),
    },
    per_run: {
      turns: spread(runs.map((run) => run.turns)),
      tool_calls: spread(runs.map((run) => run.tools?.calls)),
      input_tokens: spread(runs.map((run) => run.tokens?.input)),
      output_tokens: spread(runs.map((run) => run.tokens?.output)),
    },
    rates: {
      no_tool_runs: rate(noToolRuns, runs.length),
      tool_failure: rate(totals.toolFailed, totals.toolCalls),
      // Of the tools runs used, how many were already there on the first turn.
      tool_selection_recall: totals.toolsUsed ? rate(totals.toolsUsed - totals.missedFirstTurn, totals.toolsUsed) : null,
      suppressed_calls_that_ran_later: rate(totals.suppressedThenRan, totals.toolSuppressed),
      ambiguous_deliveries_per_1000_runs: rate(totals.ambiguousDeliveries * 1000, runs.length),
      tool_suppressed: rate(totals.toolSuppressed, totals.toolCalls + totals.toolSuppressed),
      duplicate_tool_calls: rate(totals.duplicates, totals.toolCalls),
      duplicate_deliveries_stopped_per_1000_runs: rate(totals.duplicateDeliveries * 1000, runs.length),
      delivery_failures_per_1000_runs: rate(totals.failedDeliveries * 1000, runs.length),
      // Input counts cached tokens on every provider, but rows from before that was
      // true for Anthropic can hold more cached than input.
      prompt_cache_hit: Math.min(1, rate(totals.cachedTokens, totals.inputTokens)),
      memory_tokens_per_recall: rate(totals.memoryTokens, totals.recalls),
      recoveries_per_run: rate(totals.recoveries, runs.length),
      compactions_per_run: rate(totals.compactions, runs.length),
      permission_denials_per_run: rate(totals.denied, runs.length),
    },
  };
}

module.exports = {
  buildHarnessReport,
};
