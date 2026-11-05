'use strict';

const db = require('../../../db/database');
const { createOAuthProvider } = require('../oauth_provider');
const { decryptValue } = require('../secrets');
const { parseJsonObject } = require('../../../utils/text');
const { resolveAgentId } = require('../../agents/manager');
const { APP, TOOLS } = require('./constants');
const { TailscaleRuntime, connectionScope } = require('./runtime');
const { TailscaleSessions } = require('./sessions');
const { normalizeServices } = require('./policy');

function createTailscaleProvider(options = {}) {
  const runtime = new TailscaleRuntime(() => options.app?.locals?.runtimeManager);
  const sessions = new TailscaleSessions(runtime);
  const provider = createOAuthProvider({
    key: 'tailscale', label: 'Tailscale', icon: 'tailscale', connectionMethod: 'interactive',
    description: 'Sign in to Tailscale and grant access to private services. Your cloud computer only makes outgoing connections.',
    apps: [APP], toolDefinitions: TOOLS,
    getEnvStatus() {
      const ready = Boolean(options.app?.locals?.runtimeManager?.computerBackend?.vmManager);
      return {
        configured: ready, missing: ready ? [] : ['isolated_computer'], setupMode: 'server',
        summary: ready ? 'Sign in to your Tailscale account to connect.' : 'Tailscale requires an isolated per-user QEMU or Docker computer runtime.',
      };
    },
    connectPrompt: 'Choose Connect and sign in on Tailscale. Then configure service access for the connected account.',
    async executeTool(name, args, context) {
      const action = name === 'tailscale_list_peers' ? 'list' : name === 'tailscale_ping' ? 'ping' : name === 'tailscale_request' ? 'request' : null;
      if (!action) return null;
      return { result: await runtime.execute(context.connection, action, args || {}, context.signal) };
    },
    async disconnect(connection, { signal } = {}) {
      const credentials = JSON.parse(decryptValue(connection.credentials_json));
      await runtime.call(connection.user_id, connectionScope(connection), { action: 'logout', ...credentials }, signal);
    },
  });
  provider.requiresExclusiveExecution = true;
  provider.beforeDisconnect = (connection) => runtime.stop(connectionScope(connection));
  provider.beginConnection = (context) => sessions.begin(context);
  provider.getConnectionSession = (userId, providerKey, sessionId, agentId) => providerKey === provider.key ? sessions.get(userId, agentId, sessionId) : null;
  provider.cancelConnectionSession = (userId, agentId, sessionId) => sessions.cancel(userId, agentId, sessionId);
  provider.shutdown = async () => { await sessions.shutdown(); await runtime.shutdown(); };
  provider.getServiceAccess = async ({ userId, agentId, connectionId, signal }) => {
    const connection = ownedConnection(userId, agentId, connectionId);
    const release = await options.app.locals.integrationManager.acquireConnectionExecution(connection, signal);
    try { return await runtime.execute(connection, 'list', {}, signal); }
    finally { release(); }
  };
  provider.setServiceAccess = async ({ userId, agentId, connectionId, services }) => {
    const connection = ownedConnection(userId, agentId, connectionId);
    const normalized = normalizeServices(services);
    const metadata = { ...parseJsonObject(connection.metadata_json), services: normalized };
    db.prepare(`UPDATE integration_connections SET metadata_json = ?, updated_at = datetime('now')
      WHERE id = ? AND user_id = ? AND agent_id = ? AND status = 'connected'`)
      .run(JSON.stringify(metadata), connection.id, connection.user_id, connection.agent_id);
    await runtime.stop(connectionScope(connection));
    return { services: normalized };
  };
  return provider;
}

function ownedConnection(userId, agentId, connectionId) {
  const connection = db.prepare(`SELECT * FROM integration_connections
    WHERE user_id = ? AND agent_id = ? AND id = ? AND provider_key = 'tailscale' AND status = 'connected'`)
    .get(userId, resolveAgentId(userId, agentId), Number(connectionId));
  if (!connection) throw new Error('That Tailscale connection is not available to this agent.');
  return connection;
}

module.exports = { createTailscaleProvider };
