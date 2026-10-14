'use strict';

// Limits for the runaway guards and tool-result replay. None of them shapes
// normal work: the model decides how many steps a task takes and when it is
// done. The turn ceiling is an emergency stop only.
const EMERGENCY_MAX_ITERATIONS = 5_000;
// Consecutive tool turns that changed no state and surfaced no new evidence.
const DEFAULT_MAX_IDLE_TURNS = 8;
// Consecutive tool turns in which every call failed.
const DEFAULT_MAX_FAILED_TURNS = 5;
const MAX_ALLOWED_IDLE_TURNS = 25;
const MAX_ALLOWED_FAILED_TURNS = 50;
const MAX_ALLOWED_BUDGET_CHARS = 500_000;
const DEFAULT_TOOL_RESULT_BUDGET_CHARS = 12_000;

function optionalNumber(value) {
  if (value == null || value === '') return Number.NaN;
  return Number(value);
}

function clampFinite(n, lo, hi, fallback) {
  if (!Number.isFinite(n)) return fallback;
  return Math.min(Math.max(n, lo), hi);
}

function buildLoopPolicy(aiSettings = {}, options = {}) {
  const maxIterations = clampFinite(
    Math.floor(optionalNumber(options.maxIterations)),
    1,
    EMERGENCY_MAX_ITERATIONS,
    EMERGENCY_MAX_ITERATIONS,
  );
  const maxIdleTurns = clampFinite(
    Math.floor(optionalNumber(
      options.maxConsecutiveReadOnlyIterations ?? aiSettings.max_consecutive_read_only_iterations,
    )),
    3,
    MAX_ALLOWED_IDLE_TURNS,
    DEFAULT_MAX_IDLE_TURNS,
  );
  const maxFailedTurns = clampFinite(
    Math.floor(optionalNumber(
      options.maxConsecutiveToolFailures ?? aiSettings.max_consecutive_tool_failures,
    )),
    1,
    MAX_ALLOWED_FAILED_TURNS,
    DEFAULT_MAX_FAILED_TURNS,
  );

  // Results cut below what the model needs are re-fetched in slices, and each
  // slice is a full model turn, so the budget errs on the side of complete.
  const requestedDefaultBudget = optionalNumber(aiSettings.tool_replay_budget_chars);
  const defaultBudget = Number.isFinite(requestedDefaultBudget) && requestedDefaultBudget > 0
    ? clampFinite(Math.floor(requestedDefaultBudget), 500, MAX_ALLOWED_BUDGET_CHARS, DEFAULT_TOOL_RESULT_BUDGET_CHARS)
    : DEFAULT_TOOL_RESULT_BUDGET_CHARS;
  const categoryBudget = (setting, floor) => clampFinite(
    Math.floor(optionalNumber(aiSettings[setting])),
    500,
    MAX_ALLOWED_BUDGET_CHARS,
    Math.max(defaultBudget, floor),
  );

  return {
    maxIterations,
    maxIdleTurns,
    maxFailedTurns,
    toolResultBudget: {
      default: defaultBudget,
      file: categoryBudget('tool_replay_budget_file_chars', 24000),
      browser: categoryBudget('tool_replay_budget_browser_chars', 16000),
      command: categoryBudget('tool_replay_budget_command_chars', 16000),
    },
    // The hard ceiling is twice the soft budget, capped at an absolute max.
    hardLimitMultiplier: 2,
    absoluteHardLimit: 48000,
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

module.exports = { buildLoopPolicy, resolveToolResultLimits };
