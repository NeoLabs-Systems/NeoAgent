'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { storeWebRunReply } = require('../history');
const { fenceUntrusted } = require('../../../utils/untrusted_text');
const { createServiceLogger } = require('../../../utils/logger');
const { shortenRunId } = require('../logFormat');

const logger = createServiceLogger('Runtime');

// A run cut off by a restart is picked up again only if it was alive this
// recently: a machine that was off for a day should not come back and replay
// requests nobody is waiting on any more. The last heartbeat is the measure,
// because the startup sweep stamps completed_at with the boot time.
const RESUME_WINDOW_MINUTES = 60;

// Surfaces whose person or chat is still there after a restart. A live voice
// call has ended, the CLI's exec process has exited, sub-agents and delegations
// answer to a parent run, and scheduled work has its own retry bookkeeping.
const RESUMABLE_TRIGGER_SOURCES = new Set(['web', 'messaging']);

// Plain data a resumed run needs to work on the same surface and deliver to
// the same place. Everything else (signals, callbacks, delivery state, prior
// messages) belongs to the process that is gone.
const RESUME_OPTION_KEYS = Object.freeze([
  'title',
  'triggerType',
  'triggerSource',
  'agentId',
  'conversationId',
  'source',
  'chatId',
  'deviceTarget',
  'workspaceRoot',
  'audience',
  'memoryAudience',
  'memoryScope',
  'skipGlobalRecall',
  'context',
  'mediaAttachments',
  'model',
  'latencyProfile',
  'latencyPriority',
  'reasoningEffort',
  'modelCallTimeoutMs',
]);

const STEP_LIMIT = 40;
const SENT_MESSAGE_LIMIT = 10;

const RESUMABLE_RUNS_WHERE = `status = 'interrupted'
  AND final_delivery_id IS NULL
  AND json_extract(metadata_json, '$.resume') IS NOT NULL
  AND datetime(heartbeat_at) >= datetime('now', ?)`;

function resumeWindowModifier() {
  return `-${RESUME_WINDOW_MINUTES} minutes`;
}

/**
 * What a run records at start so it can be started again after a restart, or
 * null when it is not work a restart should pick back up. A resumed run never
 * records one: if the resumed work is what keeps bringing the server down, the
 * next boot must not start it a third time.
 */
function buildResumeEnvelope(userMessage, options = {}) {
  if (!RESUMABLE_TRIGGER_SOURCES.has(options.triggerSource || 'web')) return null;
  if (Number(options.subagentDepth) > 0 || options.triggerType === 'agent_delegation') return null;
  // A public run's scope lives in memory and is not rebuilt here, so it would
  // come back with the owner's tools.
  if (options.taskId || options.resumedFromRunId || options.audience === 'public') return null;

  const picked = {};
  for (const key of RESUME_OPTION_KEYS) {
    if (options[key] !== undefined) picked[key] = options[key];
  }
  try {
    return { message: String(userMessage || ''), options: JSON.parse(JSON.stringify(picked)) };
  } catch (error) {
    logger.warn('Run options are not serializable; the run will not resume after a restart:', error?.message || error);
    return null;
  }
}

function hasResumeEnvelope(runId) {
  return Boolean(db.prepare(
    "SELECT 1 FROM agent_runs WHERE id = ? AND json_extract(metadata_json, '$.resume') IS NOT NULL",
  ).get(runId));
}

function clearResumeEnvelope(runId) {
  db.prepare(
    `UPDATE agent_runs SET metadata_json = json_remove(metadata_json, '$.resume')
     WHERE id = ? AND json_extract(metadata_json, '$.resume') IS NOT NULL`,
  ).run(runId);
}

// Taking the envelope and naming the successor is one write, so a run resumes
// at most once even when two boots race or the server dies right after.
const claimRun = db.transaction((runId, resumedAs) => {
  const row = db.prepare(
    "SELECT json_extract(metadata_json, '$.resume') AS resume FROM agent_runs WHERE id = ?",
  ).get(runId);
  if (!row?.resume) return null;
  db.prepare(
    `UPDATE agent_runs
     SET metadata_json = json_set(json_remove(metadata_json, '$.resume'), '$.resumedAs', ?),
         updated_at = datetime('now')
     WHERE id = ?`,
  ).run(resumedAs, runId);
  return JSON.parse(row.resume);
});

