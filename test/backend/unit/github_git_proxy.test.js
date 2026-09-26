'use strict';

const assert = require('node:assert/strict');
const { before, test } = require('node:test');
const express = require('express');

const { request } = require('../../helpers/supertest');

process.env.SESSION_SECRET = process.env.SESSION_SECRET || 'git-proxy-test-secret';

const { encryptValue } = require('../../../server/services/integrations/secrets');
const { buildGuestGitEnv } = require('../../../server/services/integrations/github/git_proxy');
const {
  buildPushRefusalReport,
  parsePushCommands,
} = require('../../../server/services/integrations/github/git_push_policy');

const OLD_ID = 'a'.repeat(40);
const NEW_ID = 'b'.repeat(40);
const NULL_ID = '0'.repeat(40);

function pkt(text) {
  return `${(Buffer.byteLength(text) + 4).toString(16).padStart(4, '0')}${text}`;
}

function fakeIntegrationManager(connections) {
  return {
    listConnections(userId, providerKey, agentId) {
      return connections.filter((connection) =>
        connection.user_id === userId
        && connection.provider_key === providerKey
        && connection.agent_id === agentId);
    },
  };
}

let connection;
before(() => {
  connection = {
    user_id: 1,
    agent_id: 'agent-a',
    provider_key: 'github',
    app_key: 'repos',
    status: 'connected',
    account_email: 'aurorabot-neo',
    metadata_json: JSON.stringify({ userId: 332610433 }),
    credentials_json: encryptValue(JSON.stringify({ access_token: 'gho_test' })),
  };
});

function envConfig(env) {
  const entries = [];
  for (let index = 0; index < Number(env.GIT_CONFIG_COUNT); index += 1) {
    entries.push([env[`GIT_CONFIG_KEY_${index}`], env[`GIT_CONFIG_VALUE_${index}`]]);
  }
  return entries;
}

function proxyApp(integrationManager) {
  const app = express();
  app.locals.integrationManager = integrationManager;
  app.use('/api/git-proxy', require('../../../server/routes/git_proxy'));
  return app;
}

test('parsePushCommands reads ref updates and client capabilities up to the flush', () => {
  const body = Buffer.from([
    pkt(`${OLD_ID} ${NEW_ID} refs/heads/feature\0report-status side-band-64k agent=git/2.43\n`),
    pkt(`${NULL_ID} ${NEW_ID} refs/heads/other\n`),
    '0000',
    'PACK...',
  ].join(''));

  const parsed = parsePushCommands(body);

  assert.equal(parsed.complete, true);
  assert.deepEqual(parsed.commands.map((command) => command.ref), ['refs/heads/feature', 'refs/heads/other']);
  assert.ok(parsed.clientCapabilities.includes('side-band-64k'));
  assert.equal(body.subarray(parsed.bytes).toString(), 'PACK...');
  assert.equal(parsePushCommands(Buffer.from(pkt(`${OLD_ID} ${NEW_ID} refs/heads/x\n`))).complete, false);
});

test('buildPushRefusalReport wraps report-status in side-band when the client asked for it', () => {
  const commands = [
    { oldId: OLD_ID, newId: NEW_ID, ref: 'refs/heads/main' },
    { oldId: NULL_ID, newId: NEW_ID, ref: 'refs/heads/feature' },
  ];
  const refusal = { ref: 'refs/heads/main', reason: 'blocked' };

  const plain = buildPushRefusalReport({ commands, clientCapabilities: ['report-status'], refusal }).toString();
  assert.equal(plain, [
    pkt('unpack ok\n'),
    pkt('ng refs/heads/main blocked\n'),
    pkt('ng refs/heads/feature not pushed because refs/heads/main was refused\n'),
    '0000',
  ].join(''));

  const banded = buildPushRefusalReport({ commands, clientCapabilities: ['side-band-64k'], refusal });
  assert.equal(banded[4], 1);
  assert.equal(banded.subarray(5, banded.length - 4).toString(), plain);
  assert.equal(banded.subarray(banded.length - 4).toString(), '0000');
});

