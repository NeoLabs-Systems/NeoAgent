'use strict';

const db = require('../../db/database');
const { clampRunContext } = require('./messagingFallback');
const { isShellCall, resolveToolMeta } = require('./tools/metadata');
const { canRepeat } = require('./runtime/operations');

// A conversation stores what was said. What a run did lives in its ledger
// (agent_steps), and a later run sees it from there: each earlier run's lasting
// actions, as the calls it made and the status the harness recorded for them. Reads
// and file edits are left out: the first changed nothing, and the second the next run
// can see in the workspace itself. A command stays: it can reach past the workspace.
const MAX_ARGUMENT_CHARS = 1500;

function isLastingAction(step) {
  const meta = resolveToolMeta(step.tool_name);
  // A note on the way, such as a progress update, is not something the run achieved.
  if (meta.stepType === 'note') return false;
  if (meta.sideEffect === 'workspace' && !isShellCall(meta)) return false;
  return !canRepeat(meta, parseJson(step.tool_input) || {});
}

function parseJson(text) {
  try {
    return JSON.parse(text || 'null');
  } catch {
    return null;
  }
}

// Only what the harness itself observed. "unknown" never reads as done.
function receipt(step) {
  const result = parseJson(step.result);
  let status = step.status;
  if (status === 'completed' && (result?.ambiguous === true || result?.deliveryAmbiguous === true)) status = 'ambiguous';
  if (status === 'running' || status === 'pending' || status === 'interrupted') status = 'unknown';
  return JSON.stringify({
    status,
    ...(step.error ? { error: clampRunContext(step.error, 300) } : {}),
  });
}

function clampArguments(text) {
  const args = parseJson(text);
  if (!args || typeof args !== 'object') return '{}';
  return JSON.stringify(Object.fromEntries(Object.entries(args).map(([key, value]) => [
    key,
    typeof value === 'string' ? clampRunContext(value, MAX_ARGUMENT_CHARS) : value,
  ])));
}

function actionMessages(steps) {
  return [
    {
      role: 'assistant',
      content: '',
      // Shaped like a stored row, which keeps tool calls as JSON.
      tool_calls: JSON.stringify(steps.map((step) => ({
        id: step.id,
        type: 'function',
        function: { name: step.tool_name, arguments: clampArguments(step.tool_input) },
      }))),
    },
    ...steps.map((step) => ({ role: 'tool', tool_call_id: step.id, name: step.tool_name, content: receipt(step) })),
  ];
}

// Puts each run's lasting actions right after the request that started it.
function withRunActions(rows) {
  const runIds = [...new Set(rows.filter((row) => row.role === 'user' && row.run_id).map((row) => row.run_id))];
  if (!runIds.length) return rows;
  const steps = db.prepare(
    `SELECT id, run_id, tool_name, tool_input, status, result, error FROM agent_steps
     WHERE tool_name IS NOT NULL AND run_id IN (${runIds.map(() => '?').join(', ')})
     ORDER BY step_index`,
  ).all(...runIds).filter(isLastingAction);
  if (!steps.length) return rows;
  const byRun = new Map();
  for (const step of steps) byRun.set(step.run_id, [...(byRun.get(step.run_id) || []), step]);
  const out = [];
  for (const row of rows) {
    out.push(row);
    const actions = row.role === 'user' ? byRun.get(row.run_id) : null;
    if (!actions) continue;
    byRun.delete(row.run_id);
    out.push(...actionMessages(actions));
  }
  return out;
}

module.exports = { withRunActions };
