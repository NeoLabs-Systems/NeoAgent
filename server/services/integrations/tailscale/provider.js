'use strict';

const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
} = require('../provider_config_store');
const { getConnectionAccessMode } = require('../access');
const { encryptValue } = require('../secrets');
const { summarizeAppConnection } = require('../connection_summary');
const { upsertConnectedIntegration } = require('../connection_store');
const { trimText } = require('../../../utils/text');
const { APP, PROVIDER_KEY, TOOLS, toolAppMap } = require('./constants');
const { readTailscaleStatus } = require('./client');
const { executeTailscaleTool } = require('./tools');
const { peersFromStatus } = require('./network');

// A tailnet is joined by running `tailscale up` on the NeoAgent host; there is
// no token to paste in. The only thing worth storing is an unusual socket path,
// so setup is a probe plus one optional field.
function parseConfigInput(rawConfig, existingConfig = {}) {
  const source = rawConfig && typeof rawConfig === 'object' ? rawConfig : {};
  return {
    socketPath: trimText(source.socketPath) || trimText(existingConfig.socketPath),
  };
}

function loadExistingConnection(userId, agentId) {
  return db
    .prepare(
      `SELECT *
       FROM integration_connections
       WHERE user_id = ? AND agent_id = ? AND provider_key = ?
       ORDER BY updated_at DESC, id DESC
       LIMIT 1`,
    )
    .get(userId, agentId, PROVIDER_KEY);
}

function connectedAccountCount(userId, agentId) {
  return db.prepare(
    `SELECT COUNT(*) count FROM integration_connections
     WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND status = 'connected'`,
  ).get(userId, agentId, PROVIDER_KEY)?.count || 0;
}

function resolveTailscaleEnvStatus(userId, agentId = null) {
  const normalizedUserId = Number(userId);
  const scopedAgentId = Number.isInteger(normalizedUserId) && normalizedUserId > 0
    ? resolveAgentId(normalizedUserId, agentId)
    : null;
  const connected = scopedAgentId !== null && connectedAccountCount(normalizedUserId, scopedAgentId) > 0;
  return {
    configured: connected,
    missing: connected ? [] : ['tailscale'],
    summary: connected
      ? 'This NeoAgent server is joined to a tailnet.'
      : 'Run `tailscale up` on the NeoAgent host, then connect the tailnet in Official Integrations.',
    setupMode: 'user',
  };
}

function upsertTailnetConnection(userId, agentId, tailnet, storedSocketPath = '') {
  const existing = loadExistingConnection(userId, agentId);
  const accessMode = getConnectionAccessMode(existing || null);
  const self = tailnet?.self || {};
  const accountEmail = `tailscale:${tailnet?.currentTailnet?.name || self.hostName || 'tailnet'}`;
  const metadata = {
    ...(existing?.metadata_json ? JSON.parse(existing.metadata_json) : {}),
    access_mode: accessMode,
    tailnetName: tailnet?.currentTailnet?.name || null,
    magicDnsSuffix: tailnet?.magicDnsSuffix || null,
    hostName: self.hostName || null,
    backendState: tailnet?.backendState || null,
  };

  upsertConnectedIntegration({
    userId,
    agentId,
    providerKey: PROVIDER_KEY,
    appKey: APP.id,
    accountEmail,
    scopes: ['tailscale:localapi'],
    // The socket path is a location, not a secret, but it has to travel with
    // the connection: tool calls receive only this row, and a non-default
    // socket is the difference between reading the tailnet and not.
    credentialsJson: encryptValue(JSON.stringify({ tailnet: accountEmail, socketPath: storedSocketPath })),
    metadata,
  });

  if (existing && existing.account_email !== accountEmail) {
    db.prepare('DELETE FROM integration_connections WHERE id = ? AND user_id = ? AND agent_id = ?')
      .run(existing.id, userId, agentId);
  }

  return loadExistingConnection(userId, agentId);
}

function buildTailscaleSnapshot(provider, connectionRows, context = {}) {
  const env = provider.getEnvStatus(context);
  const app = summarizeAppConnection(APP, connectionRows, env, { toolCount: TOOLS.length });
  return {
    id: provider.key,
    label: provider.label,
    description: provider.description,
    icon: provider.icon,
    apps: [app],
    env,
    connection: {
      status: !env.configured ? 'env_not_configured' : app.connection.connected ? 'connected' : 'not_connected',
      connected: app.connection.connected,
      accountEmail: app.connection.accountEmail,
      accountCount: app.connection.accountCount,
      appCount: app.connection.connected ? 1 : 0,
      lastConnectedAt: app.connection.lastConnectedAt,
    },
    availableToolCount: app.availableToolCount,
    connectPrompt: provider.connectPrompt,
    supportsMultipleAccounts: false,
    connectionMethod: provider.connectionMethod,
  };
}

