'use strict';

const { v4: uuidv4 } = require('uuid');
const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');
const { getErrorMessage } = require('../bootstrap_helpers');
const { ingestDocuments } = require('./ingestion_documents');
const {
  decorateProviderSnapshot,
  listConnectionStatuses,
} = require('./ingestion_coverage');
const {
  FRESHNESS_POLICIES,
  SOURCE_TYPES,
  getFreshnessPolicy,
  nextSyncFromPolicy,
  normalizeSourceType,
  sourceTypesForConnection,
} = require('./ingestion_support');

const DEFAULT_REFRESH_INTERVAL_MS = 10 * 60 * 1000;

class MemoryIngestionService {
  constructor({
    memoryManager,
    integrationManager,
    intervalMs = DEFAULT_REFRESH_INTERVAL_MS,
    database = db,
    setIntervalFn = setInterval,
    clearIntervalFn = clearInterval,
  } = {}) {
    this.memoryManager = memoryManager;
    this.integrationManager = integrationManager;
    this.intervalMs = Number(intervalMs);
    if (!Number.isSafeInteger(this.intervalMs) || this.intervalMs < 1000) {
      throw new Error('Memory ingestion intervalMs must be an integer greater than or equal to 1000.');
    }
    this.db = database;
    this.setInterval = setIntervalFn;
    this.clearInterval = clearIntervalFn;
    this.timer = null;
    this.activeBatches = new Map();
    this.activeConnections = new Map();
    this.stopping = false;
    this.stopPromise = null;
    this.state = 'idle';
    this.lastRunAt = null;
    this.lastCompletedAt = null;
    this.lastError = null;
  }

  getStatus() {
    return {
      state: this.state,
      intervalMs: this.intervalMs,
      activeBatchCount: this.activeBatches.size,
      activeConnectionCount: this.activeConnections.size,
      lastRunAt: this.lastRunAt,
      lastCompletedAt: this.lastCompletedAt,
      lastError: this.lastError,
    };
  }

  start() {
    if (this.timer) return this.getStatus();
    if (this.stopPromise) {
      throw new Error('Memory ingestion cannot start while shutdown is in progress.');
    }

    this.stopping = false;
    this.state = 'running';
    this.lastError = null;
    this.timer = this.setInterval(() => {
      void this._runBackgroundRefresh();
    }, this.intervalMs);
    this.timer.unref?.();
    void this._runBackgroundRefresh();
    return this.getStatus();
  }

  async _runBackgroundRefresh() {
    try {
      await this.refreshDueConnections();
    } catch (err) {
      this.lastError = getErrorMessage(err);
      console.warn('[MemoryIngestion] Background refresh failed:', this.lastError);
    }
  }

  async stop() {
    if (this.stopPromise) return this.stopPromise;
    this.stopping = true;
    this.state = 'stopping';
    if (this.timer) this.clearInterval(this.timer);
    this.timer = null;

    this.stopPromise = (async () => {
      while (this.activeBatches.size > 0 || this.activeConnections.size > 0) {
        await Promise.allSettled([
          ...this.activeBatches.values(),
          ...this.activeConnections.values(),
        ]);
      }
      this.stopping = false;
      this.state = 'stopped';
      return this.getStatus();
    })().finally(() => {
      this.stopPromise = null;
    });
    return this.stopPromise;
  }

  async ingestDocuments(userId, documents = [], options = {}) {
    return ingestDocuments(this, userId, documents, options);
  }

  refreshDueConnections(userId = null) {
    const scopeKey = userId == null ? 'all' : `user:${userId}`;
    if (this.stopping) {
      return Promise.resolve({ skipped: true, reason: 'service_stopping' });
    }
    const active = this.activeBatches.get(scopeKey);
    if (active) return active;

    const promise = this._refreshDueConnections(userId).finally(() => {
      if (this.activeBatches.get(scopeKey) === promise) {
        this.activeBatches.delete(scopeKey);
      }
    });
    this.activeBatches.set(scopeKey, promise);
    return promise;
  }

  async _refreshDueConnections(userId = null) {
    this.lastRunAt = new Date().toISOString();
    try {
      const params = [];
      let sql = `SELECT *
                 FROM integration_connections
                 WHERE status = 'connected'`;
      if (userId != null) {
        sql += ' AND user_id = ?';
        params.push(userId);
      }
      const connections = this.db.prepare(sql).all(...params);
      const results = [];
      for (const connection of connections) {
        if (this.stopping) break;
        results.push(await this._refreshConnectionSafely(connection));
      }
      if (!results.some((result) => result?.status === 'failed')) {
        this.lastError = null;
      }
      this.lastCompletedAt = new Date().toISOString();
      return { refreshed: results.length, results };
    } catch (err) {
      this.lastError = getErrorMessage(err);
      throw err;
    }
  }

  _refreshConnectionSafely(connection) {
    const connectionKey = `${connection.user_id}:${connection.id}`;
    const active = this.activeConnections.get(connectionKey);
    if (active) return active;

    const promise = Promise.resolve()
      .then(() => this.refreshConnection(connection))
      .catch((err) => {
        const error = getErrorMessage(err);
        this.lastError = error;
        console.warn(
          `[MemoryIngestion] Connection ${connection.id} refresh failed:`,
          error,
        );
        return {
          connectionId: connection.id,
          status: 'failed',
          error,
        };
      })
      .finally(() => {
        if (this.activeConnections.get(connectionKey) === promise) {
          this.activeConnections.delete(connectionKey);
        }
      });
    this.activeConnections.set(connectionKey, promise);
    return promise;
  }

  _recordCollectorFailure(connection, sourceType, policy, agentId, err) {
    try {
      this.memoryManager.recordIngestionJob(connection.user_id, {
        id: uuidv4(),
        sourceType,
        providerKey: connection.provider_key,
        connectionId: connection.id,
        status: 'failed',
        freshnessPolicy: policy,
        documentCount: 0,
        error: getErrorMessage(err),
        completedAt: new Date().toISOString(),
        nextSyncAt: nextSyncFromPolicy(policy),
        metadata: {
          appKey: connection.app_key,
          sourceTypes: sourceTypesForConnection(connection.provider_key, connection.app_key),
        },
      }, { agentId });
    } catch (recordError) {
      console.warn(
        `[MemoryIngestion] Could not persist failure for connection ${connection.id}:`,
        getErrorMessage(recordError),
      );
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
      let collected;
      try {
        collected = await provider.collectMemoryDocuments({
          connection,
          sourceTypes,
          cursor: latestJob?.cursor || {},
        });
      } catch (err) {
        this._recordCollectorFailure(connection, primarySource, policy, agentId, err);
        throw err;
      }
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
    return listConnectionStatuses(this, userId, { agentId });
  }

  decorateProviderSnapshot(snapshot, userId, agentId = null) {
    return decorateProviderSnapshot(this, snapshot, userId, agentId);
  }
}

module.exports = {
  MemoryIngestionService,
  SOURCE_TYPES,
  FRESHNESS_POLICIES,
  normalizeSourceType,
  sourceTypesForConnection,
};
