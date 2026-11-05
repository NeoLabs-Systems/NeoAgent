'use strict';

const db = require('../../db/database');
const { DEFAULT_POLICY } = require('../security/default_policy');

// An agent can be held to stricter tool rules than its account, never looser:
// per tool category it either needs the owner's OK or may not use it at all.
// Everything not listed follows the account's own policy.
const LEVEL_RANK = { require_approval: 1, deny: 2 };

function normalizeToolRestrictions(value) {
  let parsed = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value || '{}');
    } catch {
      parsed = {};
    }
  }
  const restrictions = {};
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return restrictions;
  for (const [category, level] of Object.entries(parsed)) {
    if (Object.hasOwn(DEFAULT_POLICY, category) && LEVEL_RANK[level]) restrictions[category] = level;
  }
  return restrictions;
}

// The strictest level per category across all of them.
function mergeToolRestrictions(...sources) {
  const merged = {};
  for (const source of sources) {
    for (const [category, level] of Object.entries(normalizeToolRestrictions(source))) {
      if (!merged[category] || LEVEL_RANK[level] > LEVEL_RANK[merged[category]]) merged[category] = level;
    }
  }
  return merged;
}

/**
 * The restriction a run is under for one category: its agent's own, plus, when
 * the run works an agent task, what the agents that asked for it were under.
 */
function restrictionForRun({ userId, agentId, runId, category }) {
  if (!category) return null;
  const agent = agentId
    ? db.prepare('SELECT tool_restrictions_json FROM agents WHERE user_id = ? AND id = ?').get(userId, agentId)
    : null;
  const task = runId
    ? db.prepare('SELECT tool_restrictions_json FROM agent_delegations WHERE child_run_id = ?').get(runId)
    : null;
  return mergeToolRestrictions(agent?.tool_restrictions_json, task?.tool_restrictions_json)[category] || null;
}

module.exports = {
  mergeToolRestrictions,
  normalizeToolRestrictions,
  restrictionForRun,
};
