'use strict';

const { v4: uuidv4 } = require('uuid');
const db = require('../../../db/database');
const { activateTools } = require('../toolSelector');
const { recordRunEvent } = require('../runEvents');
const { parseMaybeJson } = require('../logFormat');
const { mergeGoalContracts } = require('./completion_judge');
const { buildInitialProgressLedger } = require('./progress_monitor');
const {
  createDeliveryState,
  markInterimDelivered,
  markFinalDelivered,
} = require('./delivery_state');

function isoNow() {
  return new Date().toISOString();
}

function persistRunMetadata(_engine, runId, patch = {}) {
  if (!runId || !patch || typeof patch !== 'object') return;
  const existing = db.prepare('SELECT metadata_json FROM agent_runs WHERE id = ?').get(runId);
  const current = parseMaybeJson(existing?.metadata_json, {}) || {};
  const next = { ...current, ...patch };
  db.prepare('UPDATE agent_runs SET metadata_json = ? WHERE id = ?')
    .run(JSON.stringify(next), runId);
}

function updateRunGoalContract(engine, runId, patch = {}, options = {}) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) return null;
  runMeta.goalContract = mergeGoalContracts(runMeta.goalContract, patch);
  if (options.persist !== false) {
    persistRunMetadata(engine, runId, {
      goalContract: runMeta.goalContract,
    });
  }
  return runMeta.goalContract;
}

function buildProgressLedgerSnapshot(_engine, runMeta) {
  if (!runMeta?.progressLedger) return null;
  return {
    currentStep: runMeta.progressLedger.currentStep || null,
    currentTool: runMeta.progressLedger.currentTool || null,
    currentStepStartedAt: runMeta.progressLedger.currentStepStartedAt || null,
    lastVerifiedProgressAt: runMeta.progressLedger.lastVerifiedProgressAt || null,
    lastUserVisibleUpdateAt: runMeta.progressLedger.lastUserVisibleUpdateAt || null,
    lastFinalDeliveryAt: runMeta.progressLedger.lastFinalDeliveryAt || null,
    heartbeatCount: Number(runMeta.progressLedger.heartbeatCount || 0),
    stallNotifiedAt: runMeta.progressLedger.stallNotifiedAt || null,
    progressState: runMeta.progressLedger.progressState || 'active',
    currentPhase: runMeta.progressLedger.currentPhase || 'idle',
  };
}

function persistProgressLedger(engine, runId) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta?.progressLedger) return;
  persistRunMetadata(engine, runId, {
    progressLedger: buildProgressLedgerSnapshot(engine, runMeta),
  });
}

function updateRunProgress(engine, runId, patch = {}, options = {}) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) return null;
  if (!runMeta.progressLedger) {
    runMeta.progressLedger = buildInitialProgressLedger({
      startedAt: runMeta.startedAtIso || isoNow(),
    });
  }

  const previousState = runMeta.progressLedger.progressState || 'active';
  runMeta.progressLedger = {
    ...runMeta.progressLedger,
    ...patch,
  };

  if (options.verified === true) {
    runMeta.progressLedger.lastVerifiedProgressAt = options.timestamp || isoNow();
    runMeta.progressLedger.progressState = 'active';
    runMeta.progressLedger.stallNotifiedAt = null;
    recordRunEventSafe(engine, runMeta.userId, runId, 'progress_verified', {
      phase: runMeta.progressLedger.currentPhase || 'idle',
      currentStep: runMeta.progressLedger.currentStep || null,
      currentTool: runMeta.progressLedger.currentTool || null,
    }, { agentId: runMeta.agentId, stepId: options.stepId || null });
    if (previousState === 'stalled') {
      recordRunEventSafe(engine, runMeta.userId, runId, 'progress_resumed', {
        phase: runMeta.progressLedger.currentPhase || 'idle',
        currentStep: runMeta.progressLedger.currentStep || null,
        currentTool: runMeta.progressLedger.currentTool || null,
      }, { agentId: runMeta.agentId, stepId: options.stepId || null });
    }
  }

  if (options.persist !== false) {
    persistProgressLedger(engine, runId);
  }
  return runMeta.progressLedger;
}

