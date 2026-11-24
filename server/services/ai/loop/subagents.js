'use strict';

const { v4: uuidv4 } = require('uuid');
const { getAiSettings } = require('../settings');
const { clampRunContext } = require('../messagingFallback');
const { EVENT_TYPES } = require('../runtime/events/event_types');
const { recordEventSafe } = require('../runtime/events/run_event_store');
const { summarizeRun } = require('../runtime/events/run_metrics');
const {
  createAbortError,
  createLinkedAbortController,
  isAbortError,
  runWithAbortTimeout,
  throwIfAborted,
} = require('../../../utils/abort');

// Sub-agents for real parallel work or isolated context, and delegation to
// specialist agents. Both are tools the model chooses to use; nothing here runs
// on its own.

// A sub-agent is a bounded piece of work: these are its limits unless the parent
// asks for less, and nothing can ask for more than the ceiling.
const LIMITS = Object.freeze({
  turns: { fallback: 30, ceiling: 60 },
  tokens: { fallback: 300_000, ceiling: 1_000_000 },
  seconds: { fallback: 600, ceiling: 1_800 },
});

function limit(requested, { fallback, ceiling }) {
  const value = Number(requested);
  return Number.isFinite(value) && value > 0 ? Math.min(Math.floor(value), ceiling) : fallback;
}

function hasWritingSubagent(engine, parentRunId) {
  for (const record of engine.subagents.values()) {
    if (record.parentRunId === parentRunId && record.write && !record.settled) return true;
  }
  return false;
}

