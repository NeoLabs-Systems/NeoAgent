'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const supertest = require('supertest');

const { createTestApp, loginAs } = require('../../helpers/app');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

function loadSocialReach() {
  return require('../../../server/services/social_reach/service');
}

test('social reach status only exposes working consumer-facing platforms', async () => {
  const ctx = createTestRuntime();
  const { SocialReachService } = loadSocialReach();
  const service = new SocialReachService();
  try {
    const status = await service.getStatus(1);
    const platforms = new Map(status.platforms.map((item) => [item.platform, item]));

    assert.equal(platforms.get('rss').status, 'ok');
    assert.equal(platforms.get('v2ex').status, 'ok');
    assert.equal(platforms.get('reddit').status, 'ok');
    assert.equal(platforms.get('x').status, 'ok');
    assert.equal(platforms.has('web'), false);
    assert.equal(platforms.has('linkedin'), false);
    assert.equal(platforms.has('twitter'), false);
    assert.equal(platforms.has('instagram'), false);
    assert.equal(status.platforms.some((item) => item.setupKind === 'unsupported_node_only'), false);
    assert.equal(JSON.stringify(status).includes('not implemented'), false);
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

test('social reach routes social video platforms through the existing extractor', async () => {
  const ctx = createTestRuntime();
  const { SocialReachService } = loadSocialReach();
  const calls = [];
  const service = new SocialReachService({
    socialVideoService: {
      async getHealthStatus() {
        return { ready: true, dependencies: [] };
      },
      async extractFromUrl(userId, url, options) {
        calls.push({ userId, url, options });
        return { platform: 'tiktok', title: 'Video title', transcript: 'Video transcript' };
      },
    },
  });
  try {
    const result = await service.read(7, {
      platform: 'tiktok',
      url: 'https://www.tiktok.com/@neo/video/123',
      include_frame: false,
    });
    assert.equal(result.platform, 'social_video');
    assert.equal(result.videoPlatform, 'tiktok');
    assert.equal(result.title, 'Video title');
    assert.equal(calls.length, 1);
    assert.equal(calls[0].userId, 7);
    assert.equal(calls[0].options.includeFrame, false);
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('social reach reads reddit public JSON posts and comments', async () => {
  const ctx = createTestRuntime();
  const { SocialReachService } = loadSocialReach();
  const originalFetch = global.fetch;
  global.fetch = async (url) => ({
    ok: true,
    status: 200,
    async text() {
      assert.match(String(url), /reddit\.com\/r\/neoagent\/comments\/abc123\/post\.json/);
      return JSON.stringify([
        {
          data: {
            children: [{
              kind: 't3',
              data: {
                id: 'abc123',
                title: 'NeoAgent post',
                subreddit: 'neoagent',
                author: 'neo',
                selftext: 'Body',
                permalink: '/r/neoagent/comments/abc123/post/',
                score: 42,
                num_comments: 2,
                created_utc: 1700000000,
              },
            }],
          },
        },
        {
          data: {
            children: [{
              kind: 't1',
              data: {
                id: 'c1',
                author: 'reader',
                body: 'Comment body',
                score: 3,
                created_utc: 1700000100,
              },
            }],
          },
        },
      ]);
    },
  });
  const service = new SocialReachService();
  try {
    const result = await service.read(1, {
      url: 'https://www.reddit.com/r/neoagent/comments/abc123/post/?utm_source=x',
    });
    assert.equal(result.platform, 'reddit');
    assert.equal(result.post.title, 'NeoAgent post');
    assert.equal(result.comments[0].text, 'Comment body');
  } finally {
    global.fetch = originalFetch;
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
