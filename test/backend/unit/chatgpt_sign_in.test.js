'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const http = require('node:http');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

const ISSUER = 'https://auth.openai.com';
const CLIENT_ID = 'client_test_123';
const SUBJECT = 'user-abc';
const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const JWK = { ...publicKey.export({ format: 'jwk' }), kid: 'test-key', alg: 'RS256', use: 'sig' };

let ctx;
let db;
let manager;
let connections;
let getAiSettings;
let isSameMachineRequest;
let originalFetch;
const fakeOpenAI = { nonce: '', tokenRequests: [], revoked: [], accessTokenSerial: 0 };

function signIdToken(claims) {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const head = encode({ alg: 'RS256', kid: JWK.kid, typ: 'JWT' });
  const body = encode({
    iss: ISSUER,
    aud: CLIENT_ID,
    sub: SUBJECT,
    email: 'Neo@Example.com',
    email_verified: true,
    name: 'Neo',
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 600,
    ...claims,
  });
  const signature = crypto.sign('RSA-SHA256', Buffer.from(`${head}.${body}`), privateKey).toString('base64url');
  return `${head}.${body}.${signature}`;
}

function json(status, value) {
  return new Response(JSON.stringify(value), { status, headers: { 'content-type': 'application/json' } });
}

function tokenResponse(extra = {}) {
  fakeOpenAI.accessTokenSerial += 1;
  return {
    access_token: `access-${fakeOpenAI.accessTokenSerial}`,
    refresh_token: `refresh-${fakeOpenAI.accessTokenSerial}`,
    token_type: 'Bearer',
    expires_in: 3600,
    scope: 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct',
    ...extra,
  };
}

async function fakeFetch(input, init = {}) {
  const url = new URL(typeof input === 'string' ? input : input.url);
  const target = `${url.origin}${url.pathname}`;
  if (target === `${ISSUER}/.well-known/openid-configuration`) {
    return json(200, {
      issuer: ISSUER,
      authorization_endpoint: `${ISSUER}/api/accounts/authorize`,
      token_endpoint: `${ISSUER}/api/accounts/oauth/token`,
      revocation_endpoint: `${ISSUER}/api/accounts/oauth/revoke`,
      jwks_uri: `${ISSUER}/.well-known/jwks.json`,
    });
  }
  if (target === `${ISSUER}/.well-known/jwks.json`) return json(200, { keys: [JWK] });
  if (target === `${ISSUER}/api/accounts/oauth/token`) {
    const params = new URLSearchParams(String(init.body));
    fakeOpenAI.tokenRequests.push(Object.fromEntries(params));
    if (params.get('grant_type') === 'authorization_code') {
      return json(200, tokenResponse({ id_token: signIdToken({ nonce: fakeOpenAI.nonce }) }));
    }
    return json(200, tokenResponse({ id_token: signIdToken({}) }));
  }
  if (target === `${ISSUER}/api/accounts/oauth/revoke`) {
    fakeOpenAI.revoked.push(new URLSearchParams(String(init.body)).get('token'));
    return new Response('', { status: 200 });
  }
  if (target === 'https://api.openai.com/v1/models') {
    return json(200, {
      models: [
        { slug: 'gpt-hidden', display_name: 'Hidden', visibility: 'hide' },
        { slug: 'gpt-plan', display_name: 'GPT Plan', visibility: 'list' },
      ],
    });
  }
  return json(404, { error: 'not found' });
}