async function spawnSubagent(engine, userId, parentRunId, task, options = {}) {
  if (engine.shuttingDown || engine.lifecycleAbortController.signal.aborted) {
    throw createAbortError(engine.lifecycleAbortController.signal, 'Agent engine is shutting down.');
  }

  let parentRunMeta = engine.getRunMeta(parentRunId);
  if (
    !parentRunMeta
    || parentRunMeta.userId !== userId
    || parentRunMeta.status !== 'running'
    || parentRunMeta.aborted === true
  ) {
    return { error: 'The parent run is no longer active, so a sub-agent cannot be started.' };
  }
  const parentDepth = Math.max(0, Number(parentRunMeta?.subagentDepth) || 0);
  if (parentDepth >= 1) {
    return {
      error: 'Sub-agents cannot spawn additional sub-agents. Continue the current child run or return results to the parent run.',
    };
  }

  const aiSettings = getAiSettings(userId, options.agentId || null);
  if (options.write === true && hasWritingSubagent(engine, parentRunId)) {
    return { error: 'Another sub-agent of this run is already changing the workspace. Wait for it, or start this one read-only.' };
  }
  const maxSubagentsPerRun = Math.max(1, Number(aiSettings.subagent_max_children_per_run) || 10);
  const countExistingSubagents = () => Array.from(engine.subagents.values())
    .filter((record) => record.parentRunId === parentRunId).length;
  if (countExistingSubagents() >= maxSubagentsPerRun) {
    return {
      error: `This run has already spawned ${countExistingSubagents()} sub-agents. The limit for one run is ${maxSubagentsPerRun}.`,
    };
  }

  const handle = uuidv4();
  const childRunId = uuidv4();
  let relevantMemories = [];
  const startupLink = createLinkedAbortController([
    engine.lifecycleAbortController.signal,
    parentRunMeta.abortController?.signal,
    options.signal,
  ]);
  let memoryRecall = null;
  try {
    throwIfAborted(startupLink.signal, 'Sub-agent startup was aborted.');
    memoryRecall = engine.memoryManager
      ? runWithAbortTimeout(
        (signal) => engine.memoryManager.recallMemory(userId, task, 4, {
          agentId: options.agentId || null,
          signal,
        }),
        {
          label: 'Sub-agent memory recall',
          signal: startupLink.signal,
        },
      )
      : Promise.resolve([]);
    engine.subagentStartupTasks.add(memoryRecall);
    relevantMemories = await memoryRecall;
    throwIfAborted(startupLink.signal, 'Sub-agent startup was aborted.');
  } catch (error) {
    if (isAbortError(error, startupLink.signal)) throw error;
    console.warn('[AgentEngine] Sub-agent memory recall failed:', error?.message || error);
  } finally {
    if (memoryRecall) engine.subagentStartupTasks.delete(memoryRecall);
    startupLink.cleanup();
  }

  parentRunMeta = engine.getRunMeta(parentRunId);
  if (
    engine.shuttingDown
    || engine.lifecycleAbortController.signal.aborted
    || !parentRunMeta
    || parentRunMeta.userId !== userId
    || parentRunMeta.status !== 'running'
    || parentRunMeta.aborted === true
  ) {
    throw createAbortError(
      engine.lifecycleAbortController.signal.aborted
        ? engine.lifecycleAbortController.signal
        : parentRunMeta?.abortController?.signal,
      'The parent run stopped before the sub-agent could start.',
    );
  }
  const currentSubagentCount = countExistingSubagents();
  if (currentSubagentCount >= maxSubagentsPerRun) {
    return {
      error: `This run has already spawned ${currentSubagentCount} sub-agents. The limit for one run is ${maxSubagentsPerRun}.`,
    };
  }

  const childLink = createLinkedAbortController([
    engine.lifecycleAbortController.signal,
    parentRunMeta.abortController?.signal,
    options.signal,
  ]);
  throwIfAborted(childLink.signal, 'Sub-agent startup was aborted.');
  const subEngine = new engine.constructor(engine.io, {
    app: options.app || engine.app,
    browserController: engine.browserController,
    androidController: engine.androidController,
    runtimeManager: engine.runtimeManager,
    workspaceManager: engine.workspaceManager,
    messagingManager: engine.messagingManager,
    mcpManager: engine.mcpManager,
    skillRunner: engine.skillRunner,
    taskRuntime: engine.taskRuntime,
    memoryManager: engine.memoryManager,
  });

  const subagentContract = [
    `Goal: ${String(task || '').trim()}`,
    options.context ? `Constraints and relevant context:\n${String(options.context).trim()}` : '',
    relevantMemories.length > 0
      ? `Top relevant memories: ${JSON.stringify(relevantMemories.map((memory) => ({
        content: memory.content,
        confidence: memory.confidence,
      })))}`
      : '',
    Array.isArray(options.requiredArtifacts) && options.requiredArtifacts.length > 0
      ? `Required artifacts: ${JSON.stringify(options.requiredArtifacts)}`
      : '',
    Array.isArray(options.selectedTools) && options.selectedTools.length > 0
      ? `Selected tools: ${JSON.stringify(options.selectedTools.slice(0, 20))}`
      : '',
    'Return a single JSON object with exactly these top-level fields: status, findings, evidence, artifacts, confidence, remaining_blockers.',
    'status must be completed, partial, or blocked. findings, evidence, artifacts, and remaining_blockers must be arrays. confidence must be low, medium, or high.',
  ].filter(Boolean).join('\n\n');
  const record = {
    handle,
    parentRunId,
    childRunId,
    write: options.write === true,
    userId,
    agentId: options.agentId || null,
    task: subagentContract,
    model: options.model || null,
    status: 'running',
    createdAt: new Date().toISOString(),
    result: null,
    error: null,
    engine: subEngine,
    promise: null,
    settled: false,
    deleteWhenSettled: false,
  };
  engine.subagents.set(handle, record);
  engine.emit(userId, 'run:subagent', {
    runId: parentRunId,
    handle,
    childRunId,
    status: 'running',
    task: clampRunContext(task, 180),
  });

  const deadline = setTimeout(() => {
    childLink.controller.abort(new Error('The sub-agent ran out of time.'));
  }, limit(options.maxSeconds, LIMITS.seconds) * 1000);
  deadline.unref?.();

  record.promise = (async () => {
    try {
      const result = await subEngine.runWithModel(
        userId,
        subagentContract,
        {
          app: options.app || engine.app,
          title: task,
          triggerType: 'subagent',
          triggerSource: 'agent',
          runId: childRunId,
          agentId: options.agentId || null,
          subagentDepth: parentDepth + 1,
          // A specialist it called would have none of these limits.
          disallowedToolNames: ['spawn_subagent', 'delegate_to_agent', 'agent_task', 'create_agent'],
          // It works where the parent works.
          deviceTarget: parentRunMeta?.deviceTarget,
          workspaceRoot: parentRunMeta?.workspaceRoot,
          allowedToolNames: options.allowedTools || null,
          // Children read unless told otherwise, and only one may write at a time.
          readOnly: options.write !== true,
          maxIterations: limit(options.maxTurns, LIMITS.turns),
          maxTotalTokens: limit(options.maxTokens, LIMITS.tokens),
          // The child's task is model-written, so it works under the
          // parent's trust and any taint it picks up flows back.
          parentTrust: parentRunMeta?.trust || null,
          signal: childLink.signal,
        },
        options.model || null
      );
      if (record.status === 'cancelled') return record;
      if (childLink.signal.aborted) {
        record.status = 'failed';
        record.error = childLink.signal.reason?.message || 'The sub-agent was stopped.';
        return record;
      }
      record.status = result.status || 'completed';
      let structured = null;
      try {
        const raw = String(result.content || '').trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object') structured = parsed;
      } catch {}
      record.result = {
        runId: result.runId,
        status: structured?.status || result.status || 'completed',
        findings: Array.isArray(structured?.findings) ? structured.findings : [String(result.content || '').trim()].filter(Boolean),
        evidence: Array.isArray(structured?.evidence) ? structured.evidence : [],
        artifacts: Array.isArray(structured?.artifacts) ? structured.artifacts : [],
        confidence: ['low', 'medium', 'high'].includes(structured?.confidence) ? structured.confidence : 'medium',
        remainingBlockers: Array.isArray(structured?.remaining_blockers) ? structured.remaining_blockers : [],
        totalTokens: result.totalTokens,
        iterations: result.iterations,
        // What the run recorded, as opposed to what the child says it did.
        recorded: summarizeRun(childRunId)?.outcome || null,
      };
      if (record.write && record.result.recorded?.evidence?.actions) {
        // What it changed is not in the parent's ledger, and the parent's own earlier
        // tests say nothing about it.
        recordEventSafe({
          runId: parentRunId,
          userId,
          agentId: options.agentId || null,
          eventType: EVENT_TYPES.WORKSPACE_CHANGED,
          payload: { untracked: true, tool: 'spawn_subagent', reason: 'subagent' },
        });
      }
      engine.emit(userId, 'run:subagent', {
        runId: parentRunId,
        handle,
        childRunId,
        status: record.status,
        result: record.result,
      });
      return record;
    } catch (err) {
      const cancelled = record.status === 'cancelled' || isAbortError(err, childLink.signal);
      record.status = cancelled ? 'cancelled' : 'failed';
      record.error = cancelled ? null : (err?.message || String(err));
      engine.emit(userId, 'run:subagent', {
        runId: parentRunId,
        handle,
        childRunId,
        status: record.status,
        error: record.error,
      });
      return record;
    } finally {
      record.settled = true;
      clearTimeout(deadline);
      childLink.cleanup();
      if (record.deleteWhenSettled && engine.subagents.get(handle) === record) {
        engine.subagents.delete(handle);
      }
    }
  })();

  return {
    handle,
    status: 'running',
    childRunId,
    task: clampRunContext(task, 180),
  };
}

