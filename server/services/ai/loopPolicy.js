/**
 * loopPolicy.js
 *
 * Single source of truth for every tunable limit in the agent loop.
 * No magic numbers live in engine.js — everything flows from here.
 *
 * Values resolve in priority order:
 *   1. Per-run option override (options.*)
 *   2. Agent AI settings (aiSettings.*)
 *   3. Hardcoded sane default
 *
 * "Open but stable": limits exist as safety nets, not as the primary
 * exit signal. The AI signals completion via task_complete; these
 * numbers only fire when something goes wrong.
 */

const DEFAULT_MAX_ITERATIONS = 20;
const DEFAULT_WIDGET_MAX_ITERATIONS = 30;
const DEFAULT_PLAN_EXECUTE_MAX_ITERATIONS = 40;
const DEFAULT_COMPACTION_THRESHOLD = 0.82;
const DEFAULT_MAX_CONSECUTIVE_TOOL_FAILURES = 5;
const DEFAULT_MAX_MODEL_FAILURE_RECOVERIES = 3;

// Hard ceilings — protect against runaway config values
const MAX_ALLOWED_ITERATIONS = 200;
const MAX_ALLOWED_TOOL_FAILURES = 50;
const MAX_ALLOWED_MODEL_RECOVERIES = 10;
const MAX_ALLOWED_BUDGET_CHARS = 500_000;

/** Return n if finite and positive, otherwise fallback. */
function finitePositive(n, fallback) {
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

/** Clamp n to [lo, hi]; return fallback if not finite. */
function clampFinite(n, lo, hi, fallback) {
  if (!Number.isFinite(n)) return fallback;
  return Math.min(Math.max(n, lo), hi);
}

/**
 * @param {object} aiSettings   - from getAiSettings()
 * @param {string} triggerType  - 'chat' | 'schedule' | 'subagent' | etc.
 * @param {string} analysisMode - 'direct_answer' | 'execute' | 'plan_execute'
 * @param {object} options      - per-run options (may override anything)
 * @returns {LoopPolicy}
 */
function buildLoopPolicy(aiSettings = {}, triggerType = 'chat', analysisMode = 'execute', options = {}) {
  const autonomyPolicy = options.autonomyPolicy && typeof options.autonomyPolicy === 'object'
    ? options.autonomyPolicy
    : {};
  const complexity = String(autonomyPolicy.complexity || '').trim().toLowerCase();
  const autonomyLevel = String(autonomyPolicy.autonomy_level || autonomyPolicy.autonomyLevel || '').trim().toLowerCase();
  const parallelWork = autonomyPolicy.parallel_work === true || autonomyPolicy.parallelWork === true;

  // ── maxIterations ────────────────────────────────────────────────────────
  // Resolve raw value from options → aiSettings → mode/context defaults,
  // then clamp to [1, MAX_ALLOWED_ITERATIONS] and floor to integer.
  let rawIterations;
  if (options.maxIterations != null) {
    rawIterations = Number(options.maxIterations);
  } else if (aiSettings.max_iterations != null) {
    rawIterations = Number(aiSettings.max_iterations);
  } else if (options.widgetId) {
    rawIterations = DEFAULT_WIDGET_MAX_ITERATIONS;
  } else if (analysisMode === 'plan_execute') {
    rawIterations = DEFAULT_PLAN_EXECUTE_MAX_ITERATIONS;
  } else if (complexity === 'complex' || autonomyLevel === 'high') {
    rawIterations = DEFAULT_PLAN_EXECUTE_MAX_ITERATIONS;
  } else if (parallelWork || complexity === 'standard') {
    rawIterations = Math.max(DEFAULT_MAX_ITERATIONS, 28);
  } else {
    rawIterations = DEFAULT_MAX_ITERATIONS;
  }
  const maxIterations = clampFinite(
    Math.floor(rawIterations),
    1,
    MAX_ALLOWED_ITERATIONS,
    DEFAULT_MAX_ITERATIONS,
  );

  // ── Tool result size budget ───────────────────────────────────────────────
  // Must be a finite positive integer; bad values fall back to 2400.
  const defaultBudget = clampFinite(
    Math.floor(Number(aiSettings.tool_replay_budget_chars) || 0),
    500,
    MAX_ALLOWED_BUDGET_CHARS,
    2400,
  );

  // ── Scalar policy fields ─────────────────────────────────────────────────
  const maxConsecutiveToolFailures = clampFinite(
    Math.floor(Number(aiSettings.max_consecutive_tool_failures)),
    1,
    MAX_ALLOWED_TOOL_FAILURES,
    DEFAULT_MAX_CONSECUTIVE_TOOL_FAILURES,
  );

  const maxModelFailureRecoveries = clampFinite(
    Math.floor(Number(aiSettings.max_model_failure_recoveries)),
    0,
    MAX_ALLOWED_MODEL_RECOVERIES,
    DEFAULT_MAX_MODEL_FAILURE_RECOVERIES,
  );

  // compactionThreshold must be in (0, 1]; clamp to [0.1, 1].
  const compactionThreshold = clampFinite(
    Number(aiSettings.compaction_threshold),
    0.1,
    1,
    DEFAULT_COMPACTION_THRESHOLD,
  );

  return {
    maxIterations,
    maxConsecutiveToolFailures,
    maxModelFailureRecoveries,

    // Fill ratio at which context compaction triggers (0–1)
    compactionThreshold,

    // Per-category tool result size budgets (chars)
    toolResultBudget: {
      default: defaultBudget,
      file:    clampFinite(Math.floor(Number(aiSettings.tool_replay_budget_file_chars)),    500, MAX_ALLOWED_BUDGET_CHARS, Math.max(defaultBudget, 6000)),
      browser: clampFinite(Math.floor(Number(aiSettings.tool_replay_budget_browser_chars)), 500, MAX_ALLOWED_BUDGET_CHARS, Math.max(defaultBudget, 4000)),
      command: clampFinite(Math.floor(Number(aiSettings.tool_replay_budget_command_chars)), 500, MAX_ALLOWED_BUDGET_CHARS, Math.max(defaultBudget, 4000)),
    },

    // Hard ceiling is always 2× soft, capped at a reasonable absolute max
    hardLimitMultiplier: 2,
    absoluteHardLimit: 12000,
  };
}

/**
 * Map a tool name to its result-size category.
 */
function getToolCategory(toolName) {
  if (!toolName) return 'default';
  if (/^(read_file|write_file|search_files|list_directory|file_)/.test(toolName)) return 'file';
  if (/^browser_/.test(toolName)) return 'browser';
  if (/^(execute_command|android_shell|android_)/.test(toolName)) return 'command';
  return 'default';
}

/**
 * Resolve soft + hard limits for a specific tool from the policy.
 */
function resolveToolResultLimits(toolName, policy) {
  const category = getToolCategory(toolName);
  const soft = policy.toolResultBudget[category] ?? policy.toolResultBudget.default;
  const hard = Math.min(soft * policy.hardLimitMultiplier, policy.absoluteHardLimit);
  return { softLimit: soft, hardLimit: hard };
}

module.exports = { buildLoopPolicy, getToolCategory, resolveToolResultLimits };