function requestLoopback(url, host) {
  return new Promise((resolve, reject) => {
    const target = new URL(url);
    const req = http.get({
      hostname: '127.0.0.1',
      port: target.port,
      path: `${target.pathname}${target.search}`,
      headers: { host: host || target.host },
    }, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
  });
}

before(() => {
  ctx = createTestRuntime();
  originalFetch = global.fetch;
  global.fetch = fakeFetch;
  db = require('../../../server/db/database');
  ({ AuthProviderManager: manager } = require('../../../server/services/account/auth_provider_manager'));
  manager = new manager();
  connections = require('../../../server/services/chatgpt/connections');
  ({ getAiSettings } = require('../../../server/services/ai/settings'));
  ({ isSameMachineRequest } = require('../../../server/utils/same_machine'));
});

after(() => {
  global.fetch = originalFetch;
  teardownTestRuntime(ctx);
});

test('same-machine detection requires a direct loopback client', () => {
  const request = (remoteAddress, headers) => ({ socket: { remoteAddress }, headers });
  assert.equal(isSameMachineRequest(request('127.0.0.1', { host: 'localhost:3333' })), true);
  assert.equal(isSameMachineRequest(request('::ffff:127.0.0.1', { host: '127.0.0.1:3333' })), true);
  assert.equal(isSameMachineRequest(request('::1', { host: '[::1]:3333' })), true);
  assert.equal(isSameMachineRequest(request('192.168.1.20', { host: 'localhost:3333' })), false);
  // A reverse proxy on the same host connects from loopback but forwards.
  assert.equal(isSameMachineRequest(request('127.0.0.1', { host: 'agent.example.com' })), false);
  assert.equal(isSameMachineRequest(request('127.0.0.1', { host: 'localhost', 'x-forwarded-for': '1.2.3.4' })), false);
});

test('ChatGPT sign-in is offered only to same-machine clients', async () => {
  const remote = manager.listProviders({ sameMachine: false }).find((provider) => provider.id === 'chatgpt');
  const local = manager.listProviders({ sameMachine: true }).find((provider) => provider.id === 'chatgpt');
  assert.equal(remote.configured, false);
  assert.equal(local.configured, true);
  await assert.rejects(
    manager.beginAuthorization({ providerKey: 'chatgpt', mode: 'login', context: { sameMachine: false } }),
    /only available when NeoAgent runs on this computer/,
  );
});

test('linking ChatGPT stores plan credentials, adopts its model, and unlinking releases both', async () => {
  const userId = Number(db.prepare(
    `INSERT INTO users (username, email, password, password_login_enabled) VALUES ('neo', 'neo@example.com', 'x', 1)`,
  ).run().lastInsertRowid);

  const begin = await manager.beginAuthorization({
    providerKey: 'chatgpt',
    mode: 'link',
    userId,
    context: { sameMachine: true },
  });
  const authorizeUrl = new URL(begin.url);
  assert.equal(authorizeUrl.origin + authorizeUrl.pathname, `${ISSUER}/api/accounts/authorize`);
  assert.equal(authorizeUrl.searchParams.get('client_id'), 'dynamic_agent_client');
  assert.equal(authorizeUrl.searchParams.get('agent_name_hint'), 'NeoAgent');
  assert.match(authorizeUrl.searchParams.get('scope'), /chatgpt\.tokens\.use\.direct/);
  const redirectUri = authorizeUrl.searchParams.get('redirect_uri');
  assert.match(redirectUri, /^http:\/\/127\.0\.0\.1:\d+\/auth\/callback$/);
  fakeOpenAI.nonce = authorizeUrl.searchParams.get('nonce');

  // A request with the wrong state must not consume the pending sign-in.
  const forged = await requestLoopback(`${redirectUri}?code=evil&state=auth_wrong&client_id=${CLIENT_ID}`);
  assert.equal(forged.status, 400);
  assert.equal(manager.consumeAuthorization(begin.state).status, 'pending');

  const callback = await requestLoopback(`${redirectUri}?code=code-1&state=${begin.state}&client_id=${CLIENT_ID}`);
  assert.equal(callback.status, 200);
  assert.match(callback.body, /You are signed in/);

  const completion = manager.consumeAuthorization(begin.state);
  assert.equal(completion.status, 'completed');
  assert.equal(completion.result.action, 'link');
  assert.equal(completion.result.email, 'neo@example.com');

  const exchange = fakeOpenAI.tokenRequests.find((request) => request.grant_type === 'authorization_code');
  assert.equal(exchange.client_id, CLIENT_ID);
  assert.equal(exchange.redirect_uri, redirectUri);
  assert.equal(exchange.resource, 'https://api.openai.com/v1');

  assert.equal(connections.getAccessToken(userId), 'access-1');
  const settings = getAiSettings(userId);
  assert.equal(settings.default_chat_model, 'chatgpt::gpt-plan');
  assert.equal(settings.default_subagent_model, 'chatgpt::gpt-plan');

  // The next sign-in on this install reuses the registered client.
  const second = await manager.beginAuthorization({
    providerKey: 'chatgpt',
    mode: 'login',
    context: { sameMachine: true },
  });
  const secondUrl = new URL(second.url);
  assert.equal(secondUrl.searchParams.get('client_id'), CLIENT_ID);
  assert.equal(secondUrl.searchParams.has('agent_name_hint'), false);

  const [link] = manager.listUserProviders(userId);
  assert.equal(link.provider, 'chatgpt');
  await manager.unlinkProvider(userId, link.id);
  assert.equal(connections.getAccessToken(userId), '');
  assert.deepEqual(fakeOpenAI.revoked, ['refresh-1']);
  assert.equal(getAiSettings(userId).default_chat_model, 'auto');
});

test('expired ChatGPT access tokens are refreshed once and persisted', async () => {
  const userId = Number(db.prepare(
    `INSERT INTO users (username, email, password, password_login_enabled) VALUES ('trinity', 't@example.com', 'x', 1)`,
  ).run().lastInsertRowid);
  connections.saveConnection(userId, {
    subject: SUBJECT,
    email: 't@example.com',
    clientId: CLIENT_ID,
    credentials: {
      accessToken: 'stale',
      refreshToken: 'refresh-stale',
      expiresAt: Date.now() - 1000,
      scopes: ['openid', 'chatgpt.tokens.use.direct'],
    },
  });
  const before = fakeOpenAI.tokenRequests.length;
  const [first, second] = await Promise.all([
    connections.getFreshAccessToken(userId),
    connections.getFreshAccessToken(userId),
  ]);
  assert.equal(first, second);
  assert.equal(fakeOpenAI.tokenRequests.length, before + 1);
  assert.equal(fakeOpenAI.tokenRequests.at(-1).refresh_token, 'refresh-stale');
  assert.equal(connections.getAccessToken(userId), first);
});
