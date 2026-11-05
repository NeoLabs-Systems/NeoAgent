'use strict';

const db = require('../../db/database');
const { createAgent, getAgentById, resolveAgentId } = require('./manager');
const { getTaskForRun } = require('./tasks');
const { mergeToolRestrictions } = require('./tool_restrictions');

// An agent may set up a new persistent specialist. Whether one is worth having
// is the model's decision; this only checks rules that can be counted. Whether
// creating agents is allowed at all, or needs the owner's OK first, is the
// account's "agent_creation" tool policy, enforced before the tool runs.
const MAX_AGENTS_PER_ACCOUNT = 12;

function restrictionsFromArgs(args) {
  const requested = {};
  for (const category of Array.isArray(args.ask_first) ? args.ask_first : []) requested[category] = 'require_approval';
  for (const category of Array.isArray(args.not_allowed) ? args.not_allowed : []) requested[category] = 'deny';
  return requested;
}

/**
 * Creates the agent a run asked for. The new agent is never less restricted
 * than its creator, or than the agents whose task the creator is working on.
 */
function createAgentForRun({ userId, agentId, runId, alreadyCreatedInRun }, args = {}) {
  const name = String(args.name || '').trim();
  const responsibility = String(args.responsibility || '').trim();
  const reason = String(args.reason || '').trim();
  if (!name || !responsibility || !reason) {
    return { error: 'name, responsibility and reason are required.' };
  }
  if (alreadyCreatedInRun) return { error: 'A run may create one agent. Use the one you created.' };
  if (getTaskForRun(runId)) {
    return { error: 'Agents working on a task for another agent cannot create agents. Report the need in your result instead.' };
  }
  const count = db.prepare("SELECT COUNT(*) AS n FROM agents WHERE user_id = ? AND status != 'archived'").get(userId).n;
  if (count >= MAX_AGENTS_PER_ACCOUNT) {
    return { error: `This account already has ${count} agents, the most it may have. Hand the work to one of them, or ask the user to archive one.` };
  }

  const creator = getAgentById(userId, resolveAgentId(userId, agentId));
  const agent = createAgent(userId, {
    displayName: name,
    description: String(args.description || '').trim(),
    responsibilities: responsibility,
    instructions: String(args.instructions || '').trim(),
    toolRestrictions: mergeToolRestrictions(creator?.tool_restrictions_json, restrictionsFromArgs(args)),
    createdByAgentId: creator?.id || null,
    creationReason: reason,
    canDelegate: false,
    canBeDelegatedTo: true,
  });
  return agent;
}

module.exports = { createAgentForRun };
