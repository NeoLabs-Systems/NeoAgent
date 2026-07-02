'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const supertest = require('supertest');

const { createTestApp, loginAs } = require('../../helpers/app');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

function loadSocialReach() {
  return require('../../../server/services/social_reach/service');
}

test('social reach status includes ready native and unsupported node-only platforms', async () => {
  const ctx = createTestRuntime();
  const { SocialReachService } = loadSocialReach();
  const service = new SocialReachService();
  try {
    const status = await service.getStatus(1);
    const platforms = new Map(status.platforms.map((item) => [item.platform, item]));

    assert.equal(platforms.get('web').status, 'ok');
    assert.equal(platforms.get('rss').status, 'ok');
    assert.equal(platforms.get('v2ex').status, 'ok');
    assert.equal(platforms.get('twitter').status, 'off');
    assert.equal(platforms.get('twitter').setupKind, 'unsupported_node_only');
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('social reach cookie sanitizer keeps only allowlisted platform domains', () => {
  const ctx = createTestRuntime();
  const { sanitizeCookies } = loadSocialReach();
  const cookies = sanitizeCookies([
    { name: 'xq_a_token', value: 'keep', domain: '.xueqiu.com', path: '/', secure: true },
    { name: 'sub', value: 'keep2', domain: 'stock.xueqiu.com', path: '/', secure: true },
    { name: 'sid', value: 'drop', domain: '.evil.example', path: '/', secure: true },
    { name: '', value: 'drop', domain: '.xueqiu.com', path: '/', secure: true },
  ], ['xueqiu.com']);

  assert.deepEqual(cookies.map((cookie) => cookie.name), ['xq_a_token', 'sub']);
  assert.equal(cookies[0].value, 'keep');
  teardownTestRuntime(ctx);
});

test('social reach unsupported platforms fail explicitly', async () => {
  const ctx = createTestRuntime();
  const { SocialReachService } = loadSocialReach();
  const service = new SocialReachService();
  try {
    await assert.rejects(
      () => service.search(1, { platform: 'instagram', query: 'neoagent' }),
      /not implemented under the Node-only constraint/i,
    );
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('social reach cookie bundles are encrypted at rest', async () => {
  const ctx = createTestRuntime();
  const { readCookieBundle, writeCookieBundle } = require('../../../server/services/social_reach/store');
  try {
    const user = await createTestUser(ctx.db, { username: 'social_reach_cookie_encrypted' });
    writeCookieBundle(user.userId, 'xueqiu', {
      cookies: [{ name: 'xq_a_token', value: 'secret-cookie-value', domain: '.xueqiu.com', path: '/' }],
    });
    const row = ctx.db.prepare(
      'SELECT value FROM user_settings WHERE user_id = ? AND key = ?',
    ).get(user.userId, 'social_reach_cookies_xueqiu');

    assert.match(row.value, /^enc:v1:/);
    assert.equal(row.value.includes('secret-cookie-value'), false);
    assert.equal(readCookieBundle(user.userId, 'xueqiu').cookies[0].value, 'secret-cookie-value');
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('generic settings routes cannot write social reach cookie secrets', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'social_reach_cookie_settings' });
    const { app } = createTestApp();
    const client = supertest.agent(app);
    await loginAs(client, user);

    const single = await client
      .put('/api/settings/social_reach_cookies_xueqiu')
      .send({ value: { cookies: [{ name: 'xq_a_token', value: 'plain' }] } });
    assert.equal(single.statusCode, 403);

    const batch = await client
      .put('/api/settings')
      .send({ social_reach_cookies_xueqiu: { cookies: [{ name: 'xq_a_token', value: 'plain' }] } });
    assert.equal(batch.statusCode, 200);
    const row = ctx.db.prepare(
      'SELECT value FROM user_settings WHERE user_id = ? AND key = ?',
    ).get(user.userId, 'social_reach_cookies_xueqiu');
    assert.equal(row, undefined);
  } finally {
    teardownTestRuntime(ctx);
  }
});
