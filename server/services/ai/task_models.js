'use strict';

const { parseModelSelectionId } = require('./model_identity');

// Kinds of work a user can pin a model to, and the tools that show a run is
// doing that work. A tool matches by exact name or by `prefix*`. This is the
// only place the two are tied together; routing reads what a run actually
// calls, never what the task text says.
const TASK_KINDS = Object.freeze({
  coding: ['edit_file', 'write_file', 'replace_file_range', 'code_navigate'],
  computer_use: ['browser_*', 'desktop_*'],
  android_use: ['android_*'],
  research: ['web_*', 'search_web'],
});

const TASK_MODEL_KINDS = Object.freeze(Object.keys(TASK_KINDS));

function matchesTool(pattern, toolName) {
  return pattern.endsWith('*')
    ? toolName.startsWith(pattern.slice(0, -1))
    : toolName === pattern;
}

function normalizeTaskModels(raw) {
  const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  const normalized = {};
  for (const kind of TASK_MODEL_KINDS) {
    const selection = String(source[kind] ?? '').trim();
    if (parseModelSelectionId(selection)) normalized[kind] = selection;
  }
  return normalized;
}

// The kind of work a set of tool calls belongs to: the kind most of the
// recognised calls fall under, or null when none are recognised.
function inferTaskKind(toolNames) {
  const counts = new Map();
  for (const name of toolNames || []) {
    const kind = TASK_MODEL_KINDS.find((candidate) => (
      TASK_KINDS[candidate].some((pattern) => matchesTool(pattern, String(name || '')))
    ));
    if (kind) counts.set(kind, (counts.get(kind) || 0) + 1);
  }
  let best = null;
  for (const [kind, count] of counts) {
    if (!best || count > counts.get(best)) best = kind;
  }
  return best;
}

module.exports = {
  TASK_MODEL_KINDS,
  inferTaskKind,
  normalizeTaskModels,
};
