'use strict';

const { createHash } = require('crypto');
const { EVENT_TYPES, VISIBILITY } = require('../events/event_types');
const { requestProgressDelivery } = require('./delivery_worker');
const { MESSAGE_KINDS } = require('../constants');

function hashProgress(delta) {
  return createHash('sha256').update(JSON.stringify(delta || {})).digest('hex');
}

/**
 * Liveness is deterministic; narration may only summarize real deltas.
 */
function createProgressBroker({
  engine,
  runId,
  userId,
  eventBus = null,
  maxSilenceSeconds = 90,
  firstUpdateSeconds = 25,
  repeatUpdateSeconds = 90,
} = {}) {
  let lastUserUpdateAt = 0;
  let lastProgressHash = null;
  let lastActivityAt = Date.now();
  let acceptedAt = Date.now();

  function noteActivity(kind = 'activity', details = {}) {
    lastActivityAt = Date.now();
    if (eventBus) {
      eventBus.publish({
        runId,
        userId,
        eventType: EVENT_TYPES.NODE_PROGRESS,
        payload: { kind, ...details },
        visibility: VISIBILITY.INTERNAL,
      });
    }
  }

  function evaluateLiveness({ state = 'executing', waiting = false, blocked = false } = {}) {
    const now = Date.now();
    const silentForMs = now - lastActivityAt;
    const sinceAcceptedMs = now - acceptedAt;
    if (blocked) {
      return { status: 'blocked', silentForMs, sinceAcceptedMs };
    }
    if (waiting) {
      return { status: 'waiting', silentForMs, sinceAcceptedMs };
    }
    if (silentForMs > maxSilenceSeconds * 1000) {
      return { status: 'stalled', silentForMs, sinceAcceptedMs };
    }
    if (silentForMs > (maxSilenceSeconds * 1000) / 2) {
      return { status: 'quiet', silentForMs, sinceAcceptedMs };
    }
    return { status: 'alive', silentForMs, sinceAcceptedMs, state };
  }

  function buildDelta({
    completed = [],
    running = [],
    artifacts = [],
    blockers = [],
    planChanges = [],
    nextMilestone = null,
  } = {}) {
    return {
      completed_since_last_update: completed,
      currently_running: running,
      new_artifacts: artifacts,
      blockers,
      plan_changes: planChanges,
      next_milestone: nextMilestone,
    };
  }

  function narrate(delta, liveness) {
    const parts = [];
    if (delta.completed_since_last_update?.length) {
      parts.push(`Completed: ${delta.completed_since_last_update.join(', ')}`);
    }
    if (delta.currently_running?.length) {
      parts.push(`In progress: ${delta.currently_running.join(', ')}`);
    }
    if (delta.new_artifacts?.length) {
      parts.push(`Artifacts: ${delta.new_artifacts.join(', ')}`);
    }
    if (delta.blockers?.length) {
      parts.push(`Blocked: ${delta.blockers.join(', ')}`);
    }
    if (delta.next_milestone) {
      parts.push(`Next: ${delta.next_milestone}`);
    }
    if (parts.length === 0) {
      if (liveness.status === 'stalled') {
        return 'Still working; no new milestones since the last update. Investigating the delay.';
      }
      if (liveness.status === 'waiting') {
        return 'Waiting on an external dependency or approval.';
      }
      return null;
    }
    return parts.join('. ') + '.';
  }

  async function maybePublish({
    delta,
    channel = 'web',
    recipient = null,
    force = false,
  } = {}) {
    const liveness = evaluateLiveness({
      blocked: (delta?.blockers || []).length > 0,
      waiting: Boolean(delta?.waiting),
    });
    const now = Date.now();
    const hash = hashProgress(delta);
    const sinceLast = now - lastUserUpdateAt;
    const firstDue = lastUserUpdateAt === 0 && (now - acceptedAt) >= firstUpdateSeconds * 1000;
    const repeatDue = lastUserUpdateAt > 0 && sinceLast >= repeatUpdateSeconds * 1000;
    const stalled = liveness.status === 'stalled' || liveness.status === 'blocked';

    if (!force && !firstDue && !repeatDue && !stalled) {
      return { sent: false, reason: 'not_due', liveness };
    }
    if (!force && hash === lastProgressHash && !stalled) {
      return { sent: false, reason: 'unchanged', liveness };
    }

    const text = narrate(delta || buildDelta(), liveness);
    if (!text) {
      return { sent: false, reason: 'no_real_delta', liveness };
    }

    if (eventBus) {
      eventBus.publish({
        runId,
        userId,
        eventType: EVENT_TYPES.PROGRESS_USER_UPDATE,
        payload: { text, delta, liveness },
        visibility: VISIBILITY.USER,
      });
    }

    const result = await requestProgressDelivery({
      engine,
      runId,
      content: text,
      channel,
      recipient,
      messageKind: MESSAGE_KINDS.PROGRESS,
      metadata: {
        idempotencyKey: `${runId}:progress:${hash}`,
        progressHash: hash,
      },
    });

    if (result.ok) {
      lastUserUpdateAt = now;
      lastProgressHash = hash;
    }
    return { sent: result.ok === true, result, text, liveness };
  }

  function markAccepted() {
    acceptedAt = Date.now();
    lastActivityAt = acceptedAt;
  }

  return {
    noteActivity,
    evaluateLiveness,
    buildDelta,
    narrate,
    maybePublish,
    markAccepted,
  };
}

module.exports = {
  createProgressBroker,
  hashProgress,
};
