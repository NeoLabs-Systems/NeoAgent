'use strict';

const { createHash } = require('crypto');
const { EVENT_TYPES, VISIBILITY } = require('../events/event_types');
const { requestProgressDelivery } = require('./delivery_worker');
const { MESSAGE_KINDS } = require('../constants');

const DEFAULT_TICK_MS = 15_000;

function hashProgress(delta) {
  return createHash('sha256').update(JSON.stringify(delta || {})).digest('hex');
}

/**
 * Liveness is deterministic and derived only from observed runtime activity.
 * Narration is optional and may only phrase a delta the runtime already saw —
 * it can never introduce a fact, and there is no canned status text.
 *
 * The broker owns the heartbeat for every channel, so a run that spends minutes
 * inside a single tool or model call still reports in.
 */
function createProgressBroker({
  engine,
  runId,
  userId,
  agentId = null,
  eventBus = null,
  narrator = null,
  collectDelta = null,
  isSuppressed = null,
  getLastVisibleAt = null,
  channel = 'web',
  recipient = null,
  deliveryMetadata = null,
  tickMs = DEFAULT_TICK_MS,
  maxSilenceSeconds = 90,
  firstUpdateSeconds = 25,
  repeatUpdateSeconds = 90,
} = {}) {
  let lastUserUpdateAt = 0;
  let lastProgressHash = null;
  let lastActivityAt = Date.now();
  let acceptedAt = Date.now();
  let currentPhase = 'idle';
  let runningTools = 0;
  let timer = null;
  let tickInFlight = false;

  function noteActivity(kind = 'activity', details = {}) {
    lastActivityAt = Date.now();
    currentPhase = kind;
    if (eventBus) {
      eventBus.publish({
        runId,
        userId,
        agentId,
        eventType: EVENT_TYPES.NODE_PROGRESS,
        payload: { kind, ...details },
        visibility: VISIBILITY.INTERNAL,
      });
    }
  }

  // A tool that is still executing is real work, however long it takes. Without
  // this the stall threshold would misreport a 20-minute build as a dead run.
  function noteToolStarted(toolName) {
    runningTools += 1;
    noteActivity('tool_started', { tool: toolName });
  }

  function noteToolFinished(toolName) {
    runningTools = Math.max(0, runningTools - 1);
    noteActivity('tool_completed', { tool: toolName });
  }

  function evaluateLiveness({ waiting = false, blocked = false } = {}) {
    const now = Date.now();
    const silentForMs = now - lastActivityAt;
    const sinceAcceptedMs = now - acceptedAt;
    const base = { silentForMs, sinceAcceptedMs, phase: currentPhase, runningTools };
    if (blocked) return { ...base, status: 'blocked' };
    if (waiting) return { ...base, status: 'waiting' };
    if (runningTools > 0) return { ...base, status: 'working' };
    if (silentForMs > maxSilenceSeconds * 1000) return { ...base, status: 'stalled' };
    if (silentForMs > (maxSilenceSeconds * 1000) / 2) return { ...base, status: 'quiet' };
    return { ...base, status: 'alive' };
  }

  function buildDelta({
    completed = [],
    running = [],
    artifacts = [],
    blockers = [],
    planChanges = [],
    nextMilestone = null,
    evidence = [],
  } = {}) {
    return {
      completed_since_last_update: completed,
      currently_running: running,
      new_artifacts: artifacts,
      blockers,
      plan_changes: planChanges,
      next_milestone: nextMilestone,
      evidence,
    };
  }

  function hasRealDelta(delta) {
    return Boolean(
      delta?.completed_since_last_update?.length
      || delta?.currently_running?.length
      || delta?.new_artifacts?.length
      || delta?.blockers?.length
      || delta?.plan_changes?.length
      || delta?.evidence?.length
      || delta?.next_milestone,
    );
  }

  async function narrate(delta, liveness) {
    if (typeof narrator !== 'function' || !hasRealDelta(delta)) return null;
    try {
      const text = await narrator({ delta, liveness });
      return String(text || '').trim() || null;
    } catch {
      return null;
    }
  }

  async function maybePublish({
    delta,
    channel: overrideChannel = null,
    recipient: overrideRecipient = null,
    force = false,
  } = {}) {
    if (typeof isSuppressed === 'function' && isSuppressed()) {
      return { sent: false, reason: 'suppressed' };
    }

    const liveness = evaluateLiveness({
      blocked: (delta?.blockers || []).length > 0,
      waiting: Boolean(delta?.waiting),
    });
    const now = Date.now();
    // The hash covers only the observable milestone state, never the raw
    // evidence text, so re-reading the same node does not re-notify.
    const hash = hashProgress({
      completed: delta?.completed_since_last_update,
      running: delta?.currently_running,
      artifacts: delta?.new_artifacts,
      blockers: delta?.blockers,
      plan: delta?.plan_changes,
      next: delta?.next_milestone,
    });
    // The model can publish its own interim update through send_interim_update.
    // Cadence is measured from whichever visible update happened last, so the
    // heartbeat never talks over the agent.
    const externalVisibleAt = typeof getLastVisibleAt === 'function'
      ? Number(getLastVisibleAt()) || 0
      : 0;
    const lastVisibleAt = Math.max(lastUserUpdateAt, externalVisibleAt);
    const firstDue = lastVisibleAt === 0 && (now - acceptedAt) >= firstUpdateSeconds * 1000;
    const repeatDue = lastVisibleAt > 0 && (now - lastVisibleAt) >= repeatUpdateSeconds * 1000;

    if (!force && !firstDue && !repeatDue) {
      return { sent: false, reason: 'not_due', liveness };
    }
    const groundedToolHeartbeat = repeatDue && Number(liveness.runningTools) > 0;
    if (!force && hash === lastProgressHash && !groundedToolHeartbeat) {
      return { sent: false, reason: 'unchanged', liveness };
    }

    const text = await narrate(delta || buildDelta(), liveness);
    if (!text) {
      return { sent: false, reason: 'no_real_delta', liveness };
    }
    // The run may have finished while narration was in flight.
    if (typeof isSuppressed === 'function' && isSuppressed()) {
      return { sent: false, reason: 'suppressed', liveness };
    }

    if (eventBus) {
      eventBus.publish({
        runId,
        userId,
        agentId,
        eventType: EVENT_TYPES.PROGRESS_USER_UPDATE,
        payload: { text, delta, liveness },
        visibility: VISIBILITY.USER,
      });
    }

    const result = await requestProgressDelivery({
      engine,
      runId,
      content: text,
      channel: overrideChannel || channel,
      recipient: overrideRecipient || recipient,
      messageKind: MESSAGE_KINDS.PROGRESS,
      metadata: {
        ...(deliveryMetadata && typeof deliveryMetadata === 'object'
          ? deliveryMetadata
          : {}),
        idempotencyKey: groundedToolHeartbeat
          ? `${runId}:progress:${hash}:heartbeat:${Math.floor(now / (Math.max(1, repeatUpdateSeconds) * 1000))}`
          : `${runId}:progress:${hash}`,
        progressHash: hash,
        liveness,
      },
    });

    if (result.ok) {
      lastUserUpdateAt = now;
      lastProgressHash = hash;
    }
    return { sent: result.ok === true, result, text, liveness };
  }

  async function tick() {
    if (tickInFlight) return { sent: false, reason: 'tick_in_flight' };
    tickInFlight = true;
    try {
      const delta = typeof collectDelta === 'function' ? collectDelta() : null;
      if (!delta) return { sent: false, reason: 'no_delta_source' };
      return await maybePublish({ delta });
    } catch (error) {
      console.warn('[Runtime] Progress tick failed:', error?.message || error);
      return { sent: false, reason: 'tick_failed' };
    } finally {
      tickInFlight = false;
    }
  }

  function start() {
    if (timer) return false;
    timer = setInterval(() => { tick(); }, Math.max(1000, Number(tickMs) || DEFAULT_TICK_MS));
    timer.unref?.();
    return true;
  }

  function stop() {
    if (!timer) return false;
    clearInterval(timer);
    timer = null;
    return true;
  }

  function markAccepted() {
    acceptedAt = Date.now();
    lastActivityAt = acceptedAt;
  }

  return {
    noteActivity,
    noteToolStarted,
    noteToolFinished,
    evaluateLiveness,
    buildDelta,
    maybePublish,
    markAccepted,
    tick,
    start,
    stop,
  };
}

module.exports = {
  createProgressBroker,
};
