'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');

// Durable work between persistent agents. A task has one owner (the agent
// working it) and one requester (the agent that asked). In "delegate" mode the
// result goes back to the requester, who stays responsible for the user's
// request; in "handoff" mode the owner takes the request over and its result
// goes to the user. Rows live in agent_delegations, which predates tasks.

const OPEN_STATUSES = Object.freeze(['pending', 'working', 'waiting']);
const CLOSED_STATUSES = Object.freeze(['completed', 'failed', 'cancelled']);

// Plain counts, not a loop classifier: they bound how far work can spread.
const LIMITS = Object.freeze({
  depth: 2, // a task's owner may pass parts on, and their owners once more
  tasksPerRun: 3,
  openTasksPerUser: 20,
  messagesPerTask: 20,
  attemptsPerTask: 6, // runs one task may take, resumes included
});

const RESULT_MAX_CHARS = 20000;
const IN = (values) => values.map(() => '?').join(', ');

function getTask(userId, taskId) {
  if (!taskId) return null;
  return db.prepare('SELECT * FROM agent_delegations WHERE user_id = ? AND id = ?').get(userId, String(taskId)) || null;
}

function getTaskById(taskId) {
  return db.prepare('SELECT * FROM agent_delegations WHERE id = ?').get(taskId) || null;
}

// The task a run is working on as its owner.
function getTaskForRun(runId) {
  if (!runId) return null;
  return db.prepare('SELECT * FROM agent_delegations WHERE child_run_id = ?').get(runId) || null;
}

