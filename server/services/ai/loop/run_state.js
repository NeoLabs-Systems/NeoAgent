'use strict';

const { createHash } = require('crypto');
const { v4: uuidv4 } = require('uuid');
const db = require('../../../db/database');
const { activateTools, searchTools } = require('../toolSelector');
const { parseMaybeJson } = require('../logFormat');
const { recordEventSafe } = require('../runtime/events/run_event_store');
const { EVENT_TYPES } = require('../runtime/events/event_types');
const { createRunDelivery } = require('../runtime/delivery/run_delivery');
const { moveRunToBackground } = require('./background_runs');
const { renderFragment } = require('../prompts/registry');
const { getPublicRunScope } = require('../../messaging/public_audience');
const { runToolRefusal } = require('../tools/metadata');
const { addTrustedText } = require('../../security/run_trust');

function isoNow() {
  return new Date().toISOString();
}

function digestText(text) {
  return `sha256:${createHash('sha256').update(String(text || '')).digest('hex').slice(0, 24)}`;
}

function persistRunMetadata(_engine, runId, patch = {}) {
  if (!runId || !patch || typeof patch !== 'object') return;
  const existing = db.prepare('SELECT metadata_json FROM agent_runs WHERE id = ?').get(runId);
  const current = parseMaybeJson(existing?.metadata_json, {}) || {};
  const next = { ...current, ...patch };
  db.prepare('UPDATE agent_runs SET metadata_json = ? WHERE id = ?')
    .run(JSON.stringify(next), runId);
}

// A reply in the chat the run answers reached the user, but it says nothing
// about work still to come, so the run stays in the foreground and its chat
// waits for it.
function markRunVisibleReply(engine, runId, timestamp = isoNow()) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) return null;
  runMeta.lastUserVisibleAt = timestamp;
  return timestamp;
}

// A progress update tells the user the run is still working on something,
// which is what moves an owner's chat run to the background.
function markRunVisibleProgress(engine, runId, timestamp = isoNow()) {
  const visibleAt = markRunVisibleReply(engine, runId, timestamp);
  if (visibleAt) moveRunToBackground(engine, runId);
  return visibleAt;
}

function markRunFinalDelivery(engine, runId, content = '', timestamp = isoNow()) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) return null;
  if (!runMeta.delivery) runMeta.delivery = createRunDelivery();
  runMeta.delivery.finalDelivered = true;
  // Kept apart from `sent`: a task run's answer closes the run on its own surface,
  // and its result still has to reach the task's target.
  runMeta.delivery.finalContent = String(content || '').trim();
  runMeta.lastUserVisibleAt = timestamp;
  return timestamp;
}

function recordRunEventSafe(_engine, userId, runId, eventType, payload = {}, options = {}) {
  return recordEventSafe({
    runId,
    userId,
    agentId: options.agentId || null,
    eventType,
    requestId: options.requestId || null,
    stepId: options.stepId || null,
    payload,
  });
}

function initializeToolRuntime(engine, runId, allTools, initialTools, options = {}) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) return;
  runMeta.toolCatalog = Array.isArray(allTools) ? allTools : [];
  runMeta.activeTools = Array.isArray(initialTools) ? initialTools : [];
  runMeta.toolSelectionOptions = {
    includeCoreFileTools: options.includeCoreFileTools === true,
  };
}

function getActiveTools(engine, runId) {
  return engine.getRunMeta(runId)?.activeTools || [];
}

// Usage notes for the integrations behind `tools`, each integration at most
// once per run, so the notes arrive with the tools instead of every prompt.
function describeIntegrationsForRun(engine, runId, tools = []) {
  const runMeta = engine.getRunMeta(runId);
  const integrationManager = engine.app?.locals?.integrationManager;
  if (!runMeta || typeof integrationManager?.summarizeConnectedProviders !== 'function') return '';
  // The owner's account summaries stay out of runs answering public threads.
  if (getPublicRunScope(runId)) return '';
  runMeta.describedIntegrations ||= new Set();
  const keys = [...new Set(tools.map((tool) => tool?.integration).filter(Boolean))]
    .filter((key) => !runMeta.describedIntegrations.has(key));
  if (keys.length === 0) return '';
  keys.forEach((key) => runMeta.describedIntegrations.add(key));
  return integrationManager.summarizeConnectedProviders(runMeta.userId, runMeta.agentId, keys);
}

