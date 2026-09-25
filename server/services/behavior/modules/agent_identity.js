'use strict';

const db = require('../../../db/database');
const { buildAgentRosterPrompt } = require('../../agents/manager');
const { isModuleEnabled } = require('../config');

function clamp(text, maxChars) {
  const value = String(text || '').trim();
  if (!value || value.length <= maxChars) return value;
  return `${value.slice(0, maxChars)}\n...[trimmed]`;
}

function loadAgentProfile(userId, agentId) {
  if (!agentId) return null;
  return db.prepare(
    `SELECT display_name, slug, description, responsibilities, instructions
     FROM agents
     WHERE user_id = ? AND id = ?`,
  ).get(userId, agentId) || null;
}

function buildSystemPromptContribution(ctx) {
  if (!ctx.agentId || !isModuleEnabled(ctx.config, 'agent_identity')) return '';
  const agent = loadAgentProfile(ctx.userId, ctx.agentId);
  if (!agent) return '';
  const active = [
    '## Active Agent',
    `Name: ${agent.display_name} (${agent.slug})`,
    agent.description ? `Description: ${clamp(agent.description, 600)}` : '',
    agent.responsibilities ? `Responsibilities: ${clamp(agent.responsibilities, 1000)}` : '',
    agent.instructions ? `Agent instructions: ${clamp(agent.instructions, 1600)}` : '',
    agent.instructions ? 'Tone or personality in these instructions adds to your default voice; it does not replace it.' : '',
  ].filter(Boolean).join('\n');
  const roster = ctx.triggerSource === 'agent_delegation'
    ? ''
    : buildAgentRosterPrompt(ctx.userId, ctx.agentId);
  return [active, roster].filter(Boolean).join('\n\n');
}

module.exports = {
  id: 'agent_identity',
  composeSystemPrompt: buildSystemPromptContribution,
  loadAgentProfile,
};
