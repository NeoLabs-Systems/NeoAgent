'use strict';

const { clampRunContext } = require('../messagingFallback');
const { renderFragment } = require('../prompts/registry');
const { EVENT_TYPES } = require('./events/event_types');
const { taskGoal } = require('./task_state');

// Reflection only when something actually went wrong. A failing or spinning run
// gets a note on its next regular turn, so a healthy run pays nothing and even a
// struggling one pays no extra model call. The runaway guards still end a run
// that stays stuck after this.
const MAX_RECOVERY_NOTES = 3;
const RECOVERY_TRIGGER_TURNS = 2;

const REASON_TEXT = Object.freeze({
  tool_failures: 'every call in the last steps failed',
  same_action: 'the same call keeps being repeated',
  no_progress: 'the last steps changed nothing and found nothing new',
});

function recoveryReason({ failedTurns = 0, sameActionTurns = 0, idleTurns = 0 } = {}) {
  if (failedTurns >= RECOVERY_TRIGGER_TURNS) return 'tool_failures';
  if (sameActionTurns >= RECOVERY_TRIGGER_TURNS) return 'same_action';
  if (idleTurns >= RECOVERY_TRIGGER_TURNS) return 'no_progress';
  return null;
}

function describeActions(toolExecutions, limit = 4) {
  return toolExecutions.slice(-limit).map((item) => (
    `- ${item.toolName}: ${item.ok ? 'ok' : `failed (${clampRunContext(item.error, 160)})`}`
  )).join('\n');
}

function describeFailures(toolExecutions) {
  const failures = [...new Set(
    toolExecutions.slice(-6).filter((item) => !item.ok).map((item) => clampRunContext(item.error, 200)),
  )].slice(0, 3);
  return failures.length ? `Failures:\n${failures.map((text) => `- ${text}`).join('\n')}\n` : '';
}

/**
 * Adds the recovery note when a run has just become stuck. It re-arms once the
 * run gets moving again, so a second, separate problem can get its own note.
 */
function applyRecovery(session) {
  session.recovery ||= { notes: 0, armed: true };
  const { recovery } = session;
  const reason = recoveryReason(session.guards.streaks());
  if (!reason) {
    recovery.armed = true;
    return null;
  }
  if (!recovery.armed || recovery.notes >= MAX_RECOVERY_NOTES) return null;
  recovery.armed = false;
  recovery.notes += 1;

  session.messages.push({
    role: 'system',
    content: renderFragment('runtime/recovery.md', {
      reason: REASON_TEXT[reason],
      goal: taskGoal(session),
      actions: describeActions(session.toolExecutions),
      failures: describeFailures(session.toolExecutions),
    }),
  });
  session.eventBus.publish({
    runId: session.runId,
    userId: session.userId,
    agentId: session.agentId,
    eventType: EVENT_TYPES.RECOVERY_TRIGGERED,
    payload: {
      reason,
      note_number: recovery.notes,
      iteration: session.iterations,
      ...session.guards.streaks(),
    },
  });
  return reason;
}

module.exports = {
  MAX_RECOVERY_NOTES,
  applyRecovery,
  recoveryReason,
};
