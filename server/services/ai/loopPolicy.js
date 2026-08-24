// Completion, open obligations, and progress guards are the real exit signals.
// This ceiling is deliberately only an emergency runaway guard; productive
// long-horizon work must not be shaped around an arbitrary turn allowance.
const EMERGENCY_MAX_ITERATIONS = 5_000;
// The real "stop when stuck" guard. Counts consecutive turns with no state
// change and no new evidence; resets to 0 on any concrete progress.
const DEFAULT_MAX_CONSECUTIVE_READ_ONLY_ITERATIONS = 8;
const DEFAULT_SIMPLE_MAX_CONSECUTIVE_READ_ONLY_ITERATIONS = 3;
const DEFAULT_COMPLEX_MAX_CONSECUTIVE_READ_ONLY_ITERATIONS = 14;
const DEFAULT_MAX_CONSECUTIVE_TOOL_FAILURES = 5;
const MAX_ALLOWED_ITERATIONS = EMERGENCY_MAX_ITERATIONS;
const MAX_ALLOWED_READ_ONLY_ITERATIONS = 25;
const MAX_ALLOWED_TOOL_FAILURES = 50;
const MAX_ALLOWED_BUDGET_CHARS = 500_000;

function optionalNumber(value) {
  if (value == null || value === '') return Number.NaN;
  return Number(value);
}

function clampFinite(n, lo, hi, fallback) {
  if (!Number.isFinite(n)) return fallback;
  return Math.min(Math.max(n, lo), hi);
}

function buildLoopPolicy(aiSettings = {}, triggerType = 'chat', analysisMode = 'execute', options = {}) {
  const autonomyPolicy = options.autonomyPolicy && typeof options.autonomyPolicy === 'object'
    ? options.autonomyPolicy
    : {};
  const complexity = String(autonomyPolicy.complexity || '').trim().toLowerCase();
  const autonomyLevel = String(autonomyPolicy.autonomy_level || autonomyPolicy.autonomyLevel || '').trim().toLowerCase();
  // Tests and specialized internal callers may request a smaller safety cap.
  // There is intentionally no user-facing/default productivity budget.
  const rawIterations = options.maxIterations == null
    ? EMERGENCY_MAX_ITERATIONS
    : Number(options.maxIterations);
  const maxIterations = clampFinite(
    Math.floor(rawIterations),
    1,
    MAX_ALLOWED_ITERATIONS,
    EMERGENCY_MAX_ITERATIONS,
  );

  // ── Tool result size budget ───────────────────────────────────────────────
  // Must be a finite positive integer; bad values fall back to 2400.
  const requestedDefaultBudget = optionalNumber(aiSettings.tool_replay_budget_chars);
  const defaultBudget = Number.isFinite(requestedDefaultBudget) && requestedDefaultBudget > 0
    ? clampFinite(Math.floor(requestedDefaultBudget), 500, MAX_ALLOWED_BUDGET_CHARS, 2400)
    : 2400;

  // ── Scalar policy fields ─────────────────────────────────────────────────
  const maxConsecutiveToolFailures = clampFinite(
    Math.floor(optionalNumber(
      options.maxConsecutiveToolFailures
      ?? aiSettings.max_consecutive_tool_failures,
    )),
    1,
    MAX_ALLOWED_TOOL_FAILURES,
    DEFAULT_MAX_CONSECUTIVE_TOOL_FAILURES,
  );

  let defaultReadOnlyIterations = DEFAULT_MAX_CONSECUTIVE_READ_ONLY_ITERATIONS;
  if (analysisMode === 'direct_answer' || complexity === 'simple') {
    defaultReadOnlyIterations = DEFAULT_SIMPLE_MAX_CONSECUTIVE_READ_ONLY_ITERATIONS;
  } else if (
    analysisMode === 'plan_execute'
    || complexity === 'complex'
    || autonomyLevel === 'high'
  ) {
    // Long-horizon research/implementation needs more productive read/search
    // room before the hard no-progress wrap-up fires.
    defaultReadOnlyIterations = DEFAULT_COMPLEX_MAX_CONSECUTIVE_READ_ONLY_ITERATIONS;
  }

  const rawReadOnlyIterations = options.maxConsecutiveReadOnlyIterations != null
    ? Number(options.maxConsecutiveReadOnlyIterations)
    : optionalNumber(aiSettings.max_consecutive_read_only_iterations);
  const maxConsecutiveReadOnlyIterations = clampFinite(
    Math.floor(rawReadOnlyIterations),
    3,
    MAX_ALLOWED_READ_ONLY_ITERATIONS,
    defaultReadOnlyIterations,
  );

  return {
    maxIterations,
    maxConsecutiveReadOnlyIterations,
    maxConsecutiveToolFailures,

    // Per-category tool result size budgets (chars)
    toolResultBudget: {
      default: defaultBudget,
      file:    clampFinite(Math.floor(optionalNumber(aiSettings.tool_replay_budget_file_chars)),    500, MAX_ALLOWED_BUDGET_CHARS, Math.max(defaultBudget, 6000)),
      browser: clampFinite(Math.floor(optionalNumber(aiSettings.tool_replay_budget_browser_chars)), 500, MAX_ALLOWED_BUDGET_CHARS, Math.max(defaultBudget, 4000)),
      command: clampFinite(Math.floor(optionalNumber(aiSettings.tool_replay_budget_command_chars)), 500, MAX_ALLOWED_BUDGET_CHARS, Math.max(defaultBudget, 4000)),
    },

    // Hard ceiling is always 2× soft, capped at a reasonable absolute max
    hardLimitMultiplier: 2,
    absoluteHardLimit: 12000,
  };
}

function getToolCategory(toolName) {
  if (!toolName) return 'default';
  if (/^(read_file|write_file|search_files|list_directory|file_)/.test(toolName)) return 'file';
  if (/^browser_/.test(toolName)) return 'browser';
  if (/^(execute_command|android_shell|android_)/.test(toolName)) return 'command';
  return 'default';
}

function resolveToolResultLimits(toolName, policy) {
  const category = getToolCategory(toolName);
  const soft = policy.toolResultBudget[category] ?? policy.toolResultBudget.default;
  const hard = Math.min(soft * policy.hardLimitMultiplier, policy.absoluteHardLimit);
  return { softLimit: soft, hardLimit: hard };
}

function resolveChurnNudgeThreshold(goalContract) {
  const complexity = String(goalContract?.complexity || 'standard').toLowerCase();
  const autonomyLevel = String(goalContract?.autonomyLevel || goalContract?.autonomy_level || 'normal').toLowerCase();
  if (complexity === 'simple') return 2;
  // Complex/high-autonomy work, including multi-target research, should get more
  // productive inspection room before the soft churn nudge fires.
  if (complexity === 'complex' || autonomyLevel === 'high') return 6;
  return 3;
}

module.exports = { buildLoopPolicy, getToolCategory, resolveToolResultLimits, resolveChurnNudgeThreshold };
