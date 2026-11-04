'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');

// Raw prompts stay out of the permanent ledger. A run keeps its model requests
// only when someone asked for that run or (written when it ends) when it failed. Captures expire much sooner than the
// metrics, and private reasoning is never written at all.

const CAPTURE_NEXT_KEY = 'run_capture_next';
const FAILURE_REASON = 'failure';
const CAPTURE_TTL_HOURS = 168;

function requestCaptureNextRun(userId, agentId = null) {
  db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, 'true')
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = 'true'`,
  ).run(userId, resolveAgentId(userId, agentId), CAPTURE_NEXT_KEY);
}

function isCaptureNextRunRequested(userId, agentId = null) {
  return Boolean(db.prepare(
    'SELECT 1 FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?',
  ).get(userId, resolveAgentId(userId, agentId), CAPTURE_NEXT_KEY));
}

function consumeCaptureNextRun(userId, agentId) {
  return db.prepare(
    'DELETE FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?',
  ).run(userId, agentId, CAPTURE_NEXT_KEY).changes > 0;
}

// Decided once, when the run starts. Sub-agents and delegated runs follow their
// own settings like any other run.
function decideCapture({ userId, agentId, options = {} }) {
  if (options.captureContent === true) return { enabled: true, reason: 'requested', ttlHours: CAPTURE_TTL_HOURS };
  if (consumeCaptureNextRun(userId, agentId)) return { enabled: true, reason: 'capture_next', ttlHours: CAPTURE_TTL_HOURS };
  return { enabled: false, reason: null, ttlHours: CAPTURE_TTL_HOURS };
}

// Reasoning state goes back to the provider in the live request and nowhere else.
function withoutReasoning(messages) {
  return (messages || []).map((message) => {
    if (!message?.reasoningState && !message?.providerContentBlocks) return message;
    const { reasoningState, providerContentBlocks, ...rest } = message;
    return rest;
  });
}

function writeCapture({
  runId,
  userId,
  capture,
  reason,
  phase = 'model_turn',
  iteration = 0,
  provider = null,
  model = null,
  maxTokens,
  reasoningEffort,
  messages = [],
  tools = [],
  requestId = randomUUID(),
}) {
  const ttlHours = Number(capture?.ttlHours) || 168;
  const payload = {
    header: { phase, iteration: Number(iteration) || 0, provider, model, maxTokens, reasoningEffort },
    messages: withoutReasoning(messages),
    tools,
  };
  db.prepare(
    `INSERT OR IGNORE INTO agent_run_captures (
      run_id, user_id, request_id, phase, iteration, provider, model, reason, payload_json, expires_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now', ?))`,
  ).run(
    runId,
    userId,
    requestId,
    phase,
    Number(iteration) || 0,
    provider,
    model,
    reason,
    JSON.stringify(payload),
    `+${Math.floor(ttlHours)} hours`,
  );
  return requestId;
}

function captureRequest(runMeta, request) {
  if (!runMeta?.capture?.enabled) return null;
  try {
    return writeCapture({ ...request, capture: runMeta.capture, reason: runMeta.capture.reason });
  } catch (error) {
    console.warn('[RunCapture] Could not store a prompt capture:', error?.message || error);
    return null;
  }
}

// A failed run is the one someone will want to look at, so it keeps what its
// last turn saw even when it was not sampled.
function captureFailure({ runId, userId, capture, session }) {
  if (capture?.enabled || !session?.messages?.length) return;
  try {
    writeCapture({
      runId,
      userId,
      capture,
      reason: FAILURE_REASON,
      phase: 'failure',
      iteration: session.iterations,
      provider: session.model?.providerName || null,
      model: session.model?.model || null,
      messages: session.messages,
      tools: session.tools,
    });
  } catch (error) {
    console.warn('[RunCapture] Could not store the failed run\'s prompt:', error?.message || error);
  }
}

function pruneExpiredCaptures() {
  // Detailed steps are operational content too. Keep metadata/metrics, but expire
  // content only after terminal runs; active/interrupted recovery must retain inputs.
  db.prepare(`UPDATE agent_steps SET tool_input = NULL, result = NULL, error = NULL,
      description = type
    WHERE run_id IN (SELECT id FROM agent_runs WHERE status IN ('completed', 'failed', 'stopped', 'cancelled')
      AND completed_at < datetime('now', '-7 days')
      AND (metadata_json IS NULL OR json_valid(metadata_json))
      AND json_extract(CASE WHEN json_valid(metadata_json) THEN metadata_json ELSE '{}' END, '$.resume') IS NULL
      AND NOT EXISTS (SELECT 1 FROM agent_runs successor
        WHERE successor.id = json_extract(CASE WHEN json_valid(agent_runs.metadata_json) THEN agent_runs.metadata_json ELSE '{}' END, '$.resumedAs')
          AND successor.status IN ('running', 'paused', 'interrupted')))
      AND (tool_input IS NOT NULL OR result IS NOT NULL OR error IS NOT NULL)`).run();
  return db.prepare("DELETE FROM agent_run_captures WHERE datetime(expires_at) <= datetime('now')").run().changes;
}

function hasCaptures(runId) {
  return Boolean(db.prepare('SELECT 1 FROM agent_run_captures WHERE run_id = ? LIMIT 1').get(runId));
}

module.exports = {
  captureFailure,
  captureRequest,
  decideCapture,
  hasCaptures,
  isCaptureNextRunRequested,
  pruneExpiredCaptures,
  requestCaptureNextRun,
};
