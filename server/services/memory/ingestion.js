'use strict';

const { v4: uuidv4 } = require('uuid');
const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');
const { compactTextPayload } = require('../ai/preModelCompaction');

const SOURCE_TYPES = Object.freeze([
  'email',
  'calendar',
  'chat',
  'docs',
  'tickets',
  'repos',
  'files',
  'crm',
  'payments',
  'notes',
]);

const FRESHNESS_POLICIES = Object.freeze({
  email: Object.freeze({ intervalMinutes: 60, staleAfterDays: 14 }),
  calendar: Object.freeze({ intervalMinutes: 180, staleAfterDays: 30 }),
  chat: Object.freeze({ intervalMinutes: 60, staleAfterDays: 14 }),
  docs: Object.freeze({ intervalMinutes: 360, staleAfterDays: 60 }),
  tickets: Object.freeze({ intervalMinutes: 120, staleAfterDays: 30 }),
  repos: Object.freeze({ intervalMinutes: 180, staleAfterDays: 45 }),
  files: Object.freeze({ intervalMinutes: 360, staleAfterDays: 60 }),
  crm: Object.freeze({ intervalMinutes: 240, staleAfterDays: 45 }),
  payments: Object.freeze({ intervalMinutes: 360, staleAfterDays: 90 }),
  notes: Object.freeze({ intervalMinutes: 360, staleAfterDays: 90 }),
});

const SOURCE_MEMORY_CATEGORIES = Object.freeze({
  email: 'episodic',
  calendar: 'events',
  chat: 'episodic',
  docs: 'projects',
  tickets: 'tasks',
  repos: 'projects',
  files: 'episodic',
  crm: 'contacts',
  payments: 'events',
  notes: 'episodic',
});

const INTEGRATION_SOURCE_TYPES = Object.freeze({
  google_workspace: Object.freeze({
    gmail: Object.freeze(['email']),
    calendar: Object.freeze(['calendar']),
    drive: Object.freeze(['files']),
    docs: Object.freeze(['docs']),
    sheets: Object.freeze(['docs', 'files']),
  }),
  microsoft_365: Object.freeze({
    outlook: Object.freeze(['email']),
    calendar: Object.freeze(['calendar']),
    onedrive: Object.freeze(['files']),
    teams: Object.freeze(['chat']),
  }),
  github: Object.freeze({
    repos: Object.freeze(['repos', 'tickets']),
  }),
  slack: Object.freeze({
    slack: Object.freeze(['chat']),
  }),
  whatsapp: Object.freeze({
    personal: Object.freeze(['chat']),
  }),
  notion: Object.freeze({
    notion: Object.freeze(['notes', 'docs']),
  }),
  trello: Object.freeze({
    trello: Object.freeze(['tickets']),
  }),
});

function safeTrim(value, maxLength = 240) {
  return String(value || '').trim().slice(0, maxLength);
}

function parseJsonObject(value, fallback = {}) {
  if (!value) return { ...fallback };
  if (typeof value === 'object' && !Array.isArray(value)) return { ...value };
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : { ...fallback };
  } catch {
    return { ...fallback };
  }
}

function normalizeSourceType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return SOURCE_TYPES.includes(normalized) ? normalized : 'notes';
}

function getFreshnessPolicy(sourceType) {
  const normalized = normalizeSourceType(sourceType);
  return { ...FRESHNESS_POLICIES[normalized] };
}

function nextSyncFromPolicy(policy, now = Date.now()) {
  const intervalMinutes = Math.max(15, Number(policy?.intervalMinutes) || 360);
  return new Date(now + intervalMinutes * 60 * 1000).toISOString();
}

