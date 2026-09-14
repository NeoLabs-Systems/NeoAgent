'use strict';

const { getConnectionAccessMode } = require('./access');

// Every integration provider reports its connected accounts to the same client
// screens, so the shape of that report lives here rather than being restated in
// each provider. Providers supply only what genuinely differs: the tool count
// when their app definition does not carry one.

function sortConnections(rows) {
  return rows.slice().sort((left, right) => {
    const leftEmail = String(left.account_email || '').toLowerCase();
    const rightEmail = String(right.account_email || '').toLowerCase();
    if (leftEmail !== rightEmail) return leftEmail.localeCompare(rightEmail);
    return String(right.updated_at || '').localeCompare(String(left.updated_at || ''));
  });
}

function summarizeAccountRow(row, envStatus) {
  if (!envStatus.configured) {
    return {
      id: row?.id || null,
      status: 'env_not_configured',
      connected: false,
      accountEmail: row?.account_email || null,
      lastConnectedAt: row?.last_connected_at || null,
      accessMode: getConnectionAccessMode(row || null),
    };
  }

  if (!row) {
    return {
      id: null,
      status: 'not_connected',
      connected: false,
      accountEmail: null,
      lastConnectedAt: null,
      accessMode: getConnectionAccessMode(null),
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

function resolveAppStatus(envStatus, accounts, connectedAccounts) {
  if (!envStatus.configured) return 'env_not_configured';
  if (connectedAccounts.length > 0) return 'connected';
  if (accounts.some((account) => account.status === 'authorizing')) return 'authorizing';
  return 'not_connected';
}

function summarizeAppConnection(app, connectionRows, envStatus, options = {}) {
  const accounts = sortConnections(Array.isArray(connectionRows) ? connectionRows : [])
    .map((row) => summarizeAccountRow(row, envStatus));
  const connectedAccounts = accounts.filter((account) => account.connected);
  const latestConnectedAt = connectedAccounts
    .map((account) => account.lastConnectedAt)
    .filter(Boolean)
    .sort()
    .reverse()[0] || null;
  const toolCount = options.toolCount ?? (app.toolDefinitions?.length || 0);

  return {
    id: app.id,
    label: app.label,
    description: app.description,
    accounts,
    connection: {
      status: resolveAppStatus(envStatus, accounts, connectedAccounts),
      connected: connectedAccounts.length > 0,
      accountCount: connectedAccounts.length,
      accountEmail: connectedAccounts.length === 1 ? connectedAccounts[0].accountEmail : null,
      lastConnectedAt: latestConnectedAt,
    },
    availableToolCount:
      envStatus.configured && connectedAccounts.length > 0 ? toolCount : 0,
  };
}

// The provider-level rollup across all of a provider's apps: one connection
// status for the whole integration card, plus its total tool count.
function summarizeProviderConnection(appSnapshots, envStatus) {
  const connectedApps = appSnapshots.filter((app) => app.connection.connected);
  const connectedAccounts = connectedApps.flatMap((app) =>
    app.accounts.filter((account) => account.connected),
  );
  return {
    connectedApps,
    connectedAccounts,
    connection: {
      // The provider card reports only whether the integration as a whole is
      // usable; a single app still mid-authorization is shown on that app.
      status: !envStatus.configured
        ? 'env_not_configured'
        : (connectedAccounts.length > 0 ? 'connected' : 'not_connected'),
      connected: connectedAccounts.length > 0,
      accountEmail: connectedAccounts.length === 1
        ? connectedAccounts[0].accountEmail
        : null,
      accountCount: connectedAccounts.length,
      appCount: connectedApps.length,
      lastConnectedAt: connectedAccounts
        .map((account) => account.lastConnectedAt)
        .filter(Boolean)
        .sort()
        .reverse()[0] || null,
    },
    availableToolCount: appSnapshots.reduce(
      (total, app) => total + app.availableToolCount,
      0,
    ),
  };
}

// One line naming every connected account, for the model's context.
function buildConnectedAppSummary(appSnapshots) {
  return appSnapshots
    .filter((app) => app.connection.connected)
    .map((app) => {
      const emails = app.accounts
        .filter((account) => account.connected)
        .map((account) => account.accountEmail || `connection ${account.id}`)
        .join(', ');
      return `${app.label}: ${emails}`;
    })
    .join(' | ');
}

// Prose for the model: how an app's accounts stand, in one phrase.
function formatAccountSummary(appSnapshot) {
  const emails = appSnapshot.accounts
    .filter((account) => account.connected)
    .map((account) => account.accountEmail || `connection ${account.id}`);

  if (emails.length === 0) return 'no connected accounts';
  if (emails.length === 1) return `connected as ${emails[0]}`;
  return `connected with ${emails.length} accounts: ${emails.join(', ')}`;
}

module.exports = {
  buildConnectedAppSummary,
  formatAccountSummary,
  sortConnections,
  summarizeAccountRow,
  summarizeAppConnection,
  summarizeProviderConnection,
};