function createTailscaleProvider() {
  return {
    key: PROVIDER_KEY,
    label: 'Tailscale',
    description: 'Reach the other machines on this server\'s Tailscale network over their 100.x addresses, without exposing them to the internet.',
    icon: 'tailscale',
    apps: [APP],
    connectPrompt: 'Join this NeoAgent host to your tailnet with `tailscale up`, then connect it here. The agent can then list peers and call services on them over the private network.',
    supportsMultipleAccounts: false,
    connectionMethod: 'user_config',
    getApp(appId) {
      return trimText(appId) === APP.id ? APP : null;
    },
    getToolAppId(toolName) {
      return toolAppMap.get(trimText(toolName)) || null;
    },
    getEnvStatus(context = {}) {
      return resolveTailscaleEnvStatus(context.userId, context.agentId);
    },
    getToolDefinitions(options = {}) {
      const connectedAppIds = new Set(options.connectedAppIds || []);
      return connectedAppIds.has(APP.id) ? TOOLS.slice() : [];
    },
    supportsTool(toolName) {
      return toolAppMap.has(trimText(toolName));
    },
    buildSnapshot(connectionRows, context = {}) {
      return buildTailscaleSnapshot(this, connectionRows, context);
    },
    summarizeForModel(snapshot) {
      if (!snapshot?.env?.configured) {
        return 'Tailscale: this server is not connected to a tailnet yet. Tell the user to run `tailscale up` on the NeoAgent host and connect Tailscale in Official Integrations.';
      }
      return [
        'Tailscale: connected. The other machines on this tailnet are reachable with the tailscale_ tools',
        'even though http_request refuses private addresses.',
        'Call tailscale_list_peers first to learn the hostnames and 100.x addresses,',
        'then tailscale_request to call an HTTP service on one of them,',
        'or tailscale_ping to check whether a port answers.',
      ].join(' ');
    },
    async executeTool(toolName, args, connection, executionOptions = {}) {
      return executeTailscaleTool(toolName, args || {}, connection, {
        signal: executionOptions.signal || null,
      });
    },
    getUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const stored = parseConfigInput(getProviderConfig(normalizedUserId, PROVIDER_KEY, scopedAgentId));
      const accountCount = connectedAccountCount(normalizedUserId, scopedAgentId);
      return {
        socketPath: stored.socketPath,
        configured: accountCount > 0,
        accountCount,
        hasConnectedAccount: accountCount > 0,
      };
    },
    async saveUserConfig({ userId, agentId, config, signal }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to save Tailscale configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const existing = parseConfigInput(getProviderConfig(normalizedUserId, PROVIDER_KEY, scopedAgentId));
      const socketPath = parseConfigInput(config, existing).socketPath;

      let status;
      try {
        status = await readTailscaleStatus({
          signal,
          socketPaths: socketPath ? [socketPath] : undefined,
        });
      } catch (error) {
        throw new Error(trimText(error?.message) || 'Could not read this server\'s tailnet status.');
      }
      const backendState = trimText(status?.BackendState);
      if (backendState && backendState !== 'Running') {
        throw new Error(
          `tailscaled is running but the node is "${backendState}". Run \`tailscale up\` on this host and try again.`,
        );
      }

      setProviderConfig(normalizedUserId, PROVIDER_KEY, { socketPath }, scopedAgentId);
      const connection = upsertTailnetConnection(normalizedUserId, scopedAgentId, {
        backendState: backendState || null,
        magicDnsSuffix: trimText(status?.MagicDNSSuffix) || null,
        currentTailnet: status?.CurrentTailnet
          ? { name: trimText(status.CurrentTailnet.Name) || null }
          : null,
        self: status?.Self || {},
      }, socketPath);

      return {
        socketPath,
        configured: true,
        accountCount: connection?.status === 'connected' ? 1 : 0,
        hasConnectedAccount: connection?.status === 'connected',
        accountEmail: connection?.account_email || null,
        tailnetName: status?.CurrentTailnet ? trimText(status.CurrentTailnet.Name) || null : null,
        peerCount: peersFromStatus(status).length,
      };
    },
    clearUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to clear Tailscale configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      deleteProviderConfig(normalizedUserId, PROVIDER_KEY, scopedAgentId);
      db.prepare('DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?')
        .run(normalizedUserId, scopedAgentId, PROVIDER_KEY);
      return { cleared: true };
    },
  };
}

module.exports = {
  createTailscaleProvider,
  parseConfigInput,
  resolveTailscaleEnvStatus,
};