function markRunVisibleProgress(engine, runId, timestamp = isoNow()) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) return null;
  if (!runMeta.deliveryState) runMeta.deliveryState = createDeliveryState();
  markInterimDelivered(runMeta.deliveryState);
  const ledger = updateRunProgress(engine, runId, {
    lastUserVisibleUpdateAt: timestamp,
  }, {
    persist: false,
  });
  persistProgressLedger(engine, runId);
  return ledger;
}

function markRunFinalDelivery(engine, runId, content = '', timestamp = isoNow()) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) return null;
  if (!runMeta.deliveryState) runMeta.deliveryState = createDeliveryState();
  markFinalDelivered(runMeta.deliveryState);
  runMeta.messagingSent = true;
  runMeta.finalDeliverySent = true;
  runMeta.lastSentMessage = String(content || '').trim() || runMeta.lastSentMessage || '';
  const ledger = updateRunProgress(engine, runId, {
    lastUserVisibleUpdateAt: timestamp,
    lastFinalDeliveryAt: timestamp,
    progressState: 'complete',
  }, {
    persist: false,
  });
  persistProgressLedger(engine, runId);
  return ledger;
}

function recordRunEventSafe(_engine, userId, runId, eventType, payload = {}, options = {}) {
  try {
    return recordRunEvent({
      runId,
      userId,
      agentId: options.agentId || null,
      eventType,
      requestId: options.requestId || null,
      stepId: options.stepId || null,
      payload,
    });
  } catch {
    return null;
  }
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

function activateToolsForRun(engine, runId, names = []) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta) throw new Error('Run is not active.');
  const result = activateTools(
    runMeta.activeTools,
    runMeta.toolCatalog,
    names,
    runMeta.toolSelectionOptions,
  );
  runMeta.activeTools = result.tools;
  recordRunEventSafe(engine, runMeta.userId, runId, 'tools_activated', {
    activated: result.activated,
    evicted: result.evicted,
    unknown: result.unknown,
    notActivated: result.notActivated,
    activeToolNames: result.tools.map((tool) => tool.name),
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
      && (!conversationId || runMeta.conversationId === conversationId)
  );
}

function enqueueSteering(engine, runId, content, metadata = {}) {
  const runMeta = engine.getRunMeta(runId);
  const trimmed = typeof content === 'string' ? content.trim() : '';
  if (!runMeta || runMeta.aborted || !trimmed) return null;

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
  messages.push({
    role: 'system',
    content: [
      'The user sent follow-up messages while you were already working.',
      'Treat them as steering or next-up context for the same conversation.',
      'If a message materially changes the active task, incorporate it now.',
      'If it is unrelated or better handled after the current task, finish the current work first and then address it.',
    ].join(' '),
  });

  for (const entry of queued) {
    messages.push({ role: 'user', content: entry.content });
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

function isRunStopped(engine, runId) {
  return engine.getRunMeta(runId)?.aborted === true;
}

function attachProcessToRun(engine, runId, pid) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta || !pid) return;
  runMeta.toolPids.add(pid);
  if (runMeta.aborted) {
    if (engine.runtimeManager && typeof engine.runtimeManager.killCommand === 'function') {
      void engine.runtimeManager.killCommand(runMeta.userId, pid, 'aborted', {
        deviceTarget: runMeta.deviceTarget,
      });
    }
  }
}

function detachProcessFromRun(engine, runId, pid) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta || !pid) return;
  runMeta.toolPids.delete(pid);
}

module.exports = {
  activateToolsForRun,
  applyQueuedSteering,
  applyQueuedSystemSteering,
  attachProcessToRun,
  buildProgressLedgerSnapshot,
  detachProcessFromRun,
  enqueueSteering,
  enqueueSystemSteering,
  findActiveRunForUser,
  findSteerableRunForUser,
  getActiveTools,
  initializeToolRuntime,
  isRunStopped,
  markRunFinalDelivery,
  markRunVisibleProgress,
  persistProgressLedger,
  persistRunMetadata,
  recordRunEventSafe,
  updateRunGoalContract,
  updateRunProgress,
};
