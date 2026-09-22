'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

function createInteractiveProvider(sessions) {
  return {
    key: 'interactive_probe',
    label: 'Interactive Probe',
    description: 'Provider that links through a popup connect page.',
    apps: [{ id: 'account', label: 'Account' }],
    getApp() {
      return this.apps[0];
    },
    getEnvStatus() {
      return { configured: true, missing: [], summary: 'Ready.' };
    },
    getToolDefinitions() {
      return [];
    },
    supportsTool() {
      return false;
    },
    buildSnapshot(rows) {
      return {
        id: this.key,
        label: this.label,
        apps: [],
        connection: { connected: rows.length > 0 },
        env: this.getEnvStatus(),
      };
    },
    async beginConnection({ userId, agentId, appKey }) {
      sessions.set('session-1', { userId, agentId, appKey });
      return {
        status: 'interactive_connect',
        url: `/api/integrations/${this.key}/connect/session-1`,
      };
    },
    getConnectionSession(userId, providerKey, sessionId, agentId) {
      const session = sessions.get(String(sessionId || '').trim());
      if (!session || session.userId !== userId) return null;
      if (String(session.agentId || '') !== String(agentId || '')) return null;
      return { id: sessionId, status: 'connecting' };
    },
  };
}

function createManagerWith(provider) {
  const { IntegrationManager } = require('../../../server/services/integrations/manager');
  const manager = new IntegrationManager();
  manager.registry = {
    get: (key) => (key === provider.key ? provider : null),
    list: () => [provider],
  };
  return manager;
}

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('interactive connect URLs carry the connecting agent so non-default agents can link', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'interactive_scope' });
  const { createAgent, ensureMainAgent, resolveAgentId } = require('../../../server/services/agents/manager');
  const mainAgent = ensureMainAgent(user.userId);
  const specialist = createAgent(user.userId, { displayName: 'Specialist' });

  const sessions = new Map();
  const provider = createInteractiveProvider(sessions);
  const manager = createManagerWith(provider);

  const started = await manager.beginOAuth(user.userId, provider.key, {
    agentId: specialist.id,
    appKey: 'account',
  });

  // The popup has no session-side agent context, so the connect page reads the
  // scope straight off the URL the same way the route does.
  const popupAgentId = new URL(started.url).searchParams.get('agentId');
  assert.equal(popupAgentId, specialist.id);
  assert.notEqual(resolveAgentId(user.userId, popupAgentId), mainAgent.id);

  assert.ok(manager.getConnectionSession(
    user.userId,
    provider.key,
    'session-1',
    resolveAgentId(user.userId, popupAgentId),
  ));
});

test('connected accounts stay private to the agent that linked them', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'connection_scope' });
  const { createAgent, ensureMainAgent } = require('../../../server/services/agents/manager');
  const mainAgent = ensureMainAgent(user.userId);
  const specialist = createAgent(user.userId, { displayName: 'Specialist' });
  const { upsertConnectedIntegration } = require('../../../server/services/integrations/connection_store');

  upsertConnectedIntegration({
    userId: user.userId,
    agentId: mainAgent.id,
    providerKey: 'interactive_probe',
    appKey: 'account',
    accountEmail: 'person@example.test',
    credentialsJson: '{}',
  });

  const manager = createManagerWith(createInteractiveProvider(new Map()));
  assert.equal(manager.listConnections(user.userId, null, mainAgent.id).length, 1);
  assert.equal(manager.listConnections(user.userId, null, specialist.id).length, 0);
  assert.equal(manager.listProviders(user.userId, specialist.id)[0].connection.connected, false);
});