/**
 * The resumed run's user turn: the original request plus what the cut-off run
 * already did, so the model continues instead of starting over. The original
 * user turn is already in the conversation and is not stored again.
 */
function buildContinuationNote(runId, message) {
  const steps = db.prepare(
    `SELECT description, status FROM agent_steps
     WHERE run_id = ? AND status IN ('completed', 'interrupted')
     ORDER BY step_index DESC LIMIT ?`,
  ).all(runId, STEP_LIMIT).reverse();
  const sent = db.prepare(
    `SELECT payload_json FROM agent_outbox
     WHERE run_id = ? AND message_kind != 'final' AND status = 'delivered'
     ORDER BY created_at DESC LIMIT ?`,
  ).all(runId, SENT_MESSAGE_LIMIT).reverse()
    .map((row) => String(JSON.parse(row.payload_json || '{}').content || '').slice(0, 400))
    .filter(Boolean);

  const log = [
    steps.length
      ? `Tool calls (oldest first):\n${steps.map((step) => (
        `- ${step.status === 'completed' ? 'done' : 'cut off mid-call'}: ${step.description}`
      )).join('\n')}`
      : 'It had not finished any tool calls.',
    sent.length ? `Messages it already sent to the user:\n${sent.map((text) => `- ${text}`).join('\n')}` : '',
  ].filter(Boolean).join('\n\n');

  return [
    '[Resumed after a restart]',
    'NeoAgent restarted while you were working on the request below, which ended that run early. This run continues the same task; nothing new has come from the user.',
    `Original request:\n${message}`,
    `What the interrupted run already did:\n${fenceUntrusted('external_interrupted_run', log)}`,
    'Pick up where it stopped. Do not repeat completed actions or resend messages already sent. A call that was cut off may or may not have taken effect, so check before redoing it. Then answer the original request as you normally would.',
  ].join('\n\n');
}

function startResumedRun(agentEngine, run, runId, { message, options }) {
  agentEngine.run(run.user_id, buildContinuationNote(run.id, message), {
    ...options,
    title: options.title || message,
    context: { ...(options.context || {}), rawUserMessage: options.context?.rawUserMessage || message },
    runId,
    resumedFromRunId: run.id,
  }).then((result) => {
    // On the web the caller that awaited the run writes the chat transcript;
    // that caller is gone, so this one does it.
    if ((options.triggerSource || 'web') === 'web') {
      storeWebRunReply({
        userId: run.user_id,
        agentId: run.agent_id,
        conversationId: options.conversationId || null,
        result,
        platform: 'web',
      });
    }
  }).catch((error) => {
    logger.error(`Resumed run ${shortenRunId(runId)} (from ${shortenRunId(run.id)}) failed:`, error?.message || error);
  });
}

/**
 * Start a new run for every recent run a restart cut off. Runs are started
 * concurrently and not awaited, so boot never waits on agent work.
 */
function resumeInterruptedRuns(agentEngine) {
  const candidates = db.prepare(
    `SELECT id, user_id, agent_id FROM agent_runs WHERE ${RESUMABLE_RUNS_WHERE} ORDER BY heartbeat_at ASC`,
  ).all(resumeWindowModifier());
  const resumed = [];
  for (const run of candidates) {
    const runId = randomUUID();
    const envelope = claimRun.immediate(run.id, runId);
    if (!envelope) continue;
    agentEngine.recordRunEvent(run.user_id, run.id, 'run_resumed', { resumedAs: runId }, { agentId: run.agent_id });
    startResumedRun(agentEngine, run, runId, envelope);
    resumed.push(`${shortenRunId(run.id)}->${shortenRunId(runId)}`);
  }
  if (resumed.length) logger.info(`Resuming ${resumed.length} run(s) a restart interrupted: ${resumed.join(', ')}`);
  return resumed.length;
}

// How many runs the next boot will resume. Read-only, for the CLI to report
// right after it stops the server.
function countResumableRuns() {
  return db.prepare(
    `SELECT COUNT(*) AS n FROM agent_runs WHERE ${RESUMABLE_RUNS_WHERE}`,
  ).get(resumeWindowModifier()).n;
}

module.exports = {
  buildResumeEnvelope,
  clearResumeEnvelope,
  countResumableRuns,
  hasResumeEnvelope,
  resumeInterruptedRuns,
};
