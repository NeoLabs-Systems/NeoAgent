'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');
const { getAgentById, getDefaultAgent } = require('../agents/manager');
const { listRunEvents } = require('../ai/runEvents');
const { parseMaybeJson } = require('../ai/logFormat');

const COWORK_PLATFORM = 'cowork';
const CHAT_MODES = new Set(['agent', 'plan']);
const DEVICE_TARGETS = new Set(['local', 'cloud']);

function serviceError(message, status = 400, code = null) {
  const error = new Error(message);
  error.status = status;
  if (code) error.code = code;
  return error;
}

function requireText(value, label, maxLength) {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text) throw serviceError(`${label} is required.`);
  if (text.length > maxLength) throw serviceError(`${label} is too long.`);
  return text;
}

function normalizeMode(value, fallback = 'agent') {
  const mode = String(value || fallback).trim().toLowerCase();
  if (!CHAT_MODES.has(mode)) throw serviceError('Mode must be agent or plan.');
  return mode;
}

function normalizeDeviceOverride(value) {
  if (value == null || String(value).trim() === '') return null;
  const target = String(value).trim().toLowerCase();
  if (!DEVICE_TARGETS.has(target)) {
    throw serviceError('Device target override must be local, cloud, or null.');
  }
  return target;
}

function normalizeWorkspacePathOverride(value) {
  if (value == null || String(value).trim() === '') return null;
  const path = String(value).trim();
  if (path.length > 1024) throw serviceError('Workspace path is too long.');
  if (!path.startsWith('/') && !/^[a-zA-Z]:[\\/]/.test(path)) {
    throw serviceError('Workspace path override must be an absolute path.');
  }
  return path;
}

function normalizeModelOverride(value) {
  if (value == null || String(value).trim() === '') return null;
  const model = String(value).trim();
  if (model.length > 120) throw serviceError('Model override is too long.');
  return model === 'default' ? null : model;
}

function resolveAgent(userId, agentId) {
  if (agentId == null || String(agentId).trim() === '') return getDefaultAgent(userId);
  const agent = getAgentById(userId, String(agentId).trim());
  if (!agent || agent.status === 'archived') throw serviceError('Agent not found.', 404);
  return agent;
}

function resolveEffectiveDeviceTarget(userId, override = null, runtimeManager = null) {
  const normalizedOverride = normalizeDeviceOverride(override);
  const settingTarget = runtimeManager?.getComputerProvider?.(userId) === 'local'
    ? 'local'
    : 'cloud';
  const effective = normalizedOverride || settingTarget;
  const status = runtimeManager?.getComputerStatus?.(userId) || {};
  const capabilities = status.providers && typeof status.providers === 'object'
    ? status.providers
    : {};
  const available = effective === 'cloud'
    ? capabilities.cloud?.available !== false
    : capabilities.local?.available === true;
  return {
    override: normalizedOverride,
    setting: settingTarget,
    effective,
    inherited: normalizedOverride == null,
    available,
    providers: {
      cloud: { available: capabilities.cloud?.available !== false },
      local: {
        available: capabilities.local?.available === true,
        connected: capabilities.local?.connected === true,
      },
    },
  };
}

function parseJson(value, fallback) {
  return parseMaybeJson(value, fallback) || fallback;
}

function serializeConversation(row, options = {}) {
  if (!row) return null;
  const device = resolveEffectiveDeviceTarget(
    row.user_id,
    row.device_target_override,
    options.runtimeManager,
  );
  return {
    id: row.id,
    agentId: row.agent_id || null,
    agentName: row.agent_name || null,
    title: row.title || 'New chat',
    mode: normalizeMode(row.interaction_mode, 'agent'),
    device,
    workspacePathOverride: row.workspace_path_override || null,
    modelOverride: row.model_override || null,
    manuallyTitled: row.manually_titled === 1 || row.manually_titled === true,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    latestRun: row.latest_run_id ? {
      id: row.latest_run_id,
      status: row.latest_run_status || 'pending',
      title: row.latest_run_title || '',
      mode: row.latest_run_mode || 'agent',
      deviceTarget: row.latest_run_device_target || null,
      model: row.latest_run_model || null,
      totalTokens: Number(row.latest_run_total_tokens || 0),
      createdAt: row.latest_run_created_at || null,
      updatedAt: row.latest_run_updated_at || null,
    } : null,
    pendingInputCount: Number(row.pending_input_count || 0),
    messageCount: Number(row.message_count || 0),
  };
}

