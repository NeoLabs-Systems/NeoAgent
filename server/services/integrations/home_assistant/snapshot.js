'use strict';

const { getConnectionAccessMode } = require('../access');
const {
  HOME_ASSISTANT_APP,
  HOME_ASSISTANT_TOOL_DEFINITIONS,
} = require('./constants');

function summarizeAccountRow(row, envStatus) {
  if (!envStatus.configured) {
    return {
      id: row?.id || null,
      status: 'env_not_configured',
      connected: false,
      accountEmail: row?.account_email || null,
      lastConnectedAt: row?.last_connected_at || null,
      accessMode: 'read_write',
    };
  }

  if (!row) {
    return {
      id: null,
      status: 'not_connected',
      connected: false,
      accountEmail: null,
      lastConnectedAt: null,
      accessMode: 'read_write',
    };
  }

  return {
    id: row.id || null,
    status: row.status || 'not_connected',
    connected: row.status === 'connected',
    accountEmail: row.account_email || null,
    lastConnectedAt: row.last_connected_at || null,
    accessMode: getConnectionAccessMode(row),
  };
}

function summarizeAppConnection(app, connectionRows, envStatus) {
  const accounts = (Array.isArray(connectionRows) ? connectionRows : [])
    .slice()
    .sort((left, right) => String(right.updated_at || '').localeCompare(String(left.updated_at || '')))
    .map((row) => summarizeAccountRow(row, envStatus));
  const connectedAccounts = accounts.filter((account) => account.connected);
  return {
    id: app.id,
    label: app.label,
    description: app.description,
    accounts,
    connection: {
      status: !envStatus.configured ? 'env_not_configured' : connectedAccounts.length > 0 ? 'connected' : 'not_connected',
      connected: connectedAccounts.length > 0,
      accountCount: connectedAccounts.length,
      accountEmail: connectedAccounts.length === 1 ? connectedAccounts[0].accountEmail : null,
      lastConnectedAt: connectedAccounts.map((account) => account.lastConnectedAt).filter(Boolean).sort().reverse()[0] || null,
    },
    availableToolCount: envStatus.configured && connectedAccounts.length > 0 ? HOME_ASSISTANT_TOOL_DEFINITIONS.length : 0,
  };
}

function buildHomeAssistantSnapshot(provider, connectionRows, context = {}) {
  const env = provider.getEnvStatus(context);
  const byApp = new Map();
  for (const row of Array.isArray(connectionRows) ? connectionRows : []) {
    const appId = String(row.app_key || '').trim();
    if (!byApp.has(appId)) byApp.set(appId, []);
    byApp.get(appId).push(row);
  }
  const appSnapshots = [HOME_ASSISTANT_APP].map((app) => summarizeAppConnection(app, byApp.get(app.id) || [], env));
  const connectedAccounts = appSnapshots.flatMap((app) => app.accounts.filter((account) => account.connected));
  return {
    id: provider.key,
    label: provider.label,
    description: provider.description,
    icon: provider.icon,
    apps: appSnapshots,
    env,
    connection: {
      status: !env.configured ? 'env_not_configured' : connectedAccounts.length > 0 ? 'connected' : 'not_connected',
      connected: connectedAccounts.length > 0,
      accountEmail: connectedAccounts.length === 1 ? connectedAccounts[0].accountEmail : null,
      accountCount: connectedAccounts.length,
      appCount: appSnapshots.filter((app) => app.connection.connected).length,
      lastConnectedAt: connectedAccounts.map((account) => account.lastConnectedAt).filter(Boolean).sort().reverse()[0] || null,
    },
    availableToolCount: appSnapshots.reduce((total, app) => total + app.availableToolCount, 0),
    connectPrompt: provider.connectPrompt,
    supportsMultipleAccounts: provider.supportsMultipleAccounts,
    connectionMethod: provider.connectionMethod,
  };
}

module.exports = {
  buildHomeAssistantSnapshot,
};
