'use strict';

// Why this run was slow, wasteful, or uncertain, read from its stored summary with
// no model involved. The limits are starting points to adjust against real runs.
const SLOW_MODEL_SHARE = 0.7;
const SLOW_RUN_MS = 10 * 1000;
const TOOL_CONTEXT_SHARE = 0.5;
const TOOL_CONTEXT_MIN_TOKENS = 5000;
const FAILED_TOOLS = 2;
const REPEATED_CALLS = 2;

function diagnoseRun(metrics) {
  if (!metrics) return [];
  const found = [];
  const add = (code, values = {}) => found.push({ code, ...values });

  const outcome = metrics.outcome?.task_outcome;
  if (['action_failed', 'tests_failing', 'unverified', 'rolled_back'].includes(outcome)) add(`outcome_${outcome}`);
  const untracked = metrics.outcome?.evidence?.changes_untracked || 0;
  if (untracked > 0) add('changes_not_tracked', { count: untracked });
  const ambiguous = metrics.delivery?.ambiguous || 0;
  if (ambiguous > 0) add('delivery_ambiguous', { count: ambiguous });
  const suppressedThenRan = metrics.tools?.suppressed_then_ran || 0;
  if (suppressedThenRan > 0) add('suppression_overruled', { count: suppressedThenRan });
  const repeated = metrics.tools?.duplicate_calls || 0;
  if (repeated >= REPEATED_CALLS) add('repeated_calls', { count: repeated });
  const failed = metrics.tools?.failed || 0;
  if (failed >= FAILED_TOOLS) add('failed_tools', { count: failed });
  const missed = metrics.selection?.missed_first_turn || [];
  if (missed.length) add('tool_not_on_first_turn', { tools: missed });

  const durationMs = metrics.duration_ms || 0;
  const modelMs = metrics.latency?.model_ms || 0;
  if (durationMs >= SLOW_RUN_MS && modelMs / durationMs >= SLOW_MODEL_SHARE) {
    add('slow_model_loop', { share: Number((modelMs / durationMs).toFixed(2)) });
  }
  const toolTokens = metrics.context?.tool_tokens || 0;
  const totalTokens = metrics.context?.total_tokens || 0;
  if (toolTokens >= TOOL_CONTEXT_MIN_TOKENS && toolTokens / totalTokens >= TOOL_CONTEXT_SHARE) {
    add('tools_fill_context', { share: Number((toolTokens / totalTokens).toFixed(2)), tokens: toolTokens });
  }
  return found;
}

module.exports = { diagnoseRun };