function insertTask(fields) {
  const id = randomUUID();
  db.prepare(
    `INSERT INTO agent_delegations (
      id, user_id, parent_agent_id, target_agent_id, parent_run_id, parent_task_id,
      task, context, expected_output, mode, depth, status, reply_route_json,
      tool_restrictions_json, allow_external_side_effects
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
  ).run(
    id,
    fields.userId,
    fields.requesterAgentId,
    fields.ownerAgentId,
    fields.requesterRunId || null,
    fields.parentTaskId || null,
    fields.goal,
    fields.context || null,
    fields.expectedOutput || null,
    fields.mode,
    fields.depth,
    fields.replyRoute ? JSON.stringify(fields.replyRoute) : null,
    JSON.stringify(fields.toolRestrictions || {}),
    fields.allowExternalSideEffects ? 1 : 0,
  );
  return getTaskById(id);
}

const COLUMN_FOR = {
  status: 'status',
  ownerAgentId: 'target_agent_id',
  ownerRunId: 'child_run_id',
  mode: 'mode',
  result: 'result_summary',
  error: 'error',
  awaitingReply: 'awaiting_reply',
  reportPending: 'report_pending',
};

/**
 * Changes a task only if it is still in one of `fromStatuses`, so two paths
 * racing to settle the same task cannot both win. Returns the updated row.
 */
function updateTask(taskId, fields, { fromStatuses = null } = {}) {
  const assignments = [];
  const values = [];
  for (const [key, value] of Object.entries(fields)) {
    if (!COLUMN_FOR[key]) throw new Error(`Unknown task field: ${key}`);
    assignments.push(`${COLUMN_FOR[key]} = ?`);
    if (key === 'result') values.push(value == null ? null : String(value).slice(0, RESULT_MAX_CHARS));
    else if (typeof value === 'boolean') values.push(value ? 1 : 0);
    else values.push(value);
  }
  if (fields.status && CLOSED_STATUSES.includes(fields.status)) {
    assignments.push("completed_at = datetime('now')");
  }
  assignments.push("updated_at = datetime('now')");
  let sql = `UPDATE agent_delegations SET ${assignments.join(', ')} WHERE id = ?`;
  values.push(taskId);
  if (fromStatuses) {
    sql += ` AND status IN (${IN(fromStatuses)})`;
    values.push(...fromStatuses);
  }
  const changed = db.prepare(sql).run(...values).changes > 0;
  return changed ? getTaskById(taskId) : null;
}

// Counts an attempt and claims the task for a new owner run in one write.
function claimTaskForRun(taskId, runId) {
  const changed = db.prepare(
    `UPDATE agent_delegations
     SET status = 'working', child_run_id = ?, attempts = COALESCE(attempts, 0) + 1, updated_at = datetime('now')
     WHERE id = ? AND status = 'pending'`,
  ).run(runId, taskId).changes > 0;
  return changed ? getTaskById(taskId) : null;
}

// Takes the right to tell the requester about the task's latest change.
function claimReport(taskId) {
  return db.prepare(
    "UPDATE agent_delegations SET report_pending = 0 WHERE id = ? AND report_pending = 1",
  ).run(taskId).changes > 0;
}

function pendingTasks() {
  return db.prepare("SELECT * FROM agent_delegations WHERE status = 'pending' ORDER BY created_at ASC").all();
}

// Tasks whose owner run a restart cut off go back in the queue.
function requeueInterruptedTasks() {
  return db.prepare(
    "UPDATE agent_delegations SET status = 'pending', updated_at = datetime('now') WHERE status = 'working'",
  ).run().changes;
}

function tasksToReport() {
  return db.prepare('SELECT * FROM agent_delegations WHERE report_pending = 1 ORDER BY updated_at ASC').all();
}

function countWorkingTasks(userId) {
  return db.prepare("SELECT COUNT(*) AS n FROM agent_delegations WHERE user_id = ? AND status = 'working'").get(userId).n;
}

function countOpenTasks(userId) {
  return db.prepare(
    `SELECT COUNT(*) AS n FROM agent_delegations WHERE user_id = ? AND status IN (${IN(OPEN_STATUSES)})`,
  ).get(userId, ...OPEN_STATUSES).n;
}

function countTasksRequestedByRun(runId) {
  return db.prepare('SELECT COUNT(*) AS n FROM agent_delegations WHERE parent_run_id = ?').get(runId).n;
}

function openDelegatedChildren(taskId) {
  return db.prepare(
    `SELECT * FROM agent_delegations
     WHERE parent_task_id = ? AND mode = 'delegate' AND status IN (${IN(OPEN_STATUSES)})`,
  ).all(taskId, ...OPEN_STATUSES);
}

// Finished subtasks whose outcome the parent's owner has not seen yet.
function unreportedChildren(taskId) {
  return db.prepare(
    `SELECT * FROM agent_delegations
     WHERE parent_task_id = ? AND mode = 'delegate' AND report_pending = 1
     ORDER BY updated_at ASC`,
  ).all(taskId);
}

function tasksRequestedByRun(runId) {
  return db.prepare('SELECT * FROM agent_delegations WHERE parent_run_id = ?').all(runId);
}

// Every agent already on this chain of tasks, so work is never passed back up it.
function agentsOnChain(taskId) {
  const agents = new Set();
  let current = taskId ? getTaskById(taskId) : null;
  while (current) {
    agents.add(current.parent_agent_id);
    agents.add(current.target_agent_id);
    for (const row of db.prepare('SELECT DISTINCT from_agent_id FROM agent_task_messages WHERE task_id = ?').all(current.id)) {
      if (row.from_agent_id) agents.add(row.from_agent_id);
    }
    current = current.parent_task_id ? getTaskById(current.parent_task_id) : null;
  }
  return agents;
}

function addMessage(taskId, fromAgentId, content) {
  db.prepare('INSERT INTO agent_task_messages (task_id, from_agent_id, content) VALUES (?, ?, ?)')
    .run(taskId, fromAgentId || null, String(content).slice(0, RESULT_MAX_CHARS));
}

function countMessages(taskId) {
  return db.prepare('SELECT COUNT(*) AS n FROM agent_task_messages WHERE task_id = ?').get(taskId).n;
}

function unreadMessagesFor(taskId, agentId) {
  return db.prepare(
    `SELECT id, from_agent_id, content FROM agent_task_messages
     WHERE task_id = ? AND delivered_at IS NULL AND COALESCE(from_agent_id, '') != ?
     ORDER BY id ASC`,
  ).all(taskId, agentId || '');
}

// Messages for `agentId` that it has not been shown yet, marked shown.
function takeMessagesFor(taskId, agentId) {
  const rows = unreadMessagesFor(taskId, agentId);
  markMessagesRead(rows.map((row) => row.id));
  return rows;
}

function markMessagesRead(ids) {
  if (!ids?.length) return;
  db.prepare(`UPDATE agent_task_messages SET delivered_at = datetime('now') WHERE id IN (${IN(ids)})`).run(...ids);
}

function hasMessagesFor(taskId, agentId) {
  return Boolean(db.prepare(
    `SELECT 1 FROM agent_task_messages
     WHERE task_id = ? AND delivered_at IS NULL AND COALESCE(from_agent_id, '') != ? LIMIT 1`,
  ).get(taskId, agentId || ''));
}

// A note that was queued for a run that ended before reading it is owed again.
function markMessagesUndelivered(ids) {
  if (!ids?.length) return;
  db.prepare(`UPDATE agent_task_messages SET delivered_at = NULL WHERE id IN (${IN(ids)})`).run(...ids);
}

function lastMessageFrom(taskId, agentId) {
  return db.prepare(
    'SELECT content FROM agent_task_messages WHERE task_id = ? AND from_agent_id = ? ORDER BY id DESC LIMIT 1',
  ).get(taskId, agentId)?.content || '';
}

function listMessages(taskId) {
  return db.prepare(
    'SELECT from_agent_id, content, created_at FROM agent_task_messages WHERE task_id = ? ORDER BY id ASC',
  ).all(taskId);
}

// Open tasks an agent asked for or owns, for its prompt and its task tool.
function openTasksForAgent(userId, agentId) {
  return db.prepare(
    `SELECT * FROM agent_delegations
     WHERE user_id = ? AND status IN (${IN(OPEN_STATUSES)}) AND (parent_agent_id = ? OR target_agent_id = ?)
     ORDER BY created_at ASC LIMIT 20`,
  ).all(userId, ...OPEN_STATUSES, agentId, agentId);
}

function listTasks(userId, { limit = 50 } = {}) {
  return db.prepare(
    `SELECT * FROM agent_delegations WHERE user_id = ?
     ORDER BY CASE WHEN status IN (${IN(OPEN_STATUSES)}) THEN 0 ELSE 1 END, updated_at DESC
     LIMIT ?`,
  ).all(userId, ...OPEN_STATUSES, limit);
}

function agentNames(userId) {
  const rows = db.prepare('SELECT id, display_name FROM agents WHERE user_id = ?').all(userId);
  return new Map(rows.map((row) => [row.id, row.display_name]));
}

function serializeTask(row, names = agentNames(row.user_id)) {
  return {
    id: row.id,
    mode: row.mode || 'delegate',
    goal: row.task,
    expectedOutput: row.expected_output || '',
    status: row.status,
    result: row.result_summary || '',
    error: row.error || '',
    awaitingReply: row.awaiting_reply === 1,
    requester: { id: row.parent_agent_id, name: names.get(row.parent_agent_id) || '' },
    owner: { id: row.target_agent_id, name: names.get(row.target_agent_id) || '' },
    parentTaskId: row.parent_task_id || null,
    runId: row.child_run_id || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    completedAt: row.completed_at || null,
  };
}

module.exports = {
  LIMITS,
  OPEN_STATUSES,
  addMessage,
  agentNames,
  agentsOnChain,
  claimReport,
  claimTaskForRun,
  countMessages,
  countOpenTasks,
  countTasksRequestedByRun,
  countWorkingTasks,
  getTask,
  getTaskById,
  getTaskForRun,
  hasMessagesFor,
  insertTask,
  lastMessageFrom,
  listMessages,
  listTasks,
  markMessagesRead,
  markMessagesUndelivered,
  openDelegatedChildren,
  openTasksForAgent,
  pendingTasks,
  requeueInterruptedTasks,
  serializeTask,
  takeMessagesFor,
  tasksRequestedByRun,
  tasksToReport,
  unreadMessagesFor,
  unreportedChildren,
  updateTask,
};
