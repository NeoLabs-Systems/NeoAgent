'use strict';

const db = require('../../../db/database');
const { clampRunContext } = require('../messagingFallback');

const RECENT_STEP_LIMIT = 5;

// A live owner chat run that has told the user it is working on something
// (its opening line or a progress update) keeps running in the background.
// The chat is free again: the next message starts a new foreground run that
// sees the background work and can check on, instruct, or cancel it. The
// background run keeps its own progress updates and delivers its own result.
// A live voice call hands work off and keeps talking, so its runs are
// background work from the start.

const OWNER_SURFACES = new Set(['web', 'messaging', 'voice_live']);

function isBackgroundEligible({ triggerType, triggerSource, memoryAudience }) {
  return triggerType === 'user'
    && OWNER_SURFACES.has(triggerSource)
    && memoryAudience !== 'shared';
}

function moveRunToBackground(engine, runId) {
  const runMeta = engine.getRunMeta(runId);
  if (
    !runMeta?.backgroundEligible
    || runMeta.background
    || runMeta.aborted
    || runMeta.finalDeliverySent
  ) {
    return false;
  }
  runMeta.background = { since: new Date().toISOString() };
  engine.persistRunMetadata(runId, { background: runMeta.background });
  engine.recordRunEvent(runMeta.userId, runId, 'run_backgrounded', {}, { agentId: runMeta.agentId });
  engine.emit(runMeta.userId, 'run:background', {
    runId,
    conversationId: runMeta.conversationId || null,
  });
  runMeta.onBackground?.();
  return true;
}

// The tool steps the run has recorded are the live evidence of what it is
// doing; they are written as each tool starts and finishes.
function recentSteps(runId) {
  return db.prepare(
    `SELECT description, status, started_at, completed_at, error
     FROM agent_steps WHERE run_id = ? ORDER BY step_index DESC LIMIT ?`,
  ).all(runId, RECENT_STEP_LIMIT).reverse().map((step) => ({
    step: step.description,
    status: step.status,
    started_at: step.started_at,
    ...(step.completed_at ? { completed_at: step.completed_at } : {}),
    ...(step.error ? { error: clampRunContext(step.error, 200) } : {}),
  }));
}

function describeRun(runId, runMeta) {
  let status = runMeta.status === 'paused' ? 'paused' : 'running';
  if (runMeta.terminalInterim) status = 'waiting_for_user';
  return {
    run_id: runId,
    request: runMeta.request,
    channel: runMeta.messagingContext?.platform || runMeta.triggerSource,
    started_at: runMeta.startedAtIso || null,
    status,
    last_update_to_user_at: runMeta.progressLedger?.lastUserVisibleUpdateAt || null,
    recent_steps: recentSteps(runId),
  };
}

// A live voice call has no foreground of its own, so it also sees the chat
// run that is still in the foreground (includeForeground).
function listBackgroundRuns(engine, { userId, agentId, excludeRunId = null, includeForeground = false }) {
  const runs = [];
  for (const [runId, runMeta] of engine.activeRuns.entries()) {
    if (runId === excludeRunId || !runMeta.backgroundEligible || runMeta.aborted) continue;
    if (!runMeta.background && !includeForeground) continue;
    if (runMeta.userId !== userId || runMeta.agentId !== agentId) continue;
    runs.push(describeRun(runId, runMeta));
  }
  return runs;
}

function buildBackgroundRunsNote(runs) {
  if (!runs.length) return '';
  return [
    '[Background tasks]',
    'These tasks the user started earlier are still running in the background. Each reports its own progress and delivers its own result to the user.',
    ...runs.map((run) => {
      const latest = run.recent_steps[run.recent_steps.length - 1];
      const activity = latest ? ` Latest step (${latest.status}): ${clampRunContext(latest.step, 160)}.` : '';
      return `- run_id ${run.run_id} (${run.channel}, started ${run.started_at}, ${run.status}): ${clampRunContext(run.request, 300)}${activity}`;
    }),
    'Treat the user\'s new message as its own request unless it is about one of these tasks. When it is, use background_task: "status" for a fresh look, "instruct" to pass on a change or addition, "cancel" to stop it.',
    'Do not redo a background task\'s work yourself, and never say one has finished before its result arrives.',
  ].join('\n');
}

