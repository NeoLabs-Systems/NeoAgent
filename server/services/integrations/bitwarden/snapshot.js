'use strict';

const { getConnectionAccessMode } = require('../access');
const { BITWARDEN_APP } = require('./constants');

function summarizeAccount(row, env) {
  if (!row) {
    return {
      id: null,
      status: env.configured ? 'not_connected' : 'env_not_configured',
      connected: false,
      accountEmail: null,
      lastConnectedAt: null,
      accessMode: 'read_write',
    };
  }
  return {
    id: row.id,
    status: row.status,
    connected: row.status === 'connected',
    accountEmail: row.account_email || null,
    lastConnectedAt: row.last_connected_at || null,
    accessMode: getConnectionAccessMode(row),
  };
}

function buildBitwardenSnapshot(provider, connectionRows, context = {}) {
  const env = provider.getEnvStatus(context);
  const row = (Array.isArray(connectionRows) ? connectionRows : [])
    .filter((candidate) => candidate.app_key === BITWARDEN_APP.id)
    .sort((left, right) => String(right.updated_at || '').localeCompare(String(left.updated_at || '')))[0] || null;
  const account = summarizeAccount(row, env);
  const accounts = row ? [account] : [];
  const connection = {
    status: !env.configured ? 'env_not_configured' : account.status,
    connected: account.connected,
    accountEmail: account.accountEmail,
    accountCount: account.connected ? 1 : 0,
    appCount: account.connected ? 1 : 0,
    lastConnectedAt: account.lastConnectedAt,
  };
  return {
    id: provider.key,
    label: provider.label,
    description: provider.description,
    icon: provider.icon,
    apps: [{
      ...BITWARDEN_APP,
      accounts,
      connection,
      availableToolCount: account.connected ? 2 : 0,
    }],
    env,
    connection,
    availableToolCount: account.connected ? 2 : 0,
    credentialBindingsSummary: context.credentialBindingsSummary || 'No credential bindings are configured.',
    connectPrompt: provider.connectPrompt,
    supportsMultipleAccounts: false,
    connectionMethod: 'user_config',
  };
}

module.exports = {
  buildBitwardenSnapshot,
};
