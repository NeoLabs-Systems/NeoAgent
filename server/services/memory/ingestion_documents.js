'use strict';

const { v4: uuidv4 } = require('uuid');
const { resolveAgentId } = require('../agents/manager');
const {
  SOURCE_MEMORY_CATEGORIES,
  getFreshnessPolicy,
  nextSyncFromPolicy,
  normalizeDocument,
  normalizeSourceType,
  parseJsonObject,
  safeTrim,
} = require('./ingestion_support');

async function ingestDocuments(service, userId, documents = [], options = {}) {
  const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
  const normalizedDocs = (Array.isArray(documents) ? documents : [])
    .map((document) => normalizeDocument(document, {
      sourceType: options.sourceType,
      providerKey: options.providerKey,
      connectionId: options.connectionId,
      sourceAccount: options.sourceAccount,
    }));
  const sourceType = normalizeSourceType(options.sourceType || normalizedDocs[0]?.sourceType);
  const policy = getFreshnessPolicy(sourceType);
  const jobId = uuidv4();
  const connectionId = Number.isInteger(Number(options.connectionId))
    ? Number(options.connectionId)
    : 0;

  service.memoryManager.recordIngestionJob(userId, {
    id: jobId,
    sourceType,
    providerKey: safeTrim(options.providerKey, 80),
    connectionId,
    status: 'running',
    freshnessPolicy: policy,
    metadata: parseJsonObject(options.metadata, {}),
    documentCount: 0,
    nextSyncAt: nextSyncFromPolicy(policy),
  }, { agentId });

  const documentIds = [];
  const memoryIds = [];
  try {
    for (const document of normalizedDocs) {
      const documentId = service.memoryManager.upsertIngestionDocument(
        userId,
        document,
        { agentId },
      );
      documentIds.push(documentId);
      const memoryId = await service.memoryManager.saveMemory(
        userId,
        `${document.title}: ${document.summary || document.content}`,
        SOURCE_MEMORY_CATEGORIES[document.normalizedType]
          || SOURCE_MEMORY_CATEGORIES[document.sourceType]
          || 'episodic',
        document.salience,
        {
          agentId,
          staleAfterDays: getFreshnessPolicy(document.sourceType).staleAfterDays,
          sourceRef: {
            sourceType: 'memory_ingestion',
            sourceId: document.externalObjectId,
            sourceLabel: document.title,
          },
          scope: {
            scopeType: 'agent',
            scopeId: agentId,
          },
          metadata: {
            ingestionJobId: jobId,
            ingestionDocumentId: documentId,
            providerKey: document.providerKey || null,
            connectionId: document.connectionId || null,
            sourceType: document.sourceType,
          },
        },
      );
      if (memoryId) memoryIds.push(memoryId);
    }

    service.memoryManager.recordIngestionJob(userId, {
      id: jobId,
      sourceType,
      providerKey: safeTrim(options.providerKey, 80),
      connectionId,
      status: 'completed',
      freshnessPolicy: policy,
      summary: { documentIds, memoryIds },
      metadata: parseJsonObject(options.metadata, {}),
      documentCount: documentIds.length,
      completedAt: new Date().toISOString(),
      nextSyncAt: nextSyncFromPolicy(policy),
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
    service.memoryManager.recordIngestionJob(userId, {
      id: jobId,
      sourceType,
      providerKey: safeTrim(options.providerKey, 80),
      connectionId,
      status: 'failed',
      freshnessPolicy: policy,
      documentCount: documentIds.length,
      error: err.message,
      completedAt: new Date().toISOString(),
      nextSyncAt: nextSyncFromPolicy(policy),
    }, { agentId });
    throw err;
  }
}

module.exports = { ingestDocuments };
