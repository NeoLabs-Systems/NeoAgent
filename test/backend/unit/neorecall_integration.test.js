'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const originalFetch = global.fetch;
let ctx;

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

afterEach(() => {
  global.fetch = originalFetch;
  teardownTestRuntime(ctx);
  ctx = null;
});

test('NeoRecall provider validates setup and exposes only read-only local recall tools', async () => {
  ctx = createTestRuntime();
  process.env.PUBLIC_URL = 'https://agent.example.test';
  const user = await createTestUser(ctx.db, { username: 'neorecall_provider' });
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const agent = ensureMainAgent(user.userId);
  const { createNeoRecallProvider } = require('../../../server/services/integrations/neorecall/provider');
  const provider = createNeoRecallProvider();
  const requests = [];
  global.fetch = async (url, options = {}) => {
    requests.push({ url: String(url), options });
    if (String(url) === 'http://127.0.0.1:4500/health') {
      return jsonResponse({ status: 'ok', process: 'http', version: '0.1.0-beta.0' });
    }
    if (String(url) === 'http://127.0.0.1:4500/api/oauth/companion/neoagent/bootstrap') {
      return jsonResponse({
        companion: 'neoagent', clientId: 'nrc_test',
        redirectUri: 'https://agent.example.test/api/integrations/oauth/callback',
        scopes: ['search:read', 'memories:read', 'recordings:read'],
        authorizationEndpoint: 'http://127.0.0.1:4500/oauth/authorize',
      });
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  const saved = await provider.saveUserConfig({
    userId: user.userId,
    agentId: agent.id,
    config: { baseUrl: '127.0.0.1:4500/' },
  });
  assert.equal(saved.baseUrl, 'http://127.0.0.1:4500');
  assert.equal(saved.configured, true);
  assert.equal(provider.getEnvStatus({ userId: user.userId, agentId: agent.id }).configured, true);
  assert.deepEqual(requests.map((entry) => entry.url), [
    'http://127.0.0.1:4500/health',
    'http://127.0.0.1:4500/api/oauth/companion/neoagent/bootstrap',
  ]);

  const tools = provider.getToolDefinitions({ connectedAppIds: ['recall'] });
  assert.deepEqual(tools.map((tool) => tool.name), [
    'neorecall_search', 'neorecall_list_memories', 'neorecall_get_memory',
    'neorecall_list_mini_memories', 'neorecall_list_daily_summaries',
    'neorecall_list_conversations', 'neorecall_get_conversation',
  ]);
  assert.equal(tools.every((tool) => tool.access === 'read'), true);
  assert.equal(tools.some((tool) => tool.name.includes('ask')), false);
});

test('NeoRecall tool client refreshes OAuth and forwards hybrid search filters without an Ask call', async () => {
  ctx = createTestRuntime();
  const { executeTool, normalizeBaseUrl } = require('../../../server/services/integrations/neorecall/client');
  assert.equal(normalizeBaseUrl('recall.example.test/'), 'https://recall.example.test');
  assert.throws(() => normalizeBaseUrl('https://user:pass@recall.example.test'), /without credentials/);

  const requests = [];
  global.fetch = async (url, options = {}) => {
    requests.push({ url: String(url), options });
    if (String(url) === 'https://recall.example.test/oauth/token') {
      return jsonResponse({
        access_token: 'nro_next', refresh_token: 'nrr_next', expires_in: 3600,
        scope: 'search:read memories:read recordings:read',
      });
    }
    if (String(url).startsWith('https://recall.example.test/api/v1/search?')) {
      assert.equal(options.headers.Authorization, 'Bearer nro_next');
      return jsonResponse({ results: [{ kind: 'memory', title: 'Project decision', body: 'The launch moved to Friday.' }] });
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  const execution = await executeTool('neorecall_search', {
    query: 'when is the launch', kinds: ['memory', 'mini_memory'], limit: 8,
  }, {
    baseUrl: 'https://recall.example.test', client_id: 'nrc_client',
    access_token: 'nro_expired', refresh_token: 'nrr_old', expires_at_ms: 0,
  });
  assert.equal(execution.result.results[0].title, 'Project decision');
  assert.equal(execution.credentials.access_token, 'nro_next');
  assert.equal(execution.credentials.refresh_token, 'nrr_next');
  const searchUrl = new URL(requests[1].url);
  assert.equal(searchUrl.searchParams.get('q'), 'when is the launch');
  assert.equal(searchUrl.searchParams.get('kinds'), 'memory,mini_memory');
  assert.equal(searchUrl.searchParams.get('limit'), '8');
  assert.equal(requests.length, 2);
});

test('NeoRecall disconnect revokes durable credentials before removing local setup', async () => {
  ctx = createTestRuntime();
  process.env.PUBLIC_URL = 'https://agent.example.test';
  const user = await createTestUser(ctx.db, { username: 'neorecall_disconnect' });
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const { encryptValue } = require('../../../server/services/integrations/secrets');
  const agent = ensureMainAgent(user.userId);
  const { createNeoRecallProvider } = require('../../../server/services/integrations/neorecall/provider');
  const provider = createNeoRecallProvider();
  const revoked = [];
  global.fetch = async (url, options = {}) => {
    const target = String(url);
    if (target === 'https://recall.example.test/health') {
      return jsonResponse({ status: 'ok', process: 'http' });
    }
    if (target === 'https://recall.example.test/api/oauth/companion/neoagent/bootstrap') {
      return jsonResponse({
        companion: 'neoagent', clientId: 'nrc_disconnect',
        redirectUri: 'https://agent.example.test/api/integrations/oauth/callback',
        scopes: ['search:read', 'memories:read', 'recordings:read'],
      });
    }
    if (target === 'https://recall.example.test/oauth/revoke') {
      revoked.push(new URLSearchParams(options.body).get('token'));
      return new Response('', { status: 200 });
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  await provider.saveUserConfig({
    userId: user.userId, agentId: agent.id, config: { baseUrl: 'https://recall.example.test' },
  });
  ctx.db.prepare(`INSERT INTO integration_connections
    (user_id,agent_id,provider_key,app_key,status,account_email,credentials_json)
    VALUES (?,?,?,?,?,?,?)`).run(user.userId, agent.id, 'neorecall', 'recall', 'connected',
      'recall@example.test', encryptValue(JSON.stringify({
        baseUrl: 'https://recall.example.test', client_id: 'nrc_disconnect',
        access_token: 'nro_disconnect', refresh_token: 'nrr_disconnect',
      })));

  await provider.clearUserConfig({ userId: user.userId, agentId: agent.id });
  assert.deepEqual(revoked.sort(), ['nro_disconnect', 'nrr_disconnect']);
  assert.equal(ctx.db.prepare("SELECT COUNT(*) count FROM integration_connections WHERE provider_key='neorecall'").get().count, 0);
  assert.equal(provider.getEnvStatus({ userId: user.userId, agentId: agent.id }).configured, false);
});