// Refresh from registered services, never from a model-proposed tool name.
// New MCP servers/skills become discoverable without widening child limits.
function refreshToolCatalog(engine, runId, runMeta) {
  const app = runMeta.session?.app || engine.app;
  const publicScope = getPublicRunScope(runId);
  const options = runMeta.session?.options || {};
  const builtIn = engine.getAvailableTools(app, { userId: runMeta.userId, agentId: runMeta.agentId,
    triggerSource: runMeta.triggerSource, triggerType: runMeta.triggerType, publicScope });
  const mcp = app?.locals?.mcpManager || app?.locals?.mcpClient || engine.mcpManager;
  const external = !publicScope && mcp ? mcp.getAllTools(runMeta.userId, { agentId: runMeta.agentId }) : [];
  runMeta.toolCatalog = [...builtIn, ...external].filter((tool) =>
    !runToolRefusal([tool], options, tool.name));
}

function searchToolsForRun(engine, runId, query, limit = 8, alsoNames = []) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) throw new Error('Run is not active.');
  refreshToolCatalog(engine, runId, runMeta);
  const results = searchTools(runMeta.toolCatalog, query, {
    limit,
    activeNames: runMeta.activeTools.map((tool) => tool.name),
    alsoNames,
  });
  recordRunEventSafe(engine, runMeta.userId, runId, EVENT_TYPES.TOOLS_SELECTED, {
    kind: 'search',
    query_digest: digestText(query),
    result_names: results.map((tool) => tool.name),
  }, { agentId: runMeta.agentId });
  const resultNames = new Set(results.map((tool) => tool.name));
  const integrationNotes = describeIntegrationsForRun(
    engine,
    runId,
    runMeta.toolCatalog.filter((tool) => resultNames.has(tool?.name)),
  );
  return {
    success: true,
    query: String(query || ''),
    results,
    ...(integrationNotes ? { integration_notes: integrationNotes } : {}),
    instruction: results.length
      ? 'Activate the exact tools you need with activate_tools.'
      : 'No matching tool was found. Try a broader capability description.',
  };
}

function activateToolsForRun(engine, runId, names = []) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) throw new Error('Run is not active.');
  refreshToolCatalog(engine, runId, runMeta);
  const result = activateTools(
    runMeta.activeTools,
    runMeta.toolCatalog,
    names,
    runMeta.toolSelectionOptions,
  );
  runMeta.activeTools = result.tools;
  recordRunEventSafe(engine, runMeta.userId, runId, EVENT_TYPES.TOOLS_SELECTED, {
    kind: 'activate',
    activated: result.activated,
    evicted: result.evicted,
    unknown: result.unknown,
    not_activated: result.notActivated,
    active_tool_names: result.tools.map((tool) => tool.name),
  }, { agentId: runMeta.agentId });
  return {
    success: result.unknown.length === 0 && result.notActivated.length === 0,
    activated: result.activated,
    evicted: result.evicted,
    unknown: result.unknown,
    not_activated: result.notActivated,
    active_tools: result.tools.map((tool) => tool.name),
  };
}

function findActiveRunForUser(engine, userId, predicate = null) {
  let candidate = null;
  for (const [runId, runMeta] of engine.activeRuns.entries()) {
    if (runMeta.userId !== userId || runMeta.aborted) continue;
    if (typeof predicate === 'function' && !predicate(runMeta, runId)) continue;
    if (!candidate || (runMeta.startedAt || 0) >= (candidate.startedAt || 0)) {
      candidate = { runId, ...runMeta };
    }
  }
  return candidate;
}

