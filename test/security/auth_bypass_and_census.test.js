'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../helpers/db');
const { createTestApp } = require('../helpers/app');
const { request } = require('../helpers/supertest');
const { discoverApiRoutes } = require('../helpers/route_census');

const PUBLIC_ROUTES = new Set([
  'GET /api/auth/status',
  'GET /api/auth/providers',
  'GET /api/auth/providers/complete',
  'GET /api/auth/email/confirm',
  'GET /api/auth/password/reset',
  'GET /api/browser-extension/latest',
  'GET /api/runtime/config',
  'GET /api/settings/meta/models',
  'GET /api/settings/meta/ai-providers',
  'GET /api/wearable/timezone',
  'GET /api/wearable/bootstrap',
  'GET /api/wearable/firmware/manifest',
  'POST /api/auth/login',
  'POST /api/auth/login/2fa',
  'POST /api/auth/logout',
  'POST /api/auth/password/forgot',
  'POST /api/auth/password/reset',
  'POST /api/auth/providers/:provider/begin',
  'POST /api/auth/qr-login/challenge',
  'POST /api/auth/qr-login/challenge/:id/status',
  'POST /api/auth/qr-login/challenge/:id/claim',
  'POST /api/auth/register',
  'POST /api/browser-extension/pairing/request',
  'POST /api/browser-extension/pairing/:pairingId/claim',
  'POST /api/messaging/webhook/:platform',
  'POST /api/telnyx/webhook',
]);

const INTENTIONALLY_UNTESTED = new Map([
  ['GET /api/integrations/oauth/callback', 'OAuth callback depends on provider state.'],
  ['GET /api/integrations/qr-image', 'QR image generation is covered by integration service tests.'],
  ['GET /api/integrations/:provider/connect/:sessionId', 'OAuth popup HTML flow.'],
  ['GET /api/integrations/:provider/connect/:sessionId/status', 'OAuth popup polling flow.'],
  ['GET /api/mcp/oauth/callback', 'OAuth callback depends on provider state.'],
  ['GET /api/recordings/:sessionId/audio/:sourceKey', 'Binary audio response route.'],
  ['POST /api/android/install-apk', 'Multipart upload route.'],
  ['POST /api/recordings/:sessionId/chunks', 'Raw body chunk upload route.'],
  ['POST /api/voice-assistant/transcribe', 'Multipart audio upload route.'],
]);

function concrete(route) {
  return route
    .replace(/:id/g, '999999')
    .replace(/:provider/g, 'test-provider')
    .replace(/:platform/g, 'telegram')
    .replace(/:sessionId/g, 'missing-session')
    .replace(/:segmentId/g, '999999')
    .replace(/:sourceKey/g, 'mic')
    .replace(/:key/g, 'default_chat_model')
    .replace(/:service/g, 'openai')
    .replace(/:name/g, 'missing-skill')
    .replace(/:pairingId/g, 'missing-pairing');
}

function classify(route) {
  if (PUBLIC_ROUTES.has(route)) return 'public';
  if (INTENTIONALLY_UNTESTED.has(route)) return 'intentionally-untested';
  if (route.includes('/webhook')) return 'webhook';
  return 'protected';
}

describe('route census and auth bypass coverage', () => {
  let ctx;
  let app;

  before(() => {
    ctx = createTestRuntime();
    app = createTestApp().app;
  });

  after(() => teardownTestRuntime(ctx));

  test('every discovered API route is classified', () => {
    const routes = discoverApiRoutes();
    assert.ok(routes.length > 100);
    const classifications = routes.map((route) => [route, classify(route)]);
    assert.equal(classifications.every(([, value]) => Boolean(value)), true);
    assert.equal(classifications.some(([, value]) => value === 'protected'), true);
    assert.equal(classifications.some(([, value]) => value === 'public'), true);
  });

  test('protected API routes reject unauthenticated requests before route logic', async () => {
    const protectedRoutes = discoverApiRoutes()
      .filter((route) => classify(route) === 'protected')
      .filter((route) => !route.includes('/artifacts/'));

    for (const route of protectedRoutes) {
      const [method, pattern] = route.split(' ');
      const res = await request(app)[method.toLowerCase()](concrete(pattern)).send({});
      assert.equal(res.statusCode, 401, `${route} returned ${res.statusCode}: ${res.text.slice(0, 120)}`);
      assert.match(res.text, /Unauthorized|Not authenticated|Session invalid/);
    }
  });
});