function normalizeDocument(raw = {}, defaults = {}) {
  const sourceType = normalizeSourceType(raw.sourceType || defaults.sourceType);
  const externalObjectId = safeTrim(raw.externalObjectId || raw.id || raw.sourceId, 180);
  const contentSource = raw.content ?? raw.text ?? raw.body ?? '';
  const content = safeTrim(contentSource, 12000);
  if (!externalObjectId || !content) {
    throw new Error('Normalized memory documents require externalObjectId and content.');
  }
  const compacted = compactTextPayload(content, { maxChars: 2400, maxLines: 50 });
  return {
    sourceType,
    normalizedType: normalizeSourceType(raw.normalizedType || raw.memoryType || sourceType),
    providerKey: safeTrim(raw.providerKey || defaults.providerKey, 80),
    connectionId: Number.isInteger(Number(raw.connectionId ?? defaults.connectionId))
      ? Number(raw.connectionId ?? defaults.connectionId)
      : 0,
    externalObjectId,
    sourceAccount: safeTrim(raw.sourceAccount || defaults.sourceAccount, 180),
    title: safeTrim(raw.title || raw.subject || raw.name || externalObjectId, 220),
    content,
    summary: safeTrim(raw.summary || compacted.text, 1200),
    salience: Math.max(1, Math.min(10, Number(raw.salience) || 5)),
    sourceTimestamp: safeTrim(raw.sourceTimestamp || raw.updatedAt || raw.createdAt, 80) || null,
    metadata: {
      ...parseJsonObject(raw.metadata, {}),
      compaction: compacted.metrics,
    },
    payload: parseJsonObject(raw.payload, {}),
  };
}

function sourceTypesForConnection(providerKey, appKey) {
  const providerMap = INTEGRATION_SOURCE_TYPES[String(providerKey || '').trim()] || {};
  return Array.from(providerMap[String(appKey || '').trim()] || []);
}

function buildCoverageForConnection(connection, latestJob = null) {
  const dataDomains = sourceTypesForConnection(connection.provider_key, connection.app_key);
  const supported = dataDomains.length > 0;
  return {
    supported,
    contributesToMemory: supported,
    contributesToTaskExecution: String(connection.status || '') === 'connected',
    status: latestJob?.status || (supported ? 'ready' : 'not_supported'),
    dataDomains,
    lastRefreshAt: latestJob?.completedAt || latestJob?.updatedAt || null,
    nextRefreshAt: latestJob?.nextSyncAt || null,
    documentCount: Number(latestJob?.documentCount || 0),
    error: latestJob?.error || null,
  };
}

class MemoryIngestionService {
  constructor({ memoryManager, integrationManager, intervalMs = 10 * 60 * 1000 } = {}) {
    this.memoryManager = memoryManager;
    this.integrationManager = integrationManager;
    this.intervalMs = intervalMs;
    this.timer = null;
    this.running = false;
  }