function findSteerableRunForUser(engine, userId, triggerSource = 'web', conversationId = null) {
  return findActiveRunForUser(
    engine,
    userId,
    (runMeta) => runMeta.triggerSource === triggerSource
      && runMeta.triggerType === 'user'
      && !runMeta.background
      && !runMeta.steeringClosed
      && (!conversationId || runMeta.conversationId === conversationId)
  );
}

function enqueueSteering(engine, runId, content, metadata = {}) {
  const runMeta = engine.getRunMeta(runId);
  const trimmed = typeof content === 'string' ? content.trim() : '';
  if (!runMeta || runMeta.aborted || runMeta.steeringClosed || !trimmed) return null;

  const item = {
    id: uuidv4(),
    content: trimmed,
    metadata,
    createdAt: isoNow(),
  };

  runMeta.steeringQueue.push(item);
  engine.emit(runMeta.userId, 'run:steer_queued', {
    runId,
    conversationId: runMeta.conversationId || null,
    content: item.content,
    pendingCount: runMeta.steeringQueue.length,
  });

  return {
    runId,
    pendingCount: runMeta.steeringQueue.length,
    item,
  };
}

function enqueueSystemSteering(engine, runId, content, metadata = {}) {
  const runMeta = engine.getRunMeta(runId);
  const trimmed = typeof content === 'string' ? content.trim() : '';
  if (!runMeta || runMeta.aborted || !trimmed) return null;
  if (!Array.isArray(runMeta.systemSteeringQueue)) {
    runMeta.systemSteeringQueue = [];
  }
  const signature = JSON.stringify({
    content: trimmed,
    reason: metadata.reason || '',
  });
  if (runMeta.systemSteeringQueue.some((item) => item.signature === signature)) {
    return null;
  }
  const item = {
    id: uuidv4(),
    content: trimmed,
    metadata,
    signature,
    createdAt: isoNow(),
  };
  runMeta.systemSteeringQueue.push(item);
  return item;
}

function applyQueuedSystemSteering(engine, runId, messages) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta?.systemSteeringQueue?.length) {
    return { messages, appliedCount: 0 };
  }

  const queued = runMeta.systemSteeringQueue.splice(0, runMeta.systemSteeringQueue.length);
  for (const entry of queued) {
    messages.push({ role: 'system', content: entry.content });
  }

  return { messages, appliedCount: queued.length };
}

function applyQueuedSteering(engine, runId, messages, { userId, conversationId }) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta?.steeringQueue?.length) {
    return { messages, appliedCount: 0 };
  }

  const queued = runMeta.steeringQueue.splice(0, runMeta.steeringQueue.length);
  messages.push({ role: 'system', content: renderFragment('runtime/steering.md') });

  for (const entry of queued) {
    messages.push({ role: 'user', content: entry.content });
    addTrustedText(runMeta.trust, entry.content);
    runMeta.trust?.ownerStatements?.push(entry.content);
    if (conversationId) {
      db.prepare(
        `INSERT INTO conversation_messages (
          conversation_id, run_id, agent_id, role, content, metadata_json
        ) VALUES (?, ?, ?, 'user', ?, ?)`,
      ).run(
        conversationId,
        runId,
        runMeta.agentId || null,
        entry.content,
        JSON.stringify({ steering: true }),
      );
    }
  }

  engine.emit(userId, 'run:steer_applied', {
    runId,
    conversationId: runMeta.conversationId || conversationId || null,
    count: queued.length,
    pendingCount: runMeta.steeringQueue.length,
    latestContent: queued[queued.length - 1]?.content || '',
  });

  return { messages, appliedCount: queued.length };
}

module.exports = {
  activateToolsForRun,
  applyQueuedSteering,
  applyQueuedSystemSteering,
  enqueueSteering,
  enqueueSystemSteering,
  findActiveRunForUser,
  findSteerableRunForUser,
  getActiveTools,
  initializeToolRuntime,
  describeIntegrationsForRun,
  searchToolsForRun,
  markRunFinalDelivery,
  markRunVisibleProgress,
  markRunVisibleReply,
  persistRunMetadata,
  recordRunEventSafe,
};
