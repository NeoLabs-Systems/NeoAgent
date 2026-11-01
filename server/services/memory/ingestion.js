'use strict';

const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');
const { getErrorMessage } = require('../bootstrap_helpers');
const {
  createLinkedAbortController,
  isAbortError,
} = require('../../utils/abort');
const { ingestDocuments } = require('./ingestion_documents');
const {
  decorateProviderSnapshot,
  listConnectionStatuses,
} = require('./ingestion_coverage');
const {
  SOURCE_TYPES,
  normalizeSourceType,
  parseJsonObject,
  sourceTypesForConnection,
} = require('./ingestion_support');

// Progress events are sent at most this often while a phase is counting up.
const SWEEP_PROGRESS_INTERVAL_MS = 400;

// Integrations reach memory once: a sweep of past mail when an account is
// connected. Nothing polls connected accounts afterwards.
class MemoryIngestionService {
  constructor({
    memoryManager,
    integrationManager,
    extractFacts = null,
    io = null,
    database = db,
  } = {}) {
    this.memoryManager = memoryManager;
    this.integrationManager = integrationManager;
    this.extractFacts = extractFacts;
    this.io = io;
    this.db = database;
    // Live sweep state per connection id, shown in the app while it runs and
    // as the last result afterwards (until the server restarts).
    this.sweepProgress = new Map();
    this.sweepProgressEmittedAt = new Map();
    this.abortController = new AbortController();
    this.activeConnections = new Map();
    this.stopping = false;
    this.stopPromise = null;
    this.state = 'running';
    this.lastError = null;
  }

  getStatus() {
    return {
      state: this.state,
      activeSweepCount: this.activeConnections.size,
      lastError: this.lastError,
    };
  }

