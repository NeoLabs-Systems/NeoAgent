'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  expiresAtFromSeconds,
  tokenExpiresSoon,
  withRefreshedOAuthCredentials,
} = require('../../../server/services/integrations/oauth_tokens');
const { buildPinnedApiUrl } = require('../../../server/services/integrations/oauth_provider');

test('expiresAtFromSeconds defaults invalid values and can return null', () => {
  const iso = expiresAtFromSeconds('3600');
  const parsed = Date.parse(iso);
  assert.equal(Number.isFinite(parsed), true);
  assert.ok(parsed > Date.now() + 3500 * 1000);
  assert.equal(expiresAtFromSeconds('nope', { ifInvalid: 'null' }), null);
});

test('tokenExpiresSoon uses a one-minute skew', () => {
  assert.equal(tokenExpiresSoon({ expires_at: new Date(Date.now() + 30_000).toISOString() }), true);
  assert.equal(tokenExpiresSoon({ expires_at: new Date(Date.now() + 120_000).toISOString() }), false);
});

test('withRefreshedOAuthCredentials refreshes before expiry and after 401', async () => {
  const calls = [];
  let refreshCount = 0;
  const context = {
    credentials: {
      access_token: 'old',
      refresh_token: 'refresh',
      expires_at: new Date(Date.now() + 10_000).toISOString(),
    },
    signal: null,
    updateCredentials(next) {
      context.credentials = next;
    },
  };
  const result = await withRefreshedOAuthCredentials(context, {
    refresh: async (credentials) => {
      calls.push('refresh');
      refreshCount += 1;
      return { ...credentials, access_token: `next-${refreshCount}` };
    },
    request: async (credentials) => {
      calls.push(`request:${credentials.access_token}`);
      if (credentials.access_token === 'next-1') {
        const error = new Error('expired');
        error.status = 401;
        throw error;
      }
      return { ok: true, token: credentials.access_token };
    },
  });
  assert.deepEqual(calls, ['refresh', 'request:next-1', 'refresh', 'request:next-2']);
  assert.deepEqual(result, { ok: true, token: 'next-2' });
  assert.equal(context.credentials.access_token, 'next-2');
});

test('buildPinnedApiUrl rejects hosts outside the pinned API origin', () => {
  const url = buildPinnedApiUrl('api.figma.com', '/v1/me', { ids: '1' });
  assert.equal(url.hostname, 'api.figma.com');
  assert.equal(url.searchParams.get('ids'), '1');
  assert.throws(
    () => buildPinnedApiUrl('api.figma.com', 'https://evil.example/steal'),
    /must target api.figma.com/,
  );
});