function manageBackgroundRun(engine, callerRunId, args = {}) {
  const caller = engine.getRunMeta(callerRunId);
  if (!caller?.backgroundEligible) {
    return { error: 'Background tasks can only be managed from the owner\'s own chat.' };
  }
  const runs = listBackgroundRuns(engine, {
    userId: caller.userId,
    agentId: caller.agentId,
    excludeRunId: callerRunId,
  });
  return applyBackgroundAction(engine, {
    userId: caller.userId,
    agentId: caller.agentId,
    runs,
    origin: { fromRunId: callerRunId },
  }, args);
}

// status, instruct, or cancel one of the listed runs. Shared by the chat's
// background_task tool and the live voice call's task tools; origin names
// where the instruction came from in the run's event log.
function applyBackgroundAction(engine, { userId, agentId, runs, origin }, args = {}) {
  const action = String(args.action || '').trim();
  const targetId = String(args.run_id || '').trim();
  if (action === 'status' && !targetId) return { background_tasks: runs };

  const target = runs.find((run) => run.run_id === targetId);
  if (!target) {
    return {
      error: `No background task with run_id "${targetId}" is running.`,
      background_tasks: runs,
    };
  }

  if (action === 'status') return { background_task: target };

  if (action === 'instruct') {
    const instruction = String(args.instruction || '').trim();
    if (!instruction) return { error: 'The instruct action needs an instruction.' };
    const queued = engine.enqueueSystemSteering(targetId, [
      'The user sent a new instruction for this task from their ongoing conversation.',
      'Apply it from your next step on:',
      instruction,
    ].join('\n'), { reason: 'background_instruction' });
    engine.recordRunEvent(userId, targetId, 'background_instruction', {
      ...origin,
      instruction: clampRunContext(instruction, 500),
    }, { agentId });
    return {
      instructed: Boolean(queued),
      run_id: targetId,
      note: queued
        ? 'The task applies the instruction at its next step.'
        : 'The same instruction is already waiting for the task.',
    };
  }

  if (action === 'cancel') {
    const cancelled = engine.abort(targetId, {
      userId,
      reason: 'Cancelled by the user from their ongoing conversation.',
    });
    return { cancelled, run_id: targetId };
  }

  return { error: 'action must be status, instruct, or cancel.' };
}

// Foreground runs of the same agent learn that background work ended, so they
// do not keep describing it as running. Later runs see the result in history.
function announceBackgroundRunEnded(engine, runId, runMeta) {
  if (!runMeta?.background) return;
  let outcome = 'ended without delivering a result';
  if (runMeta.aborted) outcome = 'was cancelled';
  else if (runMeta.finalDeliverySent) outcome = 'finished and its result was delivered to the user';
  const result = runMeta.finalDeliverySent ? clampRunContext(runMeta.lastSentMessage, 1500) : '';
  const note = [
    `Background task ${runId} (${clampRunContext(runMeta.request, 200)}) ${outcome}.`,
    result ? `Its result:\n${result}` : '',
  ].filter(Boolean).join('\n');
  for (const [otherId, other] of engine.activeRuns.entries()) {
    if (otherId === runId || other.background || other.aborted || !other.backgroundEligible) continue;
    if (other.userId !== runMeta.userId || other.agentId !== runMeta.agentId) continue;
    engine.enqueueSystemSteering(otherId, note, { reason: 'background_task_ended' });
  }
}

module.exports = {
  announceBackgroundRunEnded,
  applyBackgroundAction,
  buildBackgroundRunsNote,
  isBackgroundEligible,
  listBackgroundRuns,
  manageBackgroundRun,
  moveRunToBackground,
};
