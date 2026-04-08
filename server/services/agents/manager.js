const { randomUUID } = require('crypto');
const db = require('../../db/database');

const MAIN_AGENT_SLUG = 'main';

function normalizeSlug(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
}

function parseDelegateTargets(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value.map((id) => String(id || '').trim()).filter(Boolean);
  try {
    const parsed = JSON.parse(String(value));
    return Array.isArray(parsed) ? parsed.map((id) => String(id || '').trim()).filter(Boolean) : [];
  } catch {
    return [];
  }
}

function boolFromInput(value, fallback = false) {
  if (value == null) return fallback;
  if (value === true || value === 1 || value === '1') return true;
  if (value === false || value === 0 || value === '0') return false;
  const normalized = String(value).trim().toLowerCase();
  if (['true', 'yes', 'on'].includes(normalized)) return true;
  if (['false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function serializeAgent(row) {
  if (!row) return null;
  return {
    id: row.id,
    slug: row.slug,
    displayName: row.display_name,
    description: row.description || '',
    responsibilities: row.responsibilities || '',
    instructions: row.instructions || '',
    status: row.status || 'active',
    isDefault: row.is_default === 1 || row.is_default === true,
    canDelegate: row.can_delegate === 1 || row.can_delegate === true,
    canBeDelegatedTo: row.can_be_delegated_to !== 0 && row.can_be_delegated_to !== false,
    delegateTargets: parseDelegateTargets(row.delegate_targets_json),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function ensureMainAgent(userId) {
  if (!userId) return null;
  let row = db
    .prepare('SELECT * FROM agents WHERE user_id = ? AND slug = ?')
    .get(userId, MAIN_AGENT_SLUG);
  if (row) {
    if (!row.is_default) {
      db.prepare('UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE user_id = ?')
        .run(row.id, userId);
      row = { ...row, is_default: 1 };
    }
    return row;
  }

  const id = randomUUID();
  db.prepare(
    `INSERT INTO agents (
      id, user_id, slug, display_name, description, responsibilities, instructions,
      status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', 1, 1, 0, '[]')`
  ).run(
    id,
    userId,
    MAIN_AGENT_SLUG,
    'Main',
    'Default personal assistant and fallback agent.',
    'Handle general requests. Delegate to specialist agents only when their responsibilities clearly match.',
    '',
  );
  db.prepare('UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE user_id = ?')
    .run(id, userId);
  return db.prepare('SELECT * FROM agents WHERE id = ?').get(id);
}

function getDefaultAgent(userId) {
  const row = db
    .prepare("SELECT * FROM agents WHERE user_id = ? AND is_default = 1 AND status != 'archived' ORDER BY updated_at DESC LIMIT 1")
    .get(userId);
  return row || ensureMainAgent(userId);
}

function getAgentById(userId, agentId) {
  if (!userId || !agentId) return null;
  return db.prepare('SELECT * FROM agents WHERE user_id = ? AND id = ?').get(userId, agentId);
}

function getAgentBySlug(userId, slug) {
  const normalized = normalizeSlug(slug);
  if (!userId || !normalized) return null;
  return db.prepare('SELECT * FROM agents WHERE user_id = ? AND slug = ?').get(userId, normalized);
}

function resolveAgent(userId, candidate = null) {
  ensureMainAgent(userId);
  const raw = String(candidate || '').trim();
  if (!raw) return getDefaultAgent(userId);

  const byId = getAgentById(userId, raw);
  if (byId) return byId;

  const bySlug = getAgentBySlug(userId, raw);
  if (bySlug) return bySlug;

  return getDefaultAgent(userId);
}

function resolveAgentId(userId, candidate = null) {
  return resolveAgent(userId, candidate)?.id || null;
}

function getAgentIdFromRequest(req) {
  return (
    req.body?.agentId
    || req.body?.agent_id
    || req.body?.options?.agentId
    || req.body?.options?.agent_id
    || req.query?.agentId
    || req.query?.agent_id
    || req.get?.('x-agent-id')
    || null
  );
}

function listAgents(userId, { includeArchived = false } = {}) {
  ensureMainAgent(userId);
  const rows = includeArchived
    ? db.prepare('SELECT * FROM agents WHERE user_id = ? ORDER BY is_default DESC, updated_at DESC, display_name ASC').all(userId)
    : db.prepare("SELECT * FROM agents WHERE user_id = ? AND status != 'archived' ORDER BY is_default DESC, updated_at DESC, display_name ASC").all(userId);
  return rows.map(serializeAgent);
}

function createAgent(userId, input = {}) {
  const slug = normalizeSlug(input.slug || input.displayName || input.name);
  if (!slug) throw new Error('Agent slug or display name is required.');
  if (slug === MAIN_AGENT_SLUG && getAgentBySlug(userId, MAIN_AGENT_SLUG)) {
    throw new Error('The main agent already exists.');
  }
  const displayName = String(input.displayName || input.name || slug).trim().slice(0, 120);
  const isDefault = slug === MAIN_AGENT_SLUG ? 1 : 0;
  const defaultCanDelegate = slug === MAIN_AGENT_SLUG;
  const defaultCanBeDelegatedTo = slug !== MAIN_AGENT_SLUG;
  const id = randomUUID();
  db.prepare(
    `INSERT INTO agents (
      id, user_id, slug, display_name, description, responsibilities, instructions,
      status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    id,
    userId,
    slug,
    displayName,
    String(input.description || '').trim(),
    String(input.responsibilities || '').trim(),
    String(input.instructions || '').trim(),
    input.status === 'paused' ? 'paused' : 'active',
    isDefault,
    boolFromInput(input.canDelegate ?? input.can_delegate, defaultCanDelegate) ? 1 : 0,
    boolFromInput(input.canBeDelegatedTo ?? input.can_be_delegated_to, defaultCanBeDelegatedTo) ? 1 : 0,
    JSON.stringify(parseDelegateTargets(input.delegateTargets ?? input.delegate_targets ?? input.delegate_targets_json)),
  );
  if (isDefault) {
    db.prepare('UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE user_id = ?')
      .run(id, userId);
  }
  return serializeAgent(getAgentById(userId, id));
}

function updateAgent(userId, agentId, input = {}) {
  const existing = getAgentById(userId, agentId);
  if (!existing) throw new Error('Agent not found.');
  const slug = existing.slug === MAIN_AGENT_SLUG
    ? existing.slug
    : (input.slug == null ? existing.slug : normalizeSlug(input.slug));
  if (!slug) throw new Error('Agent slug is required.');
  const displayName = input.displayName == null
    ? existing.display_name
    : String(input.displayName || '').trim().slice(0, 120);
  if (!displayName) throw new Error('Agent display name is required.');
  const status = ['active', 'paused', 'archived'].includes(input.status)
    ? input.status
    : existing.status;
  if (status === 'archived' && (existing.slug === MAIN_AGENT_SLUG || existing.is_default)) {
    throw new Error('The default main agent cannot be archived.');
  }
  const canDelegate = boolFromInput(input.canDelegate ?? input.can_delegate, existing.can_delegate === 1);
  const canBeDelegatedTo = boolFromInput(input.canBeDelegatedTo ?? input.can_be_delegated_to, existing.can_be_delegated_to !== 0);
  const delegateTargets = input.delegateTargets != null || input.delegate_targets != null || input.delegate_targets_json != null
    ? parseDelegateTargets(input.delegateTargets ?? input.delegate_targets ?? input.delegate_targets_json)
    : parseDelegateTargets(existing.delegate_targets_json);

  db.prepare(
    `UPDATE agents
     SET slug = ?, display_name = ?, description = ?, responsibilities = ?, instructions = ?,
         status = ?, can_delegate = ?, can_be_delegated_to = ?, delegate_targets_json = ?, updated_at = datetime('now')
     WHERE user_id = ? AND id = ?`
  ).run(
    slug,
    displayName,
    input.description == null ? existing.description : String(input.description || '').trim(),
    input.responsibilities == null ? existing.responsibilities : String(input.responsibilities || '').trim(),
    input.instructions == null ? existing.instructions : String(input.instructions || '').trim(),
    status,
    canDelegate ? 1 : 0,
    canBeDelegatedTo ? 1 : 0,
    JSON.stringify(delegateTargets),
    userId,
    agentId,
  );

  if (input.isDefault === true || input.is_default === true) {
    setDefaultAgent(userId, agentId);
  }

  return serializeAgent(getAgentById(userId, agentId));
}

function setDefaultAgent(userId, agentId) {
  const existing = getAgentById(userId, agentId);
  if (!existing) throw new Error('Agent not found.');
  db.prepare('UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END, updated_at = datetime(\'now\') WHERE user_id = ?')
    .run(agentId, userId);
  return serializeAgent(getAgentById(userId, agentId));
}

function archiveAgent(userId, agentId) {
  const existing = getAgentById(userId, agentId);
  if (!existing) throw new Error('Agent not found.');
  if (existing.slug === MAIN_AGENT_SLUG || existing.is_default) {
    throw new Error('The default main agent cannot be archived.');
  }
  db.prepare("UPDATE agents SET status = 'archived', updated_at = datetime('now') WHERE user_id = ? AND id = ?")
    .run(userId, agentId);
  return { archived: true };
}

function agentCanDelegateTo(sourceAgent, targetAgent) {
  if (!sourceAgent || !targetAgent) return false;
  if (sourceAgent.id === targetAgent.id) return false;
  if (sourceAgent.status !== 'active' || targetAgent.status !== 'active') return false;
  if (sourceAgent.can_delegate !== 1 && sourceAgent.can_delegate !== true) return false;
  if (targetAgent.can_be_delegated_to === 0 || targetAgent.can_be_delegated_to === false) return false;
  const allowedTargets = parseDelegateTargets(sourceAgent.delegate_targets_json);
  return allowedTargets.length === 0 || allowedTargets.includes(targetAgent.id);
}

function getDelegationTargets(userId, sourceAgentId) {
  ensureMainAgent(userId);
  const sourceAgent = getAgentById(userId, sourceAgentId);
  if (!sourceAgent) return [];
  const rows = db.prepare(
    `SELECT id, slug, display_name, description, responsibilities, status, can_be_delegated_to
     FROM agents
     WHERE user_id = ? AND status = 'active' AND id != ?
     ORDER BY is_default ASC, display_name ASC`
  ).all(userId, sourceAgent.id);
  return rows
    .filter((target) => agentCanDelegateTo(sourceAgent, target))
    .map((row) => ({
      id: row.id,
      slug: row.slug,
      name: row.display_name,
      description: row.description || '',
      responsibilities: row.responsibilities || '',
    }));
}

function getActiveAgentRoster(userId, { excludeAgentId = null, sourceAgentId = null } = {}) {
  if (sourceAgentId) {
    return getDelegationTargets(userId, sourceAgentId);
  }
  ensureMainAgent(userId);
  return db
    .prepare(
      `SELECT id, slug, display_name, description, responsibilities
       FROM agents
       WHERE user_id = ? AND status = 'active' AND (? IS NULL OR id != ?)
       ORDER BY is_default ASC, display_name ASC`
    )
    .all(userId, excludeAgentId, excludeAgentId)
    .map((row) => ({
      id: row.id,
      slug: row.slug,
      name: row.display_name,
      description: row.description || '',
      responsibilities: row.responsibilities || '',
    }));
}

function buildAgentRosterPrompt(userId, activeAgentId) {
  const roster = getDelegationTargets(userId, activeAgentId);
  if (!roster.length) return '';
  const lines = roster.map((agent) => {
    const responsibilities = agent.responsibilities || agent.description || 'No specific responsibility described.';
    return `- ${agent.slug} (${agent.name}): ${responsibilities}`;
  });
  return [
    '[Available specialist agents]',
    'Delegate only when a specialist clearly matches the task. If uncertain, handle the task yourself.',
    ...lines,
  ].join('\n');
}

module.exports = {
  MAIN_AGENT_SLUG,
  archiveAgent,
  buildAgentRosterPrompt,
  boolFromInput,
  createAgent,
  ensureMainAgent,
  agentCanDelegateTo,
  getActiveAgentRoster,
  getAgentById,
  getAgentBySlug,
  getAgentIdFromRequest,
  getDefaultAgent,
  getDelegationTargets,
  listAgents,
  parseDelegateTargets,
  resolveAgent,
  resolveAgentId,
  serializeAgent,
  setDefaultAgent,
  updateAgent,
};
