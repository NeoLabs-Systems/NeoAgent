'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const originalFetch = global.fetch;
const BASE = 'https://cloud.example.test';
const CALLBACK = 'https://agent.example.test/api/integrations/oauth/callback';
const ALL_SCOPES = ['files:read', 'files:write', 'signing:read', 'signing:write'];
let ctx;

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function setupResponses(target) {
  if (target === `${BASE}/api/health`) return jsonResponse({ status: 'ok' });
  if (target === `${BASE}/api/version`) return jsonResponse({ product: 'neocloud', version: '0.1.1' });
  if (target === `${BASE}/api/oauth/companion/neoagent/bootstrap`) {
    return jsonResponse({
      companion: 'neoagent', created: false, clientId: 'ncc_test', redirectUri: CALLBACK,
      scopes: ALL_SCOPES, authorizationEndpoint: 'http://localhost:3000/oauth/authorize',
    });
  }
  return null;
}

async function setupProvider(username) {
  ctx = createTestRuntime();
  process.env.PUBLIC_URL = 'https://agent.example.test';
  const user = await createTestUser(ctx.db, { username });
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const agent = ensureMainAgent(user.userId);
  const { createNeoCloudProvider } = require('../../../server/services/integrations/neocloud/provider');
  return { user, agent, provider: createNeoCloudProvider() };
}

function insertConnection(user, agent, { scopes, accessMode = 'read_write', email = 'neo@example.test' }) {
  const { encryptValue } = require('../../../server/services/integrations/secrets');
  ctx.db.prepare(`INSERT INTO integration_connections
    (user_id,agent_id,provider_key,app_key,status,account_email,credentials_json,scopes_json,metadata_json)
    VALUES (?,?,?,?,?,?,?,?,?)`).run(user.userId, agent.id, 'neocloud', 'files', 'connected', email,
    encryptValue(JSON.stringify({
      baseUrl: BASE, client_id: 'ncc_test', access_token: 'nca_live', refresh_token: 'ncr_live',
      expires_at_ms: Date.now() + 3_600_000,
    })), JSON.stringify(scopes), JSON.stringify({ access_mode: accessMode }));
}

afterEach(() => {
  global.fetch = originalFetch;
  teardownTestRuntime(ctx);
  ctx = null;
});

test('NeoCloud setup checks health and product before saving, and refuses other servers', async () => {
  const { user, agent, provider } = await setupProvider('neocloud_setup');
  const requests = [];
  let product = 'neocloud';
  global.fetch = async (url) => {
    const target = String(url);
    requests.push(target);
    if (target === `${BASE}/api/version`) return jsonResponse({ product, version: '1.0.0' });
    return setupResponses(target) || Promise.reject(new Error(`Unexpected request: ${url}`));
  };

  product = 'nextcloud';
  await assert.rejects(
    provider.saveUserConfig({ userId: user.userId, agentId: agent.id, config: { baseUrl: BASE } }),
    /healthy NeoCloud server/,
  );
  assert.equal(provider.getEnvStatus({ userId: user.userId, agentId: agent.id }).configured, false);

  product = 'neocloud';
  requests.length = 0;
  const saved = await provider.saveUserConfig({
    userId: user.userId, agentId: agent.id, config: { baseUrl: 'cloud.example.test/' },
  });
  assert.equal(saved.baseUrl, BASE);
  assert.equal(saved.configured, true);
  assert.deepEqual(requests, [
    `${BASE}/api/health`, `${BASE}/api/version`, `${BASE}/api/oauth/companion/neoagent/bootstrap`,
  ]);
});