function listSubagents(engine, parentRunId = null) {
  return Array.from(engine.subagents.values())
    .filter((record) => !parentRunId || record.parentRunId === parentRunId)
    .map((record) => ({
      handle: record.handle,
      parentRunId: record.parentRunId,
      childRunId: record.childRunId,
      status: record.status,
      task: clampRunContext(record.task, 180),
      result: record.result,
      error: record.error,
      createdAt: record.createdAt,
    }));
}

async function cleanupSubagentsForRun(engine, parentRunId, options = {}) {
  if (!parentRunId) return { cancelled: 0, timedOut: 0 };
  const cancelRunning = options.cancelRunning !== false;
  const shutdowns = [];
  const records = [];
  for (const [handle, record] of Array.from(engine.subagents.entries())) {
    if (record.parentRunId !== parentRunId) continue;
    records.push([handle, record]);
    record.deleteWhenSettled = true;
    if (cancelRunning && record.status === 'running') {
      record.status = 'cancelled';
      engine.emit(record.userId, 'run:subagent', {
        runId: record.parentRunId,
        handle,
        childRunId: record.childRunId,
        status: 'cancelled',
      });
      shutdowns.push(Promise.resolve(record.engine?.shutdown?.({
        reason: 'Parent run finished before the sub-agent completed.',
        timeoutMs: Math.max(100, Number(options.timeoutMs) || 10000),
      })));
    } else if (record.status === 'running') {
      record.deleteWhenSettled = false;
    }
  }
  const results = await Promise.allSettled(shutdowns);
  for (const [handle, record] of records) {
    if ((record.settled || !record.promise) && engine.subagents.get(handle) === record) {
      engine.subagents.delete(handle);
    }
  }
  return {
    cancelled: shutdowns.length,
    timedOut: results.filter((result) => (
      result.status === 'fulfilled' && result.value?.timedOut === true
    )).length,
  };
}

