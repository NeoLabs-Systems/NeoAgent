'use strict';

const { resolveAgentId } = require('../agents/manager');
const adapters = require('./adapters');
const { MINUTE_MS } = require('./adapters/shared');
const { normalizeJsonObject } = require('./utils');

/**
 * Polled trigger adapters declare:
 *   poll.intervalMinutes  number or (config) => number; the runtime ticks each minute
 *   poll.cursor           'list'    → rows are the latest items, and the
 *                                     checkpoint is the last one fired
 *                         'ordered' → fingerprints sort chronologically, so
 *                                     every row after the checkpoint is new
 *   poll.baseline         ordered only: 'now' starts from the time the task
 *                         was first polled, 'latest' from the newest row seen
 *   poll.fetchRows({ tool, config, checkpoint, now })
 *                         → rows { fingerprint, timestamp, context, silent? },
 *                           oldest first. A silent row moves the checkpoint
 *                           without running the task.
 */
const POLLED_ADAPTERS = new Map(adapters.filter((adapter) => adapter.poll).map((adapter) => [adapter.type, adapter]));
const POLLED_TRIGGER_TYPES = Object.freeze([...POLLED_ADAPTERS.keys()]);
// The minute tick allows for drift, so an N-minute trigger never slips to N+1.
const POLL_TICK_SLACK_MS = 5000;

const lastPolledAt = new Map();

function pollIntervalMs(poll, config) {
  const minutes = typeof poll.intervalMinutes === 'function'
    ? poll.intervalMinutes(config)
    : poll.intervalMinutes;
  return (Number(minutes) || 1) * MINUTE_MS;
}

function claimPoll(task, poll, config, now) {
  const last = lastPolledAt.get(task.id) || 0;
  if (now - last < pollIntervalMs(poll, config) - POLL_TICK_SLACK_MS) return false;
  lastPolledAt.set(task.id, now);
  return true;
}

async function fetchTriggerRows({
  integrationManager,
  userId,
  agentId,
  triggerType,
  config,
  checkpoint = '',
  signal = null,
  now = Date.now(),
}) {
  const adapter = POLLED_ADAPTERS.get(triggerType);
  if (!adapter || !integrationManager) return [];
  const scopedAgentId = resolveAgentId(userId, agentId);
  const connectionArgs = {
    connection_id: config.connectionId,
    account_email: config.accountEmail || undefined,
  };
  const tool = (name, args = {}) => integrationManager.executeTool(
    userId,
    name,
    { ...connectionArgs, ...args },
    scopedAgentId,
    { signal },
  );
  return adapter.poll.fetchRows({ tool, config, checkpoint, now });
}

function pendingRows(runtime, task, poll, rows, now) {
  const checkpoint = String(task.last_trigger_fingerprint || '');
  const markCheckpoint = (fingerprint) => runtime.taskRepository.markTaskTriggerCheckpoint(task.id, fingerprint, task.user_id);

  if (poll.cursor === 'ordered') {
    if (checkpoint) return rows.filter((row) => row.fingerprint > checkpoint);
    if (poll.baseline === 'now') {
      const start = new Date(now).toISOString();
      markCheckpoint(start);
      return rows.filter((row) => row.fingerprint > start);
    }
    // An empty first look still records a start, or the first item ever seen
    // would only become the baseline instead of firing.
    markCheckpoint(rows.length ? rows[rows.length - 1].fingerprint : '0');
    return [];
  }

  if (!rows.length) return [];
  if (!checkpoint) {
    markCheckpoint(rows[rows.length - 1].fingerprint);
    return [];
  }
  const startIndex = rows.findIndex((row) => row.fingerprint === checkpoint);
  return startIndex >= 0 ? rows.slice(startIndex + 1) : rows.slice(-1);
}

async function pollTriggerTask(runtime, task, options = {}) {
  const adapter = POLLED_ADAPTERS.get(task.trigger_type);
  if (!adapter) return;
  const now = options.now || Date.now();
  const config = normalizeJsonObject(task.trigger_config);
  if (!claimPoll(task, adapter.poll, config, now)) return;

  const rows = await fetchTriggerRows({
    integrationManager: runtime.integrationManager,
    userId: task.user_id,
    agentId: task.agent_id,
    triggerType: task.trigger_type,
    config,
    checkpoint: String(task.last_trigger_fingerprint || ''),
    signal: options.signal,
    now,
  });

  for (const row of pendingRows(runtime, task, adapter.poll, rows, now)) {
    if (row.silent) {
      runtime.taskRepository.markTaskTriggerCheckpoint(task.id, row.fingerprint, task.user_id);
      continue;
    }
    const result = await runtime.fireTaskFromTrigger(task.id, task.user_id, row);
    if (result?.error || (result?.skipped && result.reason !== 'duplicate_trigger')) {
      break;
    }
  }
}

function forgetPolledTask(taskId) {
  lastPolledAt.delete(taskId);
}

module.exports = {
  POLLED_TRIGGER_TYPES,
  fetchTriggerRows,
  forgetPolledTask,
  pollTriggerTask,
};