test('buildGuestGitEnv routes GitHub through the proxy as the agent identity', () => {
  const integrationManager = fakeIntegrationManager([connection]);

  const env = buildGuestGitEnv({
    integrationManager,
    userId: 1,
    agentId: 'agent-a',
    runId: 'run-1',
    guestHost: '10.0.2.2',
    ttlMs: 60_000,
  });

  const config = envConfig(env);
  const rewrites = config.filter(([key]) => key.endsWith('.insteadOf')).map(([, value]) => value);
  assert.deepEqual(rewrites, ['https://github.com/', 'git@github.com:', 'ssh://git@github.com/']);
  assert.match(config[0][0], /^url\.http:\/\/10\.0\.2\.2:\d+\/api\/git-proxy\/github\.com\/\.insteadOf$/);
  assert.match(config.at(-1)[1], /^X-NeoAgent-Git-Capability: [A-Za-z0-9_-]{43}$/);
  assert.equal(env.GIT_TERMINAL_PROMPT, '0');
  assert.equal(env.GIT_AUTHOR_NAME, 'aurorabot-neo');
  assert.equal(env.GIT_COMMITTER_EMAIL, '332610433+aurorabot-neo@users.noreply.github.com');
  assert.ok(!JSON.stringify(env).includes('gho_test'));

  assert.equal(buildGuestGitEnv({
    integrationManager,
    userId: 1,
    agentId: 'agent-b',
    runId: 'run-2',
    guestHost: '10.0.2.2',
    ttlMs: 60_000,
  }), null);
});

test('git proxy refuses requests without a valid capability', async () => {
  const res = await request(proxyApp(fakeIntegrationManager([connection])))
    .get('/api/git-proxy/github.com/owner/repo.git/info/refs?service=git-upload-pack')
    .set('X-NeoAgent-Git-Capability', 'not-a-capability');

  assert.equal(res.status, 403);
  assert.match(res.text, /expired/);
});

test('git proxy answers a branch deletion push with a git rejection instead of forwarding it', async () => {
  const integrationManager = fakeIntegrationManager([connection]);
  const env = buildGuestGitEnv({
    integrationManager,
    userId: 1,
    agentId: 'agent-a',
    runId: 'run-3',
    guestHost: '10.0.2.2',
    ttlMs: 60_000,
  });
  const capability = envConfig(env).at(-1)[1].split(': ')[1];

  const res = await request(proxyApp(integrationManager))
    .post('/api/git-proxy/github.com/owner/repo.git/git-receive-pack')
    .set('X-NeoAgent-Git-Capability', capability)
    .set('Content-Type', 'application/x-git-receive-pack-request')
    .send(Buffer.from([
      pkt(`${OLD_ID} ${NULL_ID} refs/heads/main\0report-status\n`),
      '0000',
    ].join('')))
    .buffer(true)
    .parse((response, callback) => {
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => callback(null, Buffer.concat(chunks)));
    });

  assert.equal(res.status, 200);
  assert.equal(res.headers['content-type'], 'application/x-git-receive-pack-result');
  assert.match(res.body.toString(), /ng refs\/heads\/main agents may not delete remote branches or tags/);
});

test('git proxy rejects paths that are not smart-HTTP repository endpoints', async () => {
  const integrationManager = fakeIntegrationManager([connection]);
  const env = buildGuestGitEnv({
    integrationManager,
    userId: 1,
    agentId: 'agent-a',
    runId: 'run-4',
    guestHost: '10.0.2.2',
    ttlMs: 60_000,
  });
  const capability = envConfig(env).at(-1)[1].split(': ')[1];

  const res = await request(proxyApp(integrationManager))
    .get('/api/git-proxy/github.com/owner/repo/settings')
    .set('X-NeoAgent-Git-Capability', capability);

  assert.equal(res.status, 404);
});
