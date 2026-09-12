'use strict';

const db = require('../../db/database');

const WEAK_NAMES = new Set([
  'main',
  'agent',
  'bot',
  'assistant',
  'user',
  'admin',
  'test',
]);

function escapeRegExp(value) {
  return String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function tokenizeName(name) {
  const value = String(name || '').replace(/^@/, '').trim();
  if (value.length < 3) return [];
  const tokens = [value];
  for (const part of value.split(/[\s_-]+/)) {
    if (part.length >= 3) tokens.push(part);
  }
  return tokens;
}

function addName(names, name) {
  for (const token of tokenizeName(name)) {
    if (WEAK_NAMES.has(token.toLowerCase())) continue;
    names.add(token);
  }
}

function loadAgentNames(userId, agentId, msg) {
  const names = new Set();
  if (userId && agentId) {
    const agent = db.prepare(
      `SELECT display_name, slug FROM agents WHERE user_id = ? AND id = ?`,
    ).get(userId, agentId);
    if (agent) {
      addName(names, agent.display_name);
      addName(names, agent.slug);
    }
  }
  addName(names, msg?.botUsername);
  addName(names, msg?.botDisplayName);
  addName(names, msg?.botName);
  addName(names, msg?.botTag);
  return [...names];
}

function contentAddressesAgent(content, names) {
  const text = String(content || '');
  if (!text.trim() || !Array.isArray(names) || names.length === 0) return false;
  return names.some((name) => {
    const token = String(name || '').trim();
    if (token.length < 3) return false;
    const pattern = new RegExp(
      `(^|[^\\p{L}\\p{N}])${escapeRegExp(token)}(?=[^\\p{L}\\p{N}]|$)`,
      'iu',
    );
    return pattern.test(text);
  });
}

function resolveAddressing({ userId = null, agentId = null, msg = null } = {}) {
  const names = loadAgentNames(userId, agentId, msg);
  const addressedByName = contentAddressesAgent(msg?.content, names);
  const structurallyAddressed = msg?.wasMentioned === true || msg?.repliedToAgent === true;
  return {
    names,
    addressedByName,
    structurallyAddressed,
    addressed: structurallyAddressed || addressedByName,
  };
}

module.exports = {
  WEAK_NAMES,
  contentAddressesAgent,
  loadAgentNames,
  resolveAddressing,
};
