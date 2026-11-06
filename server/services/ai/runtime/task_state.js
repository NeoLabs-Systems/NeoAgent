'use strict';

const { clampRunContext } = require('../messagingFallback');
const { changedPaths } = require('./workspace_checkpoint');

// The state a long run must not lose: what it is doing, what it has verified, and
// what it changed. The model keeps the ledger with task_ledger; the harness adds
// only what it saw itself. It survives compaction word for word, feeds recovery,
// and is what the Runs tab shows, so no raw reasoning needs to be kept for any of
// that.
const TASK_STATE_PREFIX = '[Task state]';
const STEP_STATUSES = new Set(['pending', 'active', 'done', 'blocked']);

function textList(value, { limit = 12, maxChars = 240 } = {}) {
  return (Array.isArray(value) ? value : [])
    .map((item) => clampRunContext(item, maxChars))
    .filter(Boolean)
    .slice(0, limit);
}

function normalizeSteps(value) {
  return (Array.isArray(value) ? value : [])
    .map((step, index) => {
      const entry = typeof step === 'string' ? { id: step } : (step || {});
      const id = clampRunContext(entry.id || entry.step || entry.title || `step_${index + 1}`, 120);
      const status = String(entry.status || 'pending').toLowerCase();
      return { id, status: STEP_STATUSES.has(status) ? status : 'pending' };
    })
    .slice(0, 24);
}

// Sent fields replace what the ledger held; anything left out stays.
function mergeLedger(current, args = {}) {
  const next = { ...(current || {}) };
  if (args.goal) next.goal = clampRunContext(args.goal, 400);
  if (args.constraints) next.constraints = textList(args.constraints);
  if (args.steps) next.steps = normalizeSteps(args.steps);
  if (args.observations) next.observations = textList(args.observations, { limit: 20 });
  if (args.blockers) next.blockers = textList(args.blockers);
  return next;
}

function updateTaskLedger(engine, runId, args = {}) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) return { error: 'The run is no longer active.' };
  runMeta.ledger = mergeLedger(runMeta.ledger, args);
  engine.persistRunMetadata(runId, { ledger: runMeta.ledger });
  return { recorded: true };
}

function taskGoal(session) {
  const ledger = session.engine.getRunMeta?.(session.runId)?.ledger;
  return ledger?.goal
    || clampRunContext(session.options?.context?.rawUserMessage || session.userMessage, 400);
}

function noteChangedPath(session, toolArgs = {}) {
  const changed = toolArgs.path;
  if (!changed) return;
  session.changedPaths ||= new Set();
  session.changedPaths.add(String(changed));
}

function buildTaskStateNote(session) {
  const ledger = session.engine.getRunMeta?.(session.runId)?.ledger || null;
  const lines = [TASK_STATE_PREFIX, `Goal: ${taskGoal(session)}`];
  if (ledger?.constraints?.length) lines.push(`Constraints: ${ledger.constraints.join('; ')}`);
  if (ledger?.steps?.length) {
    lines.push(`Steps: ${ledger.steps.map((step) => `${step.id} [${step.status}]`).join(', ')}`);
  }
  if (ledger?.observations?.length) lines.push(`Your notes (not checked by anything): ${ledger.observations.join('; ')}`);
  if (ledger?.blockers?.length) lines.push(`Blockers: ${ledger.blockers.join('; ')}`);
  // From here on, recorded by the harness rather than written by the model.
  const changed = [...new Set([...(session.changedPaths || []), ...changedPaths(session)])];
  if (changed.length) lines.push(`Recorded: files changed in this run: ${changed.slice(-30).join(', ')}`);
  if (session.lastCheck) lines.push(`Recorded: last check: ${session.lastCheck}`);
  return lines.join('\n');
}

// After a compaction the note sits right behind the summary it complements, in
// the leading section that later compactions keep as it is.
function placeTaskStateNote(session) {
  const messages = session.messages.filter((message) => !(
    message.role === 'system' && String(message.content || '').startsWith(TASK_STATE_PREFIX)
  ));
  let index = 0;
  while (index < messages.length && messages[index]?.role === 'system') index += 1;
  messages.splice(index, 0, { role: 'system', content: buildTaskStateNote(session) });
  session.messages = messages;
}

module.exports = {
  TASK_STATE_PREFIX,
  buildTaskStateNote,
  mergeLedger,
  noteChangedPath,
  placeTaskStateNote,
  taskGoal,
  updateTaskLedger,
};
