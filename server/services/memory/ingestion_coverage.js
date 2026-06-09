'use strict';

const { resolveAgentId } = require('../agents/manager');
const {
  buildCoverageForConnection,
  sourceTypesForConnection,
} = require('./ingestion_support');

function listConnectionStatuses(service, userId, { agentId = null } = {}) {
  const scopedAgentId = resolveAgentId(userId, agentId);
  const connections = service.db.prepare(
    `SELECT *
     FROM integration_connections
     WHERE user_id = ? AND agent_id = ?
     ORDER BY updated_at DESC, id DESC`,
  ).all(userId, scopedAgentId);
  const jobs = service.memoryManager.listIngestionJobs(
    userId,
    { agentId: scopedAgentId, limit: 100 },
  );
  return connections.map((connection) => {
    const latestJob = jobs.find(
      (job) => Number(job.connectionId || 0) === Number(connection.id),
    );
    return {
      connectionId: connection.id,
      providerKey: connection.provider_key,
      appKey: connection.app_key,
      accountEmail: connection.account_email || null,
      ...buildCoverageForConnection(connection, latestJob),
    };
  });
}

function decorateProviderSnapshot(service, snapshot, userId, agentId = null) {
  if (!snapshot || typeof snapshot !== 'object') return snapshot;
  const scopedAgentId = resolveAgentId(userId, agentId);
  const connections = service.db.prepare(
    `SELECT *
     FROM integration_connections
     WHERE user_id = ? AND agent_id = ? AND provider_key = ?`,
  ).all(userId, scopedAgentId, snapshot.provider);
  const jobs = service.memoryManager.listIngestionJobs(userId, {
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
  const providerDomains = Array.from(
    new Set(connectionCoverage.flatMap((item) => item.dataDomains || [])),
  );
  const providerJob = jobs[0] || null;
  const decorated = {
    ...snapshot,
    memoryCoverage: {
      supported: providerDomains.length > 0,
      contributesToMemory: providerDomains.length > 0,
      contributesToTaskExecution: Boolean(snapshot.connection?.connected),
      status: providerJob?.status || (providerDomains.length > 0 ? 'ready' : 'not_supported'),
      dataDomains: providerDomains,
      documentCount: connectionCoverage.reduce(
        (sum, item) => sum + Number(item.documentCount || 0),
        0,
      ),
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
        documentCount: appConnections.reduce(
          (sum, item) => sum + Number(item.documentCount || 0),
          0,
        ),
        lastRefreshAt: latest?.lastRefreshAt || null,
        nextRefreshAt: latest?.nextRefreshAt || null,
        error: latest?.error || null,
      },
      accounts: (app.accounts || []).map((account) => {
        const accountCoverage = appConnections.find(
          (item) => Number(item.connectionId) === Number(account.connectionId),
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

module.exports = {
  decorateProviderSnapshot,
  listConnectionStatuses,
};
