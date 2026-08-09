'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  getGrokOAuthTokenExpiresAt,
  GrokOAuthProvider,
  isGrokAuthenticationError,
  refreshGrokOAuthAccessToken,
} = require('../../../server/services/ai/providers/grokOauth');

function jwtWithExpiry(expiresAtSeconds) {
  const header = Buffer.from(JSON.stringify({ alg: 'none' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({ exp: expiresAtSeconds })).toString('base64url');
  return `${header}.${payload}.signature`;
}

function successfulChatResponse() {
  return {
    choices: [{ message: { content: 'ok' }, finish_reason: 'stop' }],
  };
}

test('Grok OAuth expiry prefers the access-token JWT and accepts OAuth expiry metadata', () => {
  const jwtExpiry = Math.floor(Date.now() / 1000) + 3600;
  assert.equal(
    getGrokOAuthTokenExpiresAt(jwtWithExpiry(jwtExpiry), { expires_in: 1 }),
    jwtExpiry * 1000,
  );

  const before = Date.now();
  const metadataExpiry = getGrokOAuthTokenExpiresAt('opaque-token', { expires_in: '3600' });
  assert.ok(metadataExpiry >= before + 3_600_000);
  assert.ok(metadataExpiry <= Date.now() + 3_600_000);
});

test('Grok OAuth does not pair a scoped access token with runtime refresh credentials', () => {
  const previousAccess = process.env.GROK_OAUTH_ACCESS_TOKEN;
  const previousRefresh = process.env.GROK_OAUTH_REFRESH_TOKEN;
  const previousExpiry = process.env.GROK_OAUTH_EXPIRES_AT;
  process.env.GROK_OAUTH_ACCESS_TOKEN = 'runtime-access-token';
  process.env.GROK_OAUTH_REFRESH_TOKEN = 'runtime-refresh-token';
  process.env.GROK_OAUTH_EXPIRES_AT = String(Date.now() + 60_000);

  try {
    const scopedExpiry = Math.floor(Date.now() / 1000) + 3600;
    const provider = new GrokOAuthProvider({ apiKey: jwtWithExpiry(scopedExpiry) });
    assert.equal(provider.refreshToken, null);
    assert.equal(provider.tokenExpiresAt, scopedExpiry * 1000);
    assert.equal(provider.usesRuntimeCredentials, false);
  } finally {
    if (previousAccess === undefined) delete process.env.GROK_OAUTH_ACCESS_TOKEN;
    else process.env.GROK_OAUTH_ACCESS_TOKEN = previousAccess;
    if (previousRefresh === undefined) delete process.env.GROK_OAUTH_REFRESH_TOKEN;
    else process.env.GROK_OAUTH_REFRESH_TOKEN = previousRefresh;
    if (previousExpiry === undefined) delete process.env.GROK_OAUTH_EXPIRES_AT;
    else process.env.GROK_OAUTH_EXPIRES_AT = previousExpiry;
  }
});

test('Grok OAuth refresh normalizes expiry returned by the token endpoint', async () => {
  const before = Date.now();
  const refreshed = await refreshGrokOAuthAccessToken(
    'refresh-token',
    async () => new Response(JSON.stringify({
      access_token: 'new-access-token',
      refresh_token: 'new-refresh-token',
      expires_in: 3600,
    }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    }),
  );

  assert.equal(refreshed.access, 'new-access-token');
  assert.equal(refreshed.refresh, 'new-refresh-token');
  assert.ok(refreshed.expires >= before + 3_600_000);
  assert.ok(refreshed.expires <= Date.now() + 3_600_000);
});

test('Grok OAuth refreshes proactively before an expiring token is used', async () => {
  const provider = new GrokOAuthProvider({
    apiKey: jwtWithExpiry(Math.floor(Date.now() / 1000) + 60),
    refreshToken: 'refresh-token',
  });
  const calls = [];
  provider.refreshClient = async () => {
    calls.push('refresh');
    provider.authToken = 'fresh-access-token';
    provider.tokenExpiresAt = Date.now() + 3_600_000;
    return true;
  };
  provider.client = {
    chat: {
      completions: {
        create: async () => {
          calls.push('chat');
          return successfulChatResponse();
        },
      },
    },
  };

  const response = await provider.chat([{ role: 'user', content: 'Hello' }]);
  assert.equal(response.content, 'ok');
  assert.deepEqual(calls, ['refresh', 'chat']);
});

test('Grok OAuth refreshes proactively before model discovery', async () => {
  const provider = new GrokOAuthProvider({
    apiKey: jwtWithExpiry(Math.floor(Date.now() / 1000) + 60),
    refreshToken: 'refresh-token',
  });
  const calls = [];
  provider.refreshClient = async () => {
    calls.push('refresh');
    provider.authToken = 'fresh-access-token';
    provider.tokenExpiresAt = Date.now() + 3_600_000;
    return true;
  };
  provider.client = {
    models: {
      list: async () => {
        calls.push('models');
        return { data: [{ id: 'grok-4.5' }] };
      },
    },
  };

  assert.deepEqual(await provider.listModels(), [{ id: 'grok-4.5', name: 'grok-4.5' }]);
  assert.deepEqual(calls, ['refresh', 'models']);
});

test('Grok OAuth refreshes and retries structured early-invalidated credentials once', async () => {
  const provider = new GrokOAuthProvider({
    apiKey: jwtWithExpiry(Math.floor(Date.now() / 1000) + 3600),
    refreshToken: 'refresh-token',
  });
  let chatCalls = 0;
  let refreshCalls = 0;
  provider.refreshClient = async () => {
    refreshCalls += 1;
    provider.authToken = 'fresh-access-token';
    provider.tokenExpiresAt = Date.now() + 3_600_000;
    return true;
  };
  provider.client = {
    chat: {
      completions: {
        create: async () => {
          chatCalls += 1;
          if (chatCalls === 1) {
            throw Object.assign(new Error('credential rejected'), {
              status: 403,
              code: 'unauthenticated:bad-credentials',
            });
          }
          return successfulChatResponse();
        },
      },
    },
  };

  const response = await provider.chat([{ role: 'user', content: 'Hello' }]);
  assert.equal(response.content, 'ok');
  assert.equal(refreshCalls, 1);
  assert.equal(chatCalls, 2);
});

test('Grok OAuth does not refresh for unrelated forbidden responses', async () => {
  const error = Object.assign(new Error('forbidden'), {
    status: 403,
    code: 'permission_denied',
  });
  assert.equal(isGrokAuthenticationError(error), false);

  const provider = new GrokOAuthProvider({
    apiKey: jwtWithExpiry(Math.floor(Date.now() / 1000) + 3600),
    refreshToken: 'refresh-token',
  });
  let refreshCalls = 0;
  provider.refreshClient = async () => {
    refreshCalls += 1;
    return true;
  };
  provider.client = {
    chat: {
      completions: {
        create: async () => { throw error; },
      },
    },
  };

  await assert.rejects(
    provider.chat([{ role: 'user', content: 'Hello' }]),
    (caught) => caught === error,
  );
  assert.equal(refreshCalls, 0);
});