test('NeoCloud OAuth requests all scopes with PKCE and stores the granted ones', async () => {
  const { user, agent, provider } = await setupProvider('neocloud_oauth');
  const tokenForms = [];
  global.fetch = async (url, options = {}) => {
    const target = String(url);
    if (target === `${BASE}/oauth/token`) {
      tokenForms.push(Object.fromEntries(new URLSearchParams(options.body)));
      return jsonResponse({
        access_token: 'nca_1', token_type: 'Bearer', expires_in: 3600, refresh_token: 'ncr_1',
        scope: 'files:read signing:read',
      });
    }
    if (target === `${BASE}/oauth/userinfo`) {
      assert.equal(options.headers.Authorization, 'Bearer nca_1');
      return jsonResponse({ sub: 'u1', preferred_username: 'neo', email: 'neo@example.test', scope: 'files:read signing:read' });
    }
    return setupResponses(target) || Promise.reject(new Error(`Unexpected request: ${url}`));
  };
  await provider.saveUserConfig({ userId: user.userId, agentId: agent.id, config: { baseUrl: BASE } });

  const verifier = 'verifier-value-for-pkce-challenge-tests';
  const started = await provider.beginOAuth({
    state: '0123456789abcdef0123456789abcdef', codeVerifier: verifier,
    userId: user.userId, agentId: agent.id, appKey: 'files',
  });
  const authorize = new URL(started.url);
  assert.equal(authorize.origin, BASE);
  assert.equal(authorize.pathname, '/oauth/authorize');
  assert.equal(authorize.searchParams.get('client_id'), 'ncc_test');
  assert.equal(authorize.searchParams.get('redirect_uri'), CALLBACK);
  assert.equal(authorize.searchParams.get('code_challenge_method'), 'S256');
  assert.equal(
    authorize.searchParams.get('code_challenge'),
    require('node:crypto').createHash('sha256').update(verifier).digest('base64url'),
  );
  assert.equal(authorize.searchParams.get('scope'), ALL_SCOPES.join(' '));

  const finished = await provider.finishOAuth({
    code: 'code_1', codeVerifier: verifier, state: '0123456789abcdef0123456789abcdef',
    userId: user.userId, agentId: agent.id, appKey: 'files',
  });
  assert.deepEqual(tokenForms[0], {
    grant_type: 'authorization_code', client_id: 'ncc_test', code: 'code_1',
    redirect_uri: CALLBACK, code_verifier: verifier,
  });
  assert.equal(finished.accountEmail, 'neo@example.test');
  assert.deepEqual(finished.scopes, ['files:read', 'signing:read']);
  assert.equal(finished.credentials.refresh_token, 'ncr_1');
  assert.equal(finished.credentials.scope, 'files:read signing:read');
});