function getConversationRow(userId, conversationId) {
  return db.prepare(
    `SELECT c.*, a.display_name AS agent_name
     FROM conversations c
     LEFT JOIN agents a ON a.id = c.agent_id
     WHERE c.id = ? AND c.user_id = ? AND c.platform = ?`,
  ).get(conversationId, userId, COWORK_PLATFORM);
}

function requireConversation(userId, conversationId) {
  const row = getConversationRow(userId, conversationId);
  if (!row) throw serviceError('Cowork chat not found.', 404);
  return row;
}

function listConversations(userId, options = {}) {
  const rows = db.prepare(
    `SELECT c.*, a.display_name AS agent_name,
       (SELECT COUNT(*) FROM conversation_messages cm WHERE cm.conversation_id = c.id) AS message_count,
       (SELECT COUNT(*) FROM cowork_input_requests cir
          WHERE cir.conversation_id = c.id AND cir.status = 'pending') AS pending_input_count,
       (SELECT ar.id FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_id,
       (SELECT ar.status FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_status,
       (SELECT ar.title FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_title,
       (SELECT ar.interaction_mode FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_mode,
       (SELECT ar.device_target FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_device_target,
       (SELECT ar.model FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_model,
       (SELECT ar.total_tokens FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_total_tokens,
       (SELECT ar.created_at FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_created_at,
       (SELECT ar.updated_at FROM agent_runs ar WHERE ar.conversation_id = c.id
          ORDER BY ar.created_at DESC LIMIT 1) AS latest_run_updated_at
     FROM conversations c
     LEFT JOIN agents a ON a.id = c.agent_id
     WHERE c.user_id = ? AND c.platform = ?
     ORDER BY c.updated_at DESC, c.created_at DESC`,
  ).all(userId, COWORK_PLATFORM);
  return rows.map((row) => serializeConversation(row, options));
}

