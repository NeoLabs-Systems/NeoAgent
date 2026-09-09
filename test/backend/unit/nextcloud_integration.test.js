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

function xmlResponse(body, status = 207) {
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'application/xml' },
  });
}

async function waitFor(condition, timeoutMs = 2000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const value = await condition();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error('Timed out waiting for Nextcloud login session.');
}

afterEach(() => {
  global.fetch = originalFetch;
  teardownTestRuntime(ctx);
  ctx = null;
});

test('Nextcloud URL normalize allows private HTTP and rejects credentials', () => {
  ctx = createTestRuntime();
  const { normalizeBaseUrl, normalizeRemotePath } = require('../../../server/services/integrations/nextcloud/network');
  assert.equal(normalizeBaseUrl('cloud.example.test/'), 'https://cloud.example.test');
  assert.equal(normalizeBaseUrl('192.168.1.40:8080/nextcloud/'), 'http://192.168.1.40:8080/nextcloud');
  assert.throws(() => normalizeBaseUrl('https://user:pass@cloud.example.test'), /without credentials/);
  assert.throws(() => normalizeRemotePath('../etc/passwd'), /parent traversal/);
  assert.equal(normalizeRemotePath('/Documents/Invoices/'), 'Documents/Invoices');
});

test('Nextcloud setup validates status.php and exposes Files, Calendar, and Contacts tools', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'nextcloud_setup' });
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const agent = ensureMainAgent(user.userId);
  const { createNextcloudProvider } = require('../../../server/services/integrations/nextcloud/provider');
  const provider = createNextcloudProvider();
  const requests = [];
  global.fetch = async (url) => {
    requests.push(String(url));
    if (String(url) === 'https://cloud.example.test/status.php') {
      return jsonResponse({ installed: true, version: '29.0.0.1', productname: 'Nextcloud' });
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  const saved = await provider.saveUserConfig({
    userId: user.userId,
    agentId: agent.id,
    config: { baseUrl: 'cloud.example.test/' },
  });
  assert.equal(saved.baseUrl, 'https://cloud.example.test');
  assert.equal(saved.configured, true);
  assert.equal(provider.getEnvStatus({ userId: user.userId, agentId: agent.id }).configured, true);
  assert.deepEqual(requests, ['https://cloud.example.test/status.php']);

  const tools = provider.getToolDefinitions({ connectedAppIds: ['files', 'calendar', 'contacts'] });
  assert.equal(tools.some((tool) => tool.name === 'nextcloud_list_files' && tool.access === 'read'), true);
  assert.equal(tools.some((tool) => tool.name === 'nextcloud_upload_file' && tool.access === 'write'), true);
  assert.equal(tools.some((tool) => tool.name === 'nextcloud_list_events' && tool.appId === 'calendar'), true);
  assert.equal(tools.some((tool) => tool.name === 'nextcloud_create_contact' && tool.appId === 'contacts'), true);
  assert.equal(tools.find((tool) => tool.name === 'nextcloud_ocs_request').access, 'dynamic_http_method');
  provider.shutdown();
});

