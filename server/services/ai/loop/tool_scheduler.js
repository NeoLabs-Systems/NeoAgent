'use strict';

const DEFAULT_MAX_PARALLEL_TOOL_CALLS = 10;

function normalizeParallelLimit(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) return DEFAULT_MAX_PARALLEL_TOOL_CALLS;
  return Math.min(parsed, 32);
}

function groupToolCalls(calls = [], isParallelSafe = () => false) {
  const groups = [];
  let parallel = [];

  for (const call of calls) {
    if (isParallelSafe(call)) {
      parallel.push(call);
      continue;
    }
    if (parallel.length > 0) {
      groups.push({ kind: 'parallel', calls: parallel });
      parallel = [];
    }
    groups.push({ kind: 'exclusive', calls: [call] });
  }
  if (parallel.length > 0) groups.push({ kind: 'parallel', calls: parallel });
  return groups;
}

async function runParallelGroup(calls, execute, maxParallel) {
  const results = new Array(calls.length);
  let nextIndex = 0;
  let failure = null;

  const worker = async () => {
    while (true) {
      if (failure) return;
      const index = nextIndex;
      nextIndex += 1;
      if (index >= calls.length) return;
      try {
        results[index] = await execute(calls[index], index);
      } catch (error) {
        if (!failure) failure = { index, error };
        return;
      }
    }
  };

  const workerCount = Math.min(calls.length, normalizeParallelLimit(maxParallel));
  await Promise.all(Array.from({ length: workerCount }, () => worker()));
  if (failure) throw failure.error;
  return results;
}

/**
 * Execute model-ordered tool calls with DeepSeek-style barriers.
 * Consecutive parallel-safe calls share a bounded pool. Exclusive calls run
 * alone, and committed outcomes always follow model order.
 */
async function scheduleToolCalls(calls = [], {
  isParallelSafe = () => false,
  execute,
  commit = null,
  maxParallel = DEFAULT_MAX_PARALLEL_TOOL_CALLS,
} = {}) {
  if (typeof execute !== 'function') throw new TypeError('execute must be a function');
  const outcomes = [];
  const groups = groupToolCalls(calls, isParallelSafe);

  for (const group of groups) {
    const settled = group.kind === 'parallel' && group.calls.length > 1
      ? await runParallelGroup(group.calls, execute, maxParallel)
      : [await execute(group.calls[0], 0)];

    for (let index = 0; index < settled.length; index += 1) {
      const outcome = settled[index];
      outcomes.push(outcome);
      if (commit) await commit(outcome, group.calls[index]);
    }
  }

  return outcomes;
}

module.exports = {
  DEFAULT_MAX_PARALLEL_TOOL_CALLS,
  groupToolCalls,
  normalizeParallelLimit,
  scheduleToolCalls,
};