function createConversation(userId, input = {}, options = {}) {
  const agent = resolveAgent(userId, input.agentId ?? input.agent_id);
  const title = input.title == null
    ? 'New chat'
    : requireText(input.title, 'Title', 160);
  const mode = normalizeMode(input.mode ?? input.interactionMode, 'agent');
  const deviceOverride = normalizeDeviceOverride(
    input.deviceTargetOverride ?? input.device_target_override,
  );
  const workspacePathOverride = normalizeWorkspacePathOverride(
    input.workspacePathOverride ?? input.workspace_path_override,
  );
  const modelOverride = normalizeModelOverride(input.modelOverride ?? input.model_override);
  const id = randomUUID();
  db.prepare(
    `INSERT INTO conversations (
      id, user_id, agent_id, platform, title, interaction_mode,
      device_target_override, manually_titled, workspace_path_override, model_override
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    userId,
    agent.id,
    COWORK_PLATFORM,
    title,
    mode,
    deviceOverride,
    input.title == null ? 0 : 1,
    workspacePathOverride,
    modelOverride,
  );
  return serializeConversation(getConversationRow(userId, id), options);
}

function updateConversation(userId, conversationId, input = {}, options = {}) {
  const current = requireConversation(userId, conversationId);
  const hasTitle = Object.prototype.hasOwnProperty.call(input, 'title');
  const title = hasTitle
    ? requireText(input.title, 'Title', 160)
    : current.title;
  const agent = (Object.prototype.hasOwnProperty.call(input, 'agentId')
    || Object.prototype.hasOwnProperty.call(input, 'agent_id'))
    ? resolveAgent(userId, input.agentId ?? input.agent_id)
    : null;
  const mode = (Object.prototype.hasOwnProperty.call(input, 'mode')
    || Object.prototype.hasOwnProperty.call(input, 'interactionMode'))
    ? normalizeMode(input.mode ?? input.interactionMode)
    : current.interaction_mode;
  const hasDeviceOverride = Object.prototype.hasOwnProperty.call(input, 'deviceTargetOverride')
    || Object.prototype.hasOwnProperty.call(input, 'device_target_override');
  const deviceOverride = hasDeviceOverride
    ? normalizeDeviceOverride(input.deviceTargetOverride ?? input.device_target_override)
    : current.device_target_override;
  const hasWorkspaceOverride = Object.prototype.hasOwnProperty.call(input, 'workspacePathOverride')
    || Object.prototype.hasOwnProperty.call(input, 'workspace_path_override');
  const workspacePathOverride = hasWorkspaceOverride
    ? normalizeWorkspacePathOverride(input.workspacePathOverride ?? input.workspace_path_override)
    : current.workspace_path_override;
  const hasModelOverride = Object.prototype.hasOwnProperty.call(input, 'modelOverride')
    || Object.prototype.hasOwnProperty.call(input, 'model_override');
  const modelOverride = hasModelOverride
    ? normalizeModelOverride(input.modelOverride ?? input.model_override)
    : current.model_override;

  db.prepare(
    `UPDATE conversations
     SET title = ?, agent_id = ?, interaction_mode = ?, device_target_override = ?,
         manually_titled = ?, workspace_path_override = ?, model_override = ?,
         updated_at = datetime('now')
     WHERE id = ? AND user_id = ? AND platform = ?`,
  ).run(
    title,
    agent?.id || current.agent_id,
    mode,
    deviceOverride,
    hasTitle ? 1 : current.manually_titled,
    workspacePathOverride,
    modelOverride,
    conversationId,
    userId,
    COWORK_PLATFORM,
  );
  return serializeConversation(getConversationRow(userId, conversationId), options);
}

function autoTitleConversation(userId, conversationId, content) {
  const row = requireConversation(userId, conversationId);
  if (row.manually_titled === 1 || row.title !== 'New chat') return row.title;
  const normalized = String(content || '').replace(/\s+/g, ' ').trim();
  if (!normalized) return row.title;
  const title = normalized.length > 72 ? `${normalized.slice(0, 69).trimEnd()}...` : normalized;
  db.prepare(
    `UPDATE conversations SET title = ?, updated_at = datetime('now')
     WHERE id = ? AND user_id = ? AND platform = ? AND manually_titled = 0`,
  ).run(title, conversationId, userId, COWORK_PLATFORM);
  return title;
}

function serializeMessage(row) {
  const metadata = parseJson(row.metadata_json, {});
  const displayContent = typeof metadata.displayContent === 'string'
    ? metadata.displayContent.trim()
    : '';
  return {
    id: Number(row.id),
    conversationId: row.conversation_id,
    runId: row.run_id || null,
    agentId: row.agent_id || null,
    agentName: row.agent_name || null,
    role: row.role,
    content: displayContent || row.content || '',
    metadata,
    createdAt: row.created_at,
  };
}

function listMessages(userId, conversationId, options = {}) {
  requireConversation(userId, conversationId);
  const limit = Math.min(Math.max(Number(options.limit) || 100, 1), 300);
  const rows = db.prepare(
    `SELECT cm.*, a.display_name AS agent_name
     FROM conversation_messages cm
     JOIN conversations c ON c.id = cm.conversation_id
     LEFT JOIN agents a ON a.id = cm.agent_id
     WHERE cm.conversation_id = ? AND c.user_id = ? AND c.platform = ?
     ORDER BY cm.id DESC LIMIT ?`,
  ).all(conversationId, userId, COWORK_PLATFORM, limit);
  return rows.reverse().map(serializeMessage);
}

function listActivity(userId, conversationId) {
  requireConversation(userId, conversationId);
  const runs = db.prepare(
    `SELECT * FROM agent_runs
     WHERE conversation_id = ? AND user_id = ?
     ORDER BY created_at DESC LIMIT 30`,
  ).all(conversationId, userId);
  return runs.map((run) => ({
    id: run.id,
    conversationId: run.conversation_id,
    agentId: run.agent_id || null,
    title: run.title || '',
    status: run.status || 'pending',
    mode: run.interaction_mode || 'agent',
    deviceTarget: run.device_target || null,
    model: run.model || null,
    totalTokens: Number(run.total_tokens || 0),
    error: run.error || null,
    createdAt: run.created_at,
    updatedAt: run.updated_at,
    completedAt: run.completed_at,
    steps: db.prepare(
      `SELECT id, step_index, type, description, status, tool_name, tool_input,
              result, error, started_at, completed_at
       FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC`,
    ).all(run.id).map((step) => ({
      id: step.id,
      index: Number(step.step_index || 0),
      type: step.type,
      description: step.description || '',
      status: step.status,
      toolName: step.tool_name || null,
      toolInput: parseJson(step.tool_input, {}),
      result: parseJson(step.result, step.result || null),
      error: step.error || null,
      startedAt: step.started_at,
      completedAt: step.completed_at,
    })),
    events: listRunEvents(run.id),
  }));
}

function listInputRequests(userId, conversationId) {
  requireConversation(userId, conversationId);
  return db.prepare(
    `SELECT * FROM cowork_input_requests
     WHERE conversation_id = ? AND user_id = ?
     ORDER BY created_at ASC`,
  ).all(conversationId, userId).map((row) => ({
    id: row.id,
    conversationId: row.conversation_id,
    runId: row.run_id,
    agentId: row.agent_id || null,
    status: row.status,
    schema: parseJson(row.schema_json, { questions: [] }),
    answers: parseJson(row.answers_json, null),
    createdAt: row.created_at,
    answeredAt: row.answered_at,
  }));
}

function validateQuestionSchema(input) {
  const questions = Array.isArray(input?.questions) ? input.questions : [];
  if (questions.length < 1 || questions.length > 3) {
    throw serviceError('Structured input requires between one and three questions.');
  }
  const ids = new Set();
  const normalized = questions.map((question, index) => {
    const id = requireText(question?.id || `question_${index + 1}`, 'Question ID', 64);
    if (!/^[a-z0-9_]+$/i.test(id) || ids.has(id)) {
      throw serviceError('Question IDs must be unique letters, numbers, or underscores.');
    }
    ids.add(id);
    const prompt = requireText(question?.question || question?.prompt, 'Question', 500);
    const options = Array.isArray(question?.options) ? question.options : [];
    if (options.length < 2 || options.length > 3) {
      throw serviceError('Each structured question requires two or three options.');
    }
    return {
      id,
      header: requireText(question?.header || `Question ${index + 1}`, 'Question header', 24),
      question: prompt,
      options: options.map((option) => ({
        label: requireText(option?.label, 'Option label', 80),
        description: requireText(option?.description, 'Option description', 240),
        recommended: option?.recommended === true,
      })),
      allowCustom: question?.allowCustom !== false,
    };
  });
  return { questions: normalized };
}

function createInputRequest({ userId, conversationId, runId, agentId, schema }) {
  requireConversation(userId, conversationId);
  const normalized = validateQuestionSchema(schema);
  const id = randomUUID();
  db.prepare(
    `INSERT INTO cowork_input_requests (
      id, conversation_id, run_id, user_id, agent_id, schema_json
    ) VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(id, conversationId, runId, userId, agentId || null, JSON.stringify(normalized));
  const content = normalized.questions.map((question) => question.question).join('\n');
  db.prepare(
    `INSERT INTO conversation_messages (
      conversation_id, run_id, agent_id, role, content, metadata_json
    ) VALUES (?, ?, ?, 'assistant', ?, ?)`,
  ).run(
    conversationId,
    runId,
    agentId || null,
    content,
    JSON.stringify({ structuredInputRequestId: id, structuredInput: normalized }),
  );
  db.prepare(
    `UPDATE conversations SET updated_at = datetime('now')
     WHERE id = ? AND user_id = ?`,
  ).run(conversationId, userId);
  return { id, conversationId, runId, agentId: agentId || null, schema: normalized };
}

function answerInputRequest(userId, conversationId, requestId, answers) {
  requireConversation(userId, conversationId);
  const request = db.prepare(
    `SELECT * FROM cowork_input_requests
     WHERE id = ? AND conversation_id = ? AND user_id = ?`,
  ).get(requestId, conversationId, userId);
  if (!request) throw serviceError('Input request not found.', 404);
  if (request.status !== 'pending') throw serviceError('Input request was already answered.', 409);
  const schema = parseJson(request.schema_json, { questions: [] });
  const input = answers && typeof answers === 'object' && !Array.isArray(answers) ? answers : {};
  const normalized = {};
  for (const question of schema.questions || []) {
    const answer = typeof input[question.id] === 'string' ? input[question.id].trim() : '';
    if (!answer) throw serviceError(`Answer for ${question.header} is required.`);
    if (answer.length > 2000) throw serviceError(`Answer for ${question.header} is too long.`);
    normalized[question.id] = answer;
  }
  const answerUpdate = db.prepare(
    `UPDATE cowork_input_requests
     SET status = 'answered', answers_json = ?, answered_at = datetime('now')
     WHERE id = ? AND status = 'pending'`,
  ).run(JSON.stringify(normalized), requestId);
  if (answerUpdate.changes !== 1) {
    throw serviceError('Input request was already answered.', 409);
  }
  db.prepare(
    `UPDATE conversations SET updated_at = datetime('now')
     WHERE id = ? AND user_id = ?`,
  ).run(conversationId, userId);
  db.prepare(
    `UPDATE agent_runs
     SET status = 'completed', runtime_state = 'completed',
         updated_at = datetime('now'), completed_at = COALESCE(completed_at, datetime('now'))
     WHERE id = ? AND user_id = ? AND status = 'waiting_input'`,
  ).run(request.run_id, userId);
  return {
    requestId,
    conversationId,
    runId: request.run_id,
    answers: normalized,
    prompt: (schema.questions || []).map((question) => (
      `${question.header}: ${normalized[question.id]}`
    )).join('\n'),
  };
}

function getRunContext(userId, conversationId, runtimeManager = null) {
  const conversation = requireConversation(userId, conversationId);
  const device = resolveEffectiveDeviceTarget(
    userId,
    conversation.device_target_override,
    runtimeManager,
  );
  if (!device.available) {
    throw serviceError(
      `${device.effective === 'local' ? 'Local' : 'Cloud'} computer is unavailable.`,
      409,
      'COWORK_DEVICE_UNAVAILABLE',
    );
  }
  return {
    conversationId: conversation.id,
    agentId: conversation.agent_id,
    mode: normalizeMode(conversation.interaction_mode, 'agent'),
    deviceTarget: device.effective,
    device,
    workspacePathOverride: device.effective === 'local'
      ? (conversation.workspace_path_override || null)
      : null,
    modelOverride: conversation.model_override || null,
  };
}

function deleteConversation(userId, conversationId, agentEngine = null) {
  requireConversation(userId, conversationId);
  const activeRuns = db.prepare(
    `SELECT id FROM agent_runs
     WHERE conversation_id = ? AND user_id = ?
       AND status NOT IN ('completed', 'failed', 'stopped', 'interrupted', 'cancelled')`,
  ).all(conversationId, userId);
  for (const run of activeRuns) agentEngine?.abort?.(run.id, { userId, reason: 'Cowork chat deleted.' });
  db.transaction(() => {
    db.prepare(
      'DELETE FROM conversation_history WHERE conversation_id = ? AND user_id = ?',
    ).run(conversationId, userId);
    db.prepare(
      'DELETE FROM agent_runs WHERE conversation_id = ? AND user_id = ?',
    ).run(conversationId, userId);
    db.prepare(
      'DELETE FROM conversations WHERE id = ? AND user_id = ? AND platform = ?',
    ).run(conversationId, userId, COWORK_PLATFORM);
  })();
  return { deleted: true };
}

module.exports = {
  COWORK_PLATFORM,
  answerInputRequest,
  autoTitleConversation,
  createConversation,
  createInputRequest,
  deleteConversation,
  getRunContext,
  listActivity,
  listConversations,
  listInputRequests,
  listMessages,
  normalizeDeviceOverride,
  normalizeMode,
  normalizeModelOverride,
  requireConversation,
  resolveEffectiveDeviceTarget,
  updateConversation,
  validateQuestionSchema,
};