test('NeoCloud refreshes an expired token and keeps rotated credentials when the call fails', async () => {
  ctx = createTestRuntime();
  const { executeTool } = require('../../../server/services/integrations/neocloud/client');
  const expired = {
    baseUrl: BASE, client_id: 'ncc_test', access_token: 'nca_old', refresh_token: 'ncr_old', expires_at_ms: 0,
  };
  global.fetch = async (url, options = {}) => {
    const target = String(url);
    if (target === `${BASE}/oauth/token`) {
      const form = new URLSearchParams(options.body);
      assert.equal(form.get('grant_type'), 'refresh_token');
      assert.equal(form.get('refresh_token'), 'ncr_old');
      return jsonResponse({ access_token: 'nca_new', refresh_token: 'ncr_new', expires_in: 3600, scope: 'files:read' });
    }
    if (target === `${BASE}/api/v1/files?path=%2F`) {
      assert.equal(options.headers.Authorization, 'Bearer nca_new');
      return jsonResponse({ path: '/', items: [] });
    }
    if (target === `${BASE}/api/v1/files/missing/content`) {
      return jsonResponse({ error: 'Not found', code: 'NOT_FOUND' }, 404);
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  const listed = await executeTool('neocloud_list_files', {}, expired);
  assert.deepEqual(listed.result, { path: '/', items: [] });
  assert.equal(listed.credentials.access_token, 'nca_new');
  assert.equal(listed.credentials.refresh_token, 'ncr_new');

  const failed = await executeTool('neocloud_read_file', { file_id: 'missing' }, expired);
  assert.equal(failed.result.code, 'NOT_FOUND');
  assert.equal(failed.result.status, 404);
  assert.equal(failed.credentials.refresh_token, 'ncr_new');

  await assert.rejects(
    executeTool('neocloud_read_file', { file_id: 'missing' }, listed.credentials),
    /NOT_FOUND/,
  );
});

test('NeoCloud maps every tool to its /api/v1 endpoint', async () => {
  ctx = createTestRuntime();
  const { executeTool } = require('../../../server/services/integrations/neocloud/client');
  const { TOOLS } = require('../../../server/services/integrations/neocloud/constants');
  const credentials = {
    baseUrl: BASE, client_id: 'ncc_test', access_token: 'nca_live', refresh_token: 'ncr_live',
    expires_at_ms: Date.now() + 3_600_000,
  };
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({
      method: options.method,
      path: String(url).slice(BASE.length),
      body: options.body ? JSON.parse(options.body) : undefined,
    });
    return jsonResponse({ ok: true });
  };
  const cases = [
    ['neocloud_list_files', { path: '/Contracts' }, 'GET', '/api/v1/files?path=%2FContracts'],
    ['neocloud_search_files', { query: 'lease', limit: 5 }, 'GET', '/api/v1/files/search?q=lease&limit=5'],
    ['neocloud_read_file', { file_id: 'f 1' }, 'GET', '/api/v1/files/f%201/content'],
    ['neocloud_create_file', { path: '/a.md', content: '# A' }, 'POST', '/api/v1/files',
      { path: '/a.md', content: '# A', overwrite: false }],
    ['neocloud_update_file', { file_id: 'f1', content_base64: 'QQ==', base_revision: 'r2' }, 'PUT',
      '/api/v1/files/f1/content', { contentBase64: 'QQ==', baseRevision: 'r2' }],
    ['neocloud_create_folder', { path: '/New' }, 'POST', '/api/v1/folders', { path: '/New' }],
    ['neocloud_move_file', { file_id: 'f1', parent_path: '/Archive' }, 'PATCH', '/api/v1/files/f1',
      { parentPath: '/Archive' }],
    ['neocloud_delete_file', { file_id: 'f1' }, 'DELETE', '/api/v1/files/f1'],
    ['neocloud_create_pdf', { path: '/o.pdf', title: 'Offer', markdown: '# Offer' }, 'POST', '/api/v1/documents/pdf',
      { path: '/o.pdf', title: 'Offer', markdown: '# Offer', overwrite: false }],
    ['neocloud_request_signatures', {
      document: { path: '/Contracts/Bike.pdf', title: 'Bike sale', markdown: '# Bike sale\n\nPrice: 200 EUR' },
      signers: [{ name: 'Neo' }, { name: 'Trinity', email: 'trinity@example.test' }],
    }, 'POST', '/api/v1/signing/requests', {
      document: { path: '/Contracts/Bike.pdf', title: 'Bike sale', markdown: '# Bike sale\n\nPrice: 200 EUR' },
      signers: [{ name: 'Neo' }, { name: 'Trinity', email: 'trinity@example.test' }],
      sendEmail: false,
    }],
    ['neocloud_list_signature_requests', { status: 'pending' }, 'GET', '/api/v1/signing/requests?status=pending'],
    ['neocloud_get_signature_request', { request_id: 's1' }, 'GET', '/api/v1/signing/requests/s1'],
    ['neocloud_remind_signers', { request_id: 's1' }, 'POST', '/api/v1/signing/requests/s1/remind'],
    ['neocloud_new_signing_link', { request_id: 's1', signer_id: 'g2' }, 'POST', '/api/v1/signing/requests/s1/signers/g2/link'],
    ['neocloud_cancel_signature_request', { request_id: 's1' }, 'POST', '/api/v1/signing/requests/s1/cancel'],
  ];
  assert.deepEqual(cases.map(([name]) => name).sort(), TOOLS.map((tool) => tool.name).sort());
  for (const [name, args, method, path, body] of cases) {
    calls.length = 0;
    await executeTool(name, args, credentials);
    assert.deepEqual(calls, [{ method, path, body }], name);
  }

  await assert.rejects(executeTool('neocloud_request_signatures', {
    file_id: 'f1', document: { path: '/x.pdf', title: 'X', markdown: 'x' }, signers: [{ name: 'A' }],
  }, credentials), /exactly one of document or file_id/);
  await assert.rejects(executeTool('neocloud_request_signatures', { file_id: 'f1', signers: [] }, credentials), /signer/);
});

test('NeoCloud offers only granted-scope tools and hides writes on read-only connections', async () => {
  const { user, agent, provider } = await setupProvider('neocloud_scopes');
  global.fetch = async (url) => setupResponses(String(url)) || Promise.reject(new Error(`Unexpected request: ${url}`));
  await provider.saveUserConfig({ userId: user.userId, agentId: agent.id, config: { baseUrl: BASE } });
  const { IntegrationManager } = require('../../../server/services/integrations/manager');
  const manager = new IntegrationManager();
  const toolNames = () => manager.getToolDefinitions(user.userId, agent.id)
    .filter((tool) => tool.integration === 'neocloud')
    .map((tool) => tool.name);

  insertConnection(user, agent, { scopes: ['files:read', 'signing:read', 'signing:write'] });
  assert.deepEqual(toolNames(), [
    'neocloud_list_files', 'neocloud_search_files', 'neocloud_read_file',
    'neocloud_request_signatures', 'neocloud_list_signature_requests', 'neocloud_get_signature_request',
    'neocloud_remind_signers', 'neocloud_new_signing_link', 'neocloud_cancel_signature_request',
  ]);
  const denied = await manager.executeTool(user.userId, 'neocloud_create_file', { path: '/a.md', content: 'a' }, agent.id);
  assert.match(denied.error, /did not grant files:write/);

  ctx.db.prepare("UPDATE integration_connections SET metadata_json=? WHERE provider_key='neocloud'")
    .run(JSON.stringify({ access_mode: 'read_only' }));
  assert.deepEqual(toolNames(), [
    'neocloud_list_files', 'neocloud_search_files', 'neocloud_read_file',
    'neocloud_list_signature_requests', 'neocloud_get_signature_request',
  ]);
  const readOnly = await manager.executeTool(user.userId, 'neocloud_request_signatures', {
    file_id: 'f1', signers: [{ name: 'A' }],
  }, agent.id);
  assert.match(readOnly.error, /read-only/);

  const summary = provider.summarizeForModel({ env: { configured: true }, connection: { connected: true } });
  assert.match(summary, /neocloud_request_signatures/);
  assert.match(summary, /send me the links/);
  assert.match(summary, /private/);
});