test('Nextcloud Login Flow v2 upserts Files, Calendar, and Contacts for one login', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'nextcloud_login' });
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const agent = ensureMainAgent(user.userId);
  const { createNextcloudProvider } = require('../../../server/services/integrations/nextcloud/provider');
  const provider = createNextcloudProvider();
  global.fetch = async (url, options = {}) => {
    const target = String(url);
    if (target === 'https://cloud.example.test/status.php') {
      return jsonResponse({ installed: true, version: '29.0.0.1', productname: 'Nextcloud' });
    }
    if (target === 'https://cloud.example.test/index.php/login/v2') {
      return jsonResponse({
        login: 'https://cloud.example.test/index.php/login/v2/flow/abc',
        poll: {
          token: 'poll-token',
          endpoint: 'https://cloud.example.test/login/v2/poll',
        },
      });
    }
    if (target === 'https://cloud.example.test/login/v2/poll') {
      assert.equal(String(options.method || 'GET').toUpperCase(), 'POST');
      return jsonResponse({
        server: 'https://cloud.example.test',
        loginName: 'alice',
        appPassword: 'app-secret',
      });
    }
    if (target === 'https://cloud.example.test/ocs/v2.php/cloud/user') {
      return jsonResponse({
        ocs: { meta: { status: 'ok', statuscode: 200 }, data: { id: 'alice', email: 'alice@example.test', 'display-name': 'Alice' } },
      });
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  await provider.saveUserConfig({
    userId: user.userId,
    agentId: agent.id,
    config: { baseUrl: 'https://cloud.example.test' },
  });
  const started = await provider.beginConnection({
    userId: user.userId,
    agentId: agent.id,
    appKey: 'files',
  });
  assert.equal(started.status, 'interactive_connect');
  assert.match(started.url, /\/api\/integrations\/nextcloud\/connect\//);
  const session = await waitFor(() => {
    const current = provider.getConnectionSession(user.userId, 'nextcloud', started.sessionId, agent.id);
    return current?.status === 'connected' ? current : null;
  });
  assert.equal(session.loginUrl, 'https://cloud.example.test/index.php/login/v2/flow/abc');
  assert.equal(session.accountEmail, 'alice@example.test');
  const rows = ctx.db.prepare(
    "SELECT app_key FROM integration_connections WHERE provider_key='nextcloud' AND status='connected' ORDER BY app_key",
  ).all();
  assert.deepEqual(rows.map((row) => row.app_key), ['calendar', 'contacts', 'files']);
  provider.shutdown();
});

test('Nextcloud tools guard OCS and DAV paths and reject traversal', async () => {
  ctx = createTestRuntime();
  const { executeFilesTool } = require('../../../server/services/integrations/nextcloud/files');
  const credentials = {
    baseUrl: 'https://cloud.example.test',
    username: 'alice',
    appPassword: 'app-secret',
  };
  await assert.rejects(
    () => executeFilesTool('nextcloud_list_files', { path: '../etc' }, credentials),
    /parent traversal/,
  );
  await assert.rejects(
    () => executeFilesTool('nextcloud_ocs_request', { method: 'GET', path: '/api/config' }, credentials),
    /must start with \/ocs\/v2.php\//,
  );

  global.fetch = async (url, options = {}) => {
    const target = String(url);
    if (target === 'https://cloud.example.test/remote.php/dav/files/alice/' && String(options.method).toUpperCase() === 'PROPFIND') {
      return xmlResponse(`<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
  <d:response>
    <d:href>/remote.php/dav/files/alice/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>
    <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/alice/Documents/</d:href>
    <d:propstat><d:prop>
      <d:displayname>Documents</d:displayname>
      <d:resourcetype><d:collection/></d:resourcetype>
      <oc:fileid>12</oc:fileid>
    </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>
</d:multistatus>`);
    }
    if (target === 'https://cloud.example.test/ocs/v2.php/apps/notes/api/v1/notes') {
      return jsonResponse({ ocs: { meta: { status: 'ok', statuscode: 200 }, data: [{ id: 1, title: 'Note' }] } });
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  const listed = await executeFilesTool('nextcloud_list_files', {}, credentials);
  assert.deepEqual(listed.result, [
    { path: 'Documents', name: 'Documents', type: 'folder', size: null, mimeType: null, lastModified: null, fileId: '12', deletedAt: null, originalPath: null },
  ]);
  const notes = await executeFilesTool('nextcloud_ocs_request', {
    method: 'GET',
    path: '/ocs/v2.php/apps/notes/api/v1/notes',
  }, credentials);
  assert.equal(notes.result[0].title, 'Note');
});

test('Nextcloud disconnect revokes the app password and sibling app connections', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'nextcloud_disconnect' });
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const { encryptValue } = require('../../../server/services/integrations/secrets');
  const agent = ensureMainAgent(user.userId);
  const { createNextcloudProvider } = require('../../../server/services/integrations/nextcloud/provider');
  const provider = createNextcloudProvider();
  const revoked = [];
  global.fetch = async (url) => {
    if (String(url) === 'https://cloud.example.test/status.php') {
      return jsonResponse({ installed: true, version: '29.0.0.1', productname: 'Nextcloud' });
    }
    if (String(url) === 'https://cloud.example.test/ocs/v2.php/core/apppassword') {
      revoked.push('app-secret');
      return jsonResponse({ ocs: { meta: { status: 'ok', statuscode: 200 }, data: {} } });
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  await provider.saveUserConfig({
    userId: user.userId,
    agentId: agent.id,
    config: { baseUrl: 'https://cloud.example.test' },
  });
  const credentials = encryptValue(JSON.stringify({
    baseUrl: 'https://cloud.example.test',
    username: 'alice',
    appPassword: 'app-secret',
  }));
  for (const appKey of ['files', 'calendar', 'contacts']) {
    ctx.db.prepare(`INSERT INTO integration_connections
      (user_id,agent_id,provider_key,app_key,status,account_email,credentials_json)
      VALUES (?,?,?,?,?,?,?)`).run(
      user.userId, agent.id, 'nextcloud', appKey, 'connected', 'alice@example.test', credentials,
    );
  }

  await provider.clearUserConfig({ userId: user.userId, agentId: agent.id });
  assert.equal(revoked.length, 1);
  assert.equal(ctx.db.prepare("SELECT COUNT(*) count FROM integration_connections WHERE provider_key='nextcloud'").get().count, 0);
  assert.equal(provider.getEnvStatus({ userId: user.userId, agentId: agent.id }).configured, false);
  provider.shutdown();
});