async function waitForSubagent(engine, handle, options = {}) {
  const record = engine.subagents.get(handle);
  if (!record) {
    return { error: `Unknown sub-agent handle: ${handle}` };
  }
  if (options.parentRunId && record.parentRunId !== options.parentRunId) {
    return { error: 'That sub-agent does not belong to the current parent run.' };
  }

  if (record.status !== 'running' || !record.promise) {
    return {
      handle,
      status: record.status,
      result: record.result,
      error: record.error,
    };
  }

  const timeoutMs = Math.max(1000, Number(options.timeoutMs) || 30000);
  const timeout = new Promise((resolve) => {
    setTimeout(() => resolve(null), timeoutMs);
  });
  const settled = await Promise.race([
    record.promise.then(() => record).catch(() => record),
    timeout,
  ]);

  if (!settled) {
    return {
      handle,
      status: 'running',
      timedOut: true,
    };
  }

  return {
    handle,
    status: record.status,
    result: record.result,
    error: record.error,
  };
}

async function cancelSubagent(engine, handle, options = {}) {
  const record = engine.subagents.get(handle);
  if (!record) {
    return { error: `Unknown sub-agent handle: ${handle}` };
  }
  if (options.parentRunId && record.parentRunId !== options.parentRunId) {
    return { error: 'That sub-agent does not belong to the current parent run.' };
  }
  if (record.status !== 'running') {
    return {
      handle,
      status: record.status,
      result: record.result,
      error: record.error,
    };
  }

  record.status = 'cancelled';
  engine.emit(record.userId, 'run:subagent', {
    runId: record.parentRunId,
    handle,
    childRunId: record.childRunId,
    status: 'cancelled',
  });

  const shutdown = await record.engine?.shutdown?.({
    reason: 'Sub-agent cancelled by its parent run.',
    timeoutMs: Math.max(100, Number(options.timeoutMs) || 10000),
  });
  return {
    handle,
    status: 'cancelled',
    timedOut: shutdown?.timedOut === true,
  };
}

module.exports = {
  hasWritingSubagent,
  spawnSubagent,
  listSubagents,
  cleanupSubagentsForRun,
  waitForSubagent,
  cancelSubagent,
};
