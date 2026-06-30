'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  chooseBrowserIdentity,
  detectBotChallenge,
  generateHumanMousePath,
  normalizeChallengeRetry,
  normalizeReferrerMode,
} = require('../../../server/services/browser/anti_detection');
const { executeTool, getAvailableTools } = require('../../../server/services/ai/tools');

test('chooseBrowserIdentity is stable and returns supported desktop dimensions', () => {
  const first = chooseBrowserIdentity('user-123');
  const second = chooseBrowserIdentity('user-123');
  assert.deepEqual(first, second);
  assert.match(first.userAgent, /Chrome\/13[45]\.0\.0\.0/);
  assert.ok(first.viewport.width >= 1280);
  assert.ok(first.viewport.height >= 720);
  assert.ok(['Win32', 'MacIntel', 'Linux x86_64'].includes(first.platform));
});

test('detectBotChallenge identifies common challenge pages', () => {
  assert.deepEqual(
    detectBotChallenge({ title: 'Just a moment...', html: '<html></html>' }),
    { detected: true, provider: 'cloudflare' },
  );
  assert.deepEqual(
    detectBotChallenge({ html: '<input name="cf-turnstile-response">' }),
    { detected: true, provider: 'cloudflare' },
  );
  assert.deepEqual(
    detectBotChallenge({ pageContent: 'Please verify you are a human before continuing.' }),
    { detected: true, provider: 'perimeterx' },
  );
  assert.deepEqual(
    detectBotChallenge({ title: 'Normal page', pageContent: 'Welcome back.' }),
    { detected: false, provider: null },
  );
});

test('generateHumanMousePath starts and ends at requested coordinates', () => {
  const path = generateHumanMousePath(
    { x: 10, y: 20 },
    { x: 400, y: 300 },
    { width: 800, height: 600 },
  );
  assert.ok(path.length >= 12);
  assert.deepEqual(path[0], { x: 10, y: 20 });
  assert.deepEqual(path[path.length - 1], { x: 400, y: 300 });
  for (const point of path) {
    assert.ok(Number.isFinite(point.x));
    assert.ok(Number.isFinite(point.y));
    assert.ok(point.x >= 0 && point.x <= 800);
    assert.ok(point.y >= 0 && point.y <= 600);
  }
});

test('navigation option normalization keeps safe defaults', () => {
  assert.equal(normalizeReferrerMode('google'), 'google');
  assert.equal(normalizeReferrerMode('current'), 'current');
  assert.equal(normalizeReferrerMode('invalid'), 'direct');
  assert.equal(normalizeReferrerMode(''), 'direct');
  assert.equal(normalizeChallengeRetry(false), false);
  assert.equal(normalizeChallengeRetry(undefined), true);
});

test('browser_navigate schema exposes anti-bot options', () => {
  const tools = getAvailableTools(null, {});
  const navigate = tools.find((tool) => tool.name === 'browser_navigate');
  assert.ok(navigate);
  assert.deepEqual(navigate.parameters.properties.referrerMode.enum, ['direct', 'google', 'current']);
  assert.equal(navigate.parameters.properties.challengeRetry.type, 'boolean');
});

test('browser_navigate forwards referrer and challenge retry options to provider', async () => {
  let captured = null;
  const provider = {
    async navigate(url, options) {
      captured = { url, options };
      return { success: true, url };
    },
  };
  const runtimeManager = {
    async getActiveBrowserBackend() {
      return 'vm';
    },
    async getBrowserProviderForUser() {
      return provider;
    },
  };

  const result = await executeTool('browser_navigate', {
    url: 'https://example.com/',
    referrerMode: 'google',
    challengeRetry: false,
    screenshot: false,
    waitFor: '#ready',
    fullPage: true,
  }, {
    userId: 7,
    app: { locals: { runtimeManager } },
  }, {});

  assert.equal(result.backend, 'vm');
  assert.equal(captured.url, 'https://example.com/');
  assert.equal(captured.options.referrerMode, 'google');
  assert.equal(captured.options.challengeRetry, false);
  assert.equal(captured.options.screenshot, false);
  assert.equal(captured.options.waitFor, '#ready');
  assert.equal(captured.options.fullPage, true);
});
