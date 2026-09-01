'use strict';

const db = require('../../db/database');
const { parseMaybeJson } = require('../ai/logFormat');

function changedPath(toolInput) {
  const input = parseMaybeJson(toolInput, {}) || {};
  const raw = input.path ?? input.file_path;
  const path = typeof raw === 'string' ? raw.trim().replace(/\\/g, '/') : '';
  if (!path) return null;
  return path.replace(/^\.\//, '').replace(/^\/+/, '');
}

function listChangedFiles(userId, conversationId) {
  const rows = db.prepare(
    `SELECT s.id AS step_id, s.run_id, s.tool_name, s.tool_input, s.status,
            COALESCE(s.completed_at, s.started_at) AS changed_at
     FROM agent_steps s
     JOIN agent_runs r ON r.id = s.run_id
     WHERE r.conversation_id = ? AND r.user_id = ?
       AND s.tool_name IN ('write_file', 'edit_file', 'replace_file_range')
       AND s.status = 'completed'
     ORDER BY s.started_at ASC, s.step_index ASC`,
  ).all(conversationId, userId);
  const byPath = new Map();
  for (const row of rows) {
    const path = changedPath(row.tool_input);
    if (!path) continue;
    const previous = byPath.get(path);
    byPath.set(path, {
      path,
      action: previous?.action || (row.tool_name === 'write_file' ? 'written' : 'edited'),
      edits: (previous?.edits || 0) + 1,
      runId: row.run_id,
      stepId: row.step_id,
      changedAt: row.changed_at,
    });
  }
  return [...byPath.values()].sort((left, right) => (
    String(right.changedAt || '').localeCompare(String(left.changedAt || ''))
  ));
}

module.exports = { listChangedFiles };
