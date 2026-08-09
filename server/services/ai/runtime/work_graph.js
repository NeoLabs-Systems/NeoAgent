'use strict';

const { randomUUID } = require('crypto');
const db = require('../../../db/database');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');

const NODE_STATUSES = Object.freeze({
  PENDING: 'pending',
  READY: 'ready',
  RUNNING: 'running',
  COMPLETED: 'completed',
  FAILED: 'failed',
  BLOCKED: 'blocked',
  REOPENED: 'reopened',
  SKIPPED: 'skipped',
});

function parseJson(value, fallback) {
  if (value == null || value === '') return fallback;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function serializeNode(row) {
  if (!row) return null;
  return {
    id: row.id,
    runId: row.run_id,
    nodeKey: row.node_key,
    kind: row.kind,
    status: row.status,
    version: Number(row.version || 1),
    objective: row.objective || '',
    successCriteria: parseJson(row.success_criteria_json, []),
    allowedTools: parseJson(row.allowed_tools_json, []),
    resourceReads: parseJson(row.resource_reads_json, []),
    resourceWrites: parseJson(row.resource_writes_json, []),
    evidence: parseJson(row.evidence_json, []),
    artifactIds: parseJson(row.artifact_ids_json, []),
    blockers: parseJson(row.blockers_json, []),
    defects: parseJson(row.defects_json, []),
    retryCount: Number(row.retry_count || 0),
    attemptBudget: Number(row.attempt_budget || 5),
    assignedWorker: row.assigned_worker || null,
    checkpointId: row.checkpoint_id || null,
    metadata: parseJson(row.metadata_json, {}),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function listNodes(runId) {
  const rows = db.prepare(
    `SELECT * FROM agent_work_nodes WHERE run_id = ? ORDER BY created_at ASC`,
  ).all(runId);
  return rows.map(serializeNode);
}

function listDependencies(runId) {
  return db.prepare(
    `SELECT node_id, depends_on_node_id FROM agent_node_dependencies WHERE run_id = ?`,
  ).all(runId).map((row) => ({
    nodeId: row.node_id,
    dependsOnNodeId: row.depends_on_node_id,
  }));
}

function createGraph(runId, nodes = [], { eventBus = null, userId = null, agentId = null } = {}) {
  return db.transaction(() => {
    db.prepare('DELETE FROM agent_node_dependencies WHERE run_id = ?').run(runId);
    db.prepare('DELETE FROM agent_work_nodes WHERE run_id = ?').run(runId);

    const created = [];
    const keyToId = new Map();

    for (const node of nodes) {
      const id = randomUUID();
      const nodeKey = String(node.id || node.nodeKey || id);
      keyToId.set(nodeKey, id);
      const status = node.status || (Array.isArray(node.dependencies) && node.dependencies.length
        ? NODE_STATUSES.PENDING
        : NODE_STATUSES.READY);
      db.prepare(
        `INSERT INTO agent_work_nodes (
          id, run_id, node_key, kind, status, objective, success_criteria_json,
          allowed_tools_json, resource_reads_json, resource_writes_json, metadata_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).run(
        id,
        runId,
        nodeKey,
        String(node.kind || 'execute'),
        status,
        String(node.objective || node.goal || nodeKey),
        JSON.stringify(node.success_criteria || node.successCriteria || []),
        JSON.stringify(node.allowed_tools || node.allowedTools || []),
        JSON.stringify(node.resource_reads || node.resourceReads || node.reads || []),
        JSON.stringify(node.resource_writes || node.resourceWrites || node.writes || []),
        JSON.stringify(node.metadata || {}),
      );
      created.push({ id, nodeKey, dependencies: node.dependencies || [] });
    }

    for (const node of created) {
      for (const depKey of node.dependencies || []) {
        const depId = keyToId.get(String(depKey));
        if (!depId) continue;
        db.prepare(
          `INSERT OR IGNORE INTO agent_node_dependencies (run_id, node_id, depends_on_node_id)
           VALUES (?, ?, ?)`,
        ).run(runId, node.id, depId);
      }
    }

    refreshReadyStates(runId);

    if (eventBus && userId) {
      eventBus.publish({
        runId,
        userId,
        agentId,
        eventType: EVENT_TYPES.PLAN_CREATED,
        payload: {
          node_count: created.length,
          node_keys: created.map((n) => n.nodeKey),
        },
        visibility: VISIBILITY.OPERATOR,
      });
    }

    return listNodes(runId);
  })();
}

function refreshReadyStates(runId) {
  const nodes = listNodes(runId);
  const deps = listDependencies(runId);
  const byId = new Map(nodes.map((n) => [n.id, n]));
  const depsByNode = new Map();
  for (const dep of deps) {
    if (!depsByNode.has(dep.nodeId)) depsByNode.set(dep.nodeId, []);
    depsByNode.get(dep.nodeId).push(dep.dependsOnNodeId);
  }

  for (const node of nodes) {
    if (![NODE_STATUSES.PENDING, NODE_STATUSES.REOPENED, NODE_STATUSES.READY].includes(node.status)) {
      continue;
    }
    const requirements = depsByNode.get(node.id) || [];
    const allDone = requirements.every((depId) => {
      const dep = byId.get(depId);
      return dep && dep.status === NODE_STATUSES.COMPLETED;
    });
    const nextStatus = allDone ? NODE_STATUSES.READY : NODE_STATUSES.PENDING;
    if (nextStatus !== node.status) {
      db.prepare(
        `UPDATE agent_work_nodes
         SET status = ?, version = version + 1, updated_at = datetime('now')
         WHERE id = ?`,
      ).run(nextStatus, node.id);
    }
  }
}

function nextActionableNodes(runId, { limit = 8 } = {}) {
  refreshReadyStates(runId);
  return db.prepare(
    `SELECT * FROM agent_work_nodes
     WHERE run_id = ? AND status IN ('ready', 'reopened')
     ORDER BY updated_at ASC
     LIMIT ?`,
  ).all(runId, Math.max(1, Math.min(Number(limit) || 8, 32))).map(serializeNode);
}

function updateNode(nodeId, patch = {}) {
  const current = db.prepare('SELECT * FROM agent_work_nodes WHERE id = ?').get(nodeId);
  if (!current) return null;

  const fields = [];
  const values = [];
  if (patch.status) {
    fields.push('status = ?');
    values.push(patch.status);
  }
  if (Object.hasOwn(patch, 'objective')) {
    fields.push('objective = ?');
    values.push(patch.objective || '');
  }
  if (Object.hasOwn(patch, 'evidence')) {
    fields.push('evidence_json = ?');
    values.push(JSON.stringify(patch.evidence || []));
  }
  if (Object.hasOwn(patch, 'artifactIds')) {
    fields.push('artifact_ids_json = ?');
    values.push(JSON.stringify(patch.artifactIds || []));
  }
  if (Object.hasOwn(patch, 'blockers')) {
    fields.push('blockers_json = ?');
    values.push(JSON.stringify(patch.blockers || []));
  }
  if (Object.hasOwn(patch, 'defects')) {
    fields.push('defects_json = ?');
    values.push(JSON.stringify(patch.defects || []));
  }
  if (Object.hasOwn(patch, 'retryCount')) {
    fields.push('retry_count = ?');
    values.push(Number(patch.retryCount) || 0);
  }
  if (Object.hasOwn(patch, 'assignedWorker')) {
    fields.push('assigned_worker = ?');
    values.push(patch.assignedWorker || null);
  }
  if (Object.hasOwn(patch, 'checkpointId')) {
    fields.push('checkpoint_id = ?');
    values.push(patch.checkpointId || null);
  }
  if (Object.hasOwn(patch, 'metadata')) {
    fields.push('metadata_json = ?');
    values.push(JSON.stringify(patch.metadata || {}));
  }
  if (fields.length === 0) return serializeNode(current);

  fields.push('version = version + 1');
  fields.push("updated_at = datetime('now')");
  values.push(nodeId);
  db.prepare(`UPDATE agent_work_nodes SET ${fields.join(', ')} WHERE id = ?`).run(...values);
  return serializeNode(db.prepare('SELECT * FROM agent_work_nodes WHERE id = ?').get(nodeId));
}

function completeNode(nodeId, { evidence = [], artifactIds } = {}) {
  const patch = {
    status: NODE_STATUSES.COMPLETED,
    evidence,
  };
  if (artifactIds !== undefined) patch.artifactIds = artifactIds;
  const node = updateNode(nodeId, patch);
  if (node) refreshReadyStates(node.runId);
  return node;
}

function reopenNodes(runId, nodeKeysOrIds = [], defects = []) {
  const nodes = listNodes(runId);
  const reopened = [];
  for (const node of nodes) {
    if (!nodeKeysOrIds.includes(node.id) && !nodeKeysOrIds.includes(node.nodeKey)) continue;
    const next = updateNode(node.id, {
      status: NODE_STATUSES.REOPENED,
      defects,
      retryCount: node.retryCount + 1,
    });
    if (next) reopened.push(next);
  }
  refreshReadyStates(runId);
  return reopened;
}

function requiredOpenNodes(runId) {
  return listNodes(runId).filter((node) => (
    node.status !== NODE_STATUSES.COMPLETED
    && node.status !== NODE_STATUSES.SKIPPED
    && node.metadata?.optional !== true
  ));
}


function graphFromContract(contract = {}) {
  const nodes = [];
  const deps = [];
  if ((contract.open_obligations || []).some((o) => o.type === 'plan' || o.id === 'plan')) {
    nodes.push({
      id: 'plan',
      kind: 'plan',
      objective: 'Create execution plan',
      success_criteria: ['Plan covers required deliverables'],
      dependencies: [],
    });
    deps.push('plan');
  }
  if ((contract.research_targets || []).length > 0 || contract.research_depth === 'deep') {
    nodes.push({
      id: 'research',
      kind: 'research',
      objective: 'Gather evidence for the request',
      success_criteria: contract.evidence_requirements || ['Relevant sources collected'],
      dependencies: [...deps],
    });
    deps.push('research');
  }
  nodes.push({
    id: 'execute',
    kind: 'execute',
    objective: contract.goal || 'Execute the task',
    success_criteria: contract.success_criteria || [],
    dependencies: [...deps],
  });
  if (contract.verification_required !== false) {
    nodes.push({
      id: 'verify',
      kind: 'verification',
      objective: 'Verify completion',
      success_criteria: contract.evidence_requirements || contract.success_criteria || [],
      dependencies: ['execute'],
    });
  }
  return nodes;
}

module.exports = {
  listNodes,
  createGraph,
  nextActionableNodes,
  updateNode,
  completeNode,
  reopenNodes,
  requiredOpenNodes,
  graphFromContract,
};