  start() {
    if (this.timer) return;
    this.timer = setInterval(() => {
      this.refreshDueConnections().catch((err) => {
        console.warn('[MemoryIngestion] Background refresh failed:', err.message);
      });
    }, this.intervalMs);
    this.timer.unref?.();
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  getFreshnessPolicy(sourceType) {
    return getFreshnessPolicy(sourceType);
  }

  async ingestDocuments(userId, documents = [], options = {}) {
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

    this.memoryManager.recordIngestionJob(userId, {
      id: jobId,
      sourceType,
      providerKey: safeTrim(options.providerKey, 80),
      connectionId: Number.isInteger(Number(options.connectionId)) ? Number(options.connectionId) : 0,
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
        const documentId = this.memoryManager.upsertIngestionDocument(userId, document, { agentId });
        documentIds.push(documentId);
        const memoryId = await this.memoryManager.saveMemory(
          userId,
          `${document.title}: ${document.summary || document.content}`,
          SOURCE_MEMORY_CATEGORIES[document.normalizedType] || SOURCE_MEMORY_CATEGORIES[document.sourceType] || 'episodic',
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

      this.memoryManager.recordIngestionJob(userId, {
        id: jobId,
        sourceType,
        providerKey: safeTrim(options.providerKey, 80),
        connectionId: Number.isInteger(Number(options.connectionId)) ? Number(options.connectionId) : 0,
        status: 'completed',
        freshnessPolicy: policy,
        summary: { documentIds, memoryIds },
        metadata: parseJsonObject(options.metadata, {}),
        documentCount: documentIds.length,
        completedAt: new Date().toISOString(),
        nextSyncAt: nextSyncFromPolicy(policy),
      }, { agentId });

      const knowledgeViews = this.memoryManager.materializeKnowledgeViews(userId, { agentId });
      return {
        jobId,
        status: 'completed',
        documentIds,
        memoryIds,
        knowledgeViews,
      };
    } catch (err) {
      this.memoryManager.recordIngestionJob(userId, {
        id: jobId,
        sourceType,
        providerKey: safeTrim(options.providerKey, 80),
        connectionId: Number.isInteger(Number(options.connectionId)) ? Number(options.connectionId) : 0,
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

  async refreshDueConnections(userId = null) {
    if (this.running) return { skipped: true };
    this.running = true;
    try {
      const params = [];
      let sql = `SELECT *
                 FROM integration_connections
                 WHERE status = 'connected'`;
      if (userId != null) {
        sql += ' AND user_id = ?';
        params.push(userId);
      }
      const connections = db.prepare(sql).all(...params);
      const results = [];
      for (const connection of connections) {
        results.push(await this.refreshConnection(connection));
      }
      return { refreshed: results.length, results };
    } finally {
      this.running = false;
    }
  }

  async refreshConnection(connection) {
    const sourceTypes = sourceTypesForConnection(connection.provider_key, connection.app_key);
    if (sourceTypes.length === 0) {
      return { connectionId: connection.id, status: 'not_supported' };
    }
    const provider = this.integrationManager?.getProvider?.(connection.provider_key);
    const agentId = connection.agent_id || resolveAgentId(connection.user_id, null);
    const primarySource = sourceTypes[0];
    const policy = getFreshnessPolicy(primarySource);
    const latestJob = this.memoryManager
      .listIngestionJobs(connection.user_id, {
        agentId,
        providerKey: connection.provider_key,
        limit: 1,
      })
      .find((job) => Number(job.connectionId || 0) === Number(connection.id));

    if (latestJob?.nextSyncAt && Date.parse(latestJob.nextSyncAt) > Date.now()) {
      return { connectionId: connection.id, status: 'fresh' };
    }

    if (typeof provider?.collectMemoryDocuments === 'function') {
      const collected = await provider.collectMemoryDocuments({
        connection,
        sourceTypes,
        cursor: latestJob?.cursor || {},
      });
      return this.ingestDocuments(connection.user_id, collected.documents || [], {
        agentId,
        sourceType: primarySource,
        providerKey: connection.provider_key,
        connectionId: connection.id,
        sourceAccount: connection.account_email,
        metadata: {
          appKey: connection.app_key,
          sourceTypes,
          cursor: collected.cursor || null,
        },
      });
    }

    const jobId = this.memoryManager.recordIngestionJob(connection.user_id, {
      id: uuidv4(),
      sourceType: primarySource,
      providerKey: connection.provider_key,
      connectionId: connection.id,
      status: 'ready',
      freshnessPolicy: policy,
      summary: {
        appKey: connection.app_key,
        sourceTypes,
        collectorAvailable: false,
      },
      metadata: {
        accountEmail: connection.account_email || null,
      },
      documentCount: 0,
      completedAt: new Date().toISOString(),
      nextSyncAt: nextSyncFromPolicy(policy),
    }, { agentId });
    return { connectionId: connection.id, status: 'ready', jobId };
  }

  listConnectionStatuses(userId, { agentId = null } = {}) {
    const scopedAgentId = resolveAgentId(userId, agentId);
    const connections = db.prepare(
      `SELECT *
       FROM integration_connections
       WHERE user_id = ? AND agent_id = ?
       ORDER BY updated_at DESC, id DESC`,
    ).all(userId, scopedAgentId);
    const jobs = this.memoryManager.listIngestionJobs(userId, { agentId: scopedAgentId, limit: 100 });
    return connections.map((connection) => {
      const latestJob = jobs.find((job) => Number(job.connectionId || 0) === Number(connection.id));
      return {
        connectionId: connection.id,
        providerKey: connection.provider_key,
        appKey: connection.app_key,
        accountEmail: connection.account_email || null,
        ...buildCoverageForConnection(connection, latestJob),
      };
    });
  }

  decorateProviderSnapshot(snapshot, userId, agentId = null) {
    if (!snapshot || typeof snapshot !== 'object') return snapshot;
    const scopedAgentId = resolveAgentId(userId, agentId);
    const connections = db.prepare(
      `SELECT *
       FROM integration_connections
       WHERE user_id = ? AND agent_id = ? AND provider_key = ?`,
    ).all(userId, scopedAgentId, snapshot.provider);
    const jobs = this.memoryManager.listIngestionJobs(userId, {
      agentId: scopedAgentId,
      providerKey: snapshot.provider,
      limit: 100,
    });
    const latestJobForConnection = (connectionId) =>
      jobs.find((job) => Number(job.connectionId || 0) === Number(connectionId));

    const connectionCoverage = connections.map((connection) => ({
      connectionId: connection.id,
      appKey: connection.app_key,
      accountEmail: connection.account_email || null,
      ...buildCoverageForConnection(connection, latestJobForConnection(connection.id)),
    }));
    const providerDomains = Array.from(new Set(connectionCoverage.flatMap((item) => item.dataDomains || [])));
    const providerJob = jobs[0] || null;
    const decorated = {
      ...snapshot,
      memoryCoverage: {
        supported: providerDomains.length > 0,
        contributesToMemory: providerDomains.length > 0,
        contributesToTaskExecution: Boolean(snapshot.connection?.connected),
        status: providerJob?.status || (providerDomains.length > 0 ? 'ready' : 'not_supported'),
        dataDomains: providerDomains,
        documentCount: connectionCoverage.reduce((sum, item) => sum + Number(item.documentCount || 0), 0),
        lastRefreshAt: providerJob?.completedAt || providerJob?.updatedAt || null,
        nextRefreshAt: providerJob?.nextSyncAt || null,
        error: providerJob?.error || null,
      },
    };

    decorated.apps = (snapshot.apps || []).map((app) => {
      const appConnections = connectionCoverage.filter((item) => item.appKey === app.id);
      const dataDomains = Array.from(new Set([
        ...sourceTypesForConnection(snapshot.provider, app.id),
        ...appConnections.flatMap((item) => item.dataDomains || []),
      ]));
      const latest = appConnections[0] || null;
      return {
        ...app,
        memoryCoverage: {
          supported: dataDomains.length > 0,
          contributesToMemory: dataDomains.length > 0 && app.connection?.connected === true,
          contributesToTaskExecution: app.connection?.connected === true,
          status: latest?.status || (dataDomains.length > 0 ? 'ready' : 'not_supported'),
          dataDomains,
          documentCount: appConnections.reduce((sum, item) => sum + Number(item.documentCount || 0), 0),
          lastRefreshAt: latest?.lastRefreshAt || null,
          nextRefreshAt: latest?.nextRefreshAt || null,
          error: latest?.error || null,
        },
        accounts: (app.accounts || []).map((account) => {
          const accountCoverage = appConnections.find((item) =>
            Number(item.connectionId) === Number(account.connectionId),
          );
          return {
            ...account,
            memoryCoverage: accountCoverage || {
              supported: dataDomains.length > 0,
              contributesToMemory: false,
              contributesToTaskExecution: app.connection?.connected === true,
              status: dataDomains.length > 0 ? 'ready' : 'not_supported',
              dataDomains,
              documentCount: 0,
              lastRefreshAt: null,
              nextRefreshAt: null,
              error: null,
            },
          };
        }),
      };
    });
    return decorated;
  }
}

module.exports = {
  MemoryIngestionService,
  SOURCE_TYPES,
  FRESHNESS_POLICIES,
  normalizeSourceType,
  sourceTypesForConnection,
};
