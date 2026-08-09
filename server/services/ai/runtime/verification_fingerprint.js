'use strict';

const crypto = require('crypto');

const TRANSIENT_KEYS = new Set([
  'at',
  'createdAt',
  'created_at',
  'updatedAt',
  'updated_at',
  'completedAt',
  'completed_at',
  'startedAt',
  'started_at',
  'timestamp',
]);

function canonicalize(value) {
  if (value == null || typeof value !== 'object') return value;
  if (Array.isArray(value)) {
    return value
      .map(canonicalize)
      .sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)));
  }
  const next = {};
  for (const key of Object.keys(value).sort()) {
    if (TRANSIENT_KEYS.has(key) || value[key] === undefined) continue;
    next[key] = canonicalize(value[key]);
  }
  return next;
}

function nodeFingerprintView(node = {}) {
  return {
    nodeKey: node.nodeKey || node.id || '',
    version: Number(node.version || 0),
    status: node.status || '',
    evidence: node.evidence || [],
    artifactIds: node.artifactIds || [],
    defects: node.defects || [],
  };
}

function artifactFingerprintView(artifact = {}) {
  return {
    artifactId: artifact.artifactId || artifact.id || '',
    kind: artifact.kind || '',
    byteSize: Number(artifact.byteSize || artifact.byte_size || 0),
    complete: artifact.complete !== false,
    checksum: artifact.checksum || artifact.sha256 || '',
  };
}

function buildVerificationFingerprint({
  contractVersion = 0,
  finalContent = '',
  nodes = [],
  evidence = [],
  artifacts = [],
  sideEffects = [],
} = {}) {
  const payload = canonicalize({
    contractVersion: Number(contractVersion || 0),
    finalContent: String(finalContent || '').trim(),
    nodes: nodes.map(nodeFingerprintView),
    evidence,
    artifacts: artifacts.map(artifactFingerprintView),
    sideEffects: sideEffects.map((effect) => ({
      id: effect?.id || effect?.tool_name || '',
      tool: effect?.tool_name || effect?.tool || '',
      status: effect?.status || '',
    })),
  });
  return crypto.createHash('sha256').update(JSON.stringify(payload)).digest('hex');
}

module.exports = {
  buildVerificationFingerprint,
  canonicalize,
};