  async stop() {
    if (this.stopPromise) return this.stopPromise;
    this.stopping = true;
    this.state = 'stopping';
    this.abortController.abort('Memory ingestion service is stopping.');

    this.stopPromise = (async () => {
      while (this.activeConnections.size > 0) {
        await Promise.allSettled([...this.activeConnections.values()]);
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
    const linked = createLinkedAbortController([
      this.abortController.signal,
      options.signal,
    ]);
    try {
      return await ingestDocuments(this, userId, documents, {
        ...options,
        signal: linked.signal,
      });
    } finally {
      linked.cleanup();
    }
  }

  _saveCollectorCredentials(connection, collected) {
    if (collected?.credentials) {
      this.integrationManager?.saveRefreshedCredentials?.(connection, collected.credentials);
    }
  }

  getSweepProgress(connectionId) {
    return this.sweepProgress.get(Number(connectionId)) || null;
  }

  _reportSweep(connection, patch, { force = false } = {}) {
    const connectionId = Number(connection.id);
    const progress = {
      ...this.sweepProgress.get(connectionId),
      ...patch,
      updatedAt: new Date().toISOString(),
    };
    this.sweepProgress.set(connectionId, progress);
    const now = Date.now();
    if (!force && now - (this.sweepProgressEmittedAt.get(connectionId) || 0) < SWEEP_PROGRESS_INTERVAL_MS) {
      return;
    }
    this.sweepProgressEmittedAt.set(connectionId, now);
    this.io?.to?.(`user:${connection.user_id}`).emit('memory:sweep_progress', {
      connectionId,
      providerKey: connection.provider_key,
      appKey: connection.app_key,
      ...progress,
    });
  }

  // Runs the one-time sweep of past mail when the user left it switched on.
  handleConnected({ connection, memorySweep = false } = {}) {
    if (!connection || !memorySweep || this.abortController.signal.aborted) {
      return Promise.resolve(null);
    }
    return this.sweepConnection(connection);
  }

  // Sweeps every connected account of one app again on request, importing
  // only threads that are not in memory yet.
  sweepApp(userId, { agentId, providerKey, appKey }) {
    if (this.abortController.signal.aborted) return [];
    const connections = this.db.prepare(
      `SELECT *
       FROM integration_connections
       WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND app_key = ? AND status = 'connected'`,
    ).all(userId, agentId, providerKey, appKey);
    for (const connection of connections) {
      void this.sweepConnection(connection, { repeat: true });
    }
    return connections.map((connection) => connection.id);
  }

  sweepConnection(connection, { repeat = false } = {}) {
    const sweepKey = `sweep:${connection.user_id}:${connection.id}`;
    const active = this.activeConnections.get(sweepKey);
    if (active) return active;

    const promise = this._sweepConnection(connection, { repeat })
      .catch((err) => {
        if (isAbortError(err, this.abortController.signal) && this.stopping) {
          this.sweepProgress.delete(Number(connection.id));
          return { connectionId: connection.id, status: 'cancelled' };
        }
        const error = getErrorMessage(err);
        this.lastError = error;
        this._reportSweep(connection, {
          state: 'failed',
          error,
          finishedAt: new Date().toISOString(),
        }, { force: true });
        console.warn(`[MemoryIngestion] Connection ${connection.id} sweep failed:`, error);
        return { connectionId: connection.id, status: 'failed', error };
      })
      .finally(() => {
        if (this.activeConnections.get(sweepKey) === promise) {
          this.activeConnections.delete(sweepKey);
        }
      });
    this.activeConnections.set(sweepKey, promise);
    return promise;
  }

  async _sweepConnection(connection, { repeat }) {
    const signal = this.abortController.signal;
    const sourceTypes = sourceTypesForConnection(connection.provider_key, connection.app_key);
    const provider = this.integrationManager?.getProvider?.(connection.provider_key);
    if (!sourceTypes.includes('email') || typeof provider?.collectMemorySweep !== 'function') {
      return { connectionId: connection.id, status: 'not_supported' };
    }
    const agentId = connection.agent_id || resolveAgentId(connection.user_id, null);
    const alreadySwept = !repeat && this.memoryManager
      .listIngestionJobs(connection.user_id, {
        agentId,
        providerKey: connection.provider_key,
        limit: 100,
      })
      .some((job) => Number(job.connectionId || 0) === Number(connection.id)
        && job.status === 'completed'
        && job.metadata?.mode === 'sweep');
    if (alreadySwept) return { connectionId: connection.id, status: 'already_swept' };

    const startedAt = new Date().toISOString();
    this.sweepProgress.delete(Number(connection.id));
    this._reportSweep(connection, {
      state: 'running',
      phase: 'reading',
      done: 0,
      total: null,
      imported: 0,
      learned: 0,
      startedAt,
      finishedAt: null,
      error: null,
    }, { force: true });
    const collected = await provider.collectMemorySweep({
      connection,
      sourceTypes,
      skipObjectIds: this.memoryManager.listIngestedObjectIds(connection.user_id, connection.id, {
        agentId,
      }),
      onProgress: (done, total = null) => this._reportSweep(connection, { done, total }),
      signal,
    });
    this._saveCollectorCredentials(connection, collected);
    const documents = collected.documents || [];
    this._reportSweep(connection, {
      phase: 'learning',
      done: 0,
      total: documents.length,
    }, { force: true });
    const connectionMetadata = parseJsonObject(connection.metadata_json, {});
    const result = await this.ingestDocuments(connection.user_id, documents, {
      agentId,
      sourceType: 'email',
      providerKey: connection.provider_key,
      connectionId: connection.id,
      sourceAccount: connection.account_email,
      owner: {
        email: connection.account_email || null,
        name: connectionMetadata.displayName || null,
      },
      metadata: {
        appKey: connection.app_key,
        sourceTypes,
        mode: 'sweep',
        cursor: collected.cursor || null,
      },
      onProgress: (done, total) => this._reportSweep(connection, { done, total }),
      signal,
    });
    this._reportSweep(connection, {
      state: 'completed',
      imported: documents.length,
      learned: this.memoryManager.countMemoriesCreatedSince(result.memoryIds, startedAt),
      finishedAt: new Date().toISOString(),
    }, { force: true });
    return result;
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
  normalizeSourceType,
  sourceTypesForConnection,
};
