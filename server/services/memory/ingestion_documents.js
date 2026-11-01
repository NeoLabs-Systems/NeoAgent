'use strict';

const { v4: uuidv4 } = require('uuid');
const { resolveAgentId } = require('../agents/manager');
const {
  normalizeDocument,
  normalizeSourceType,
  parseJsonObject,
  safeTrim,
} = require('./ingestion_support');
const { isAbortError, throwIfAborted } = require('../../utils/abort');

// Stores documents as source material and learns durable facts from them.
// The documents themselves never become memories.
async function ingestDocuments(service, userId, documents = [], options = {}) {
  const signal = options.signal || null;
  throwIfAborted(signal, 'Memory ingestion aborted.');
  const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
  const normalizedDocs = (Array.isArray(documents) ? documents : [])
    .map((document) => normalizeDocument(document, {
      sourceType: options.sourceType,
      providerKey: options.providerKey,
      connectionId: options.connectionId,
      sourceAccount: options.sourceAccount,
    }));
  const sourceType = normalizeSourceType(options.sourceType || normalizedDocs[0]?.sourceType);
  const jobId = uuidv4();
  const connectionId = Number.isInteger(Number(options.connectionId))
    ? Number(options.connectionId)
    : 0;
  const jobMetadata = parseJsonObject(options.metadata, {});

  service.memoryManager.recordIngestionJob(userId, {
    id: jobId,
    sourceType,
    providerKey: safeTrim(options.providerKey, 80),
    connectionId,
    status: 'running',
    metadata: jobMetadata,
    documentCount: 0,
  }, { agentId });

  const documentIds = [];
  try {
    for (const document of normalizedDocs) {
      throwIfAborted(signal, 'Memory ingestion aborted.');
      documentIds.push(service.memoryManager.upsertIngestionDocument(userId, document, { agentId }));
    }

    const { memoryIds = [] } = typeof service.extractFacts === 'function'
      ? await service.extractFacts(userId, agentId, {
        documents: normalizedDocs,
        owner: options.owner || { email: options.sourceAccount || null },
        metadata: { ingestionJobId: jobId },
        signal,
        onProgress: options.onProgress,
      })
      : {};

    throwIfAborted(signal, 'Memory ingestion aborted.');
    service.memoryManager.recordIngestionJob(userId, {
      id: jobId,
      sourceType,
      providerKey: safeTrim(options.providerKey, 80),
      connectionId,
      status: 'completed',
      summary: { documentIds, memoryIds },
      metadata: jobMetadata,
      documentCount: documentIds.length,
      completedAt: new Date().toISOString(),
    }, { agentId });

    const knowledgeViews = service.memoryManager.materializeKnowledgeViews(userId, { agentId });
    return {
      jobId,
      status: 'completed',
      documentIds,
      memoryIds,
      knowledgeViews,
    };
  } catch (err) {
    const cancelled = isAbortError(err, signal);
    service.memoryManager.recordIngestionJob(userId, {
      id: jobId,
      sourceType,
      providerKey: safeTrim(options.providerKey, 80),
      connectionId,
      status: cancelled ? 'cancelled' : 'failed',
      documentCount: documentIds.length,
      error: cancelled ? null : err.message,
      completedAt: new Date().toISOString(),
    }, { agentId });
    throw err;
  }
}

module.exports = { ingestDocuments };
