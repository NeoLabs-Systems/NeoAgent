'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

// Regression coverage: POST /api/triggers/geofence used to read req.user.id,
// but req.user was never populated (no middleware set it), so every call
// threw and 500'd. It now reads req.session.userId, the canonical pattern
// used across the route layer.
describe('triggers geofence route', () => {
  let ctx;
  let app;
  let client;
  let user;

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    user = await createTestUser(ctx.db, { username: 'geofence_user' });
    client = agent(app);
    await loginAs(client, user);
  });

  after(() => teardownTestRuntime(ctx));

  test('authenticated geofence trigger returns 200, not 500', async () => {
    const res = await client
      .post('/api/triggers/geofence')
      .send({ label: 'Home', latitude: 37.77, longitude: -122.41, radius_meters: 100, action: 'remind' })
      .expect(200);
    assert.equal(res.body.success, true);
  });

  test('unauthenticated geofence trigger is rejected with 401', async () => {
    const anon = agent(app);
    await anon
      .post('/api/triggers/geofence')
      .send({ label: 'Home' })
      .expect(401);
  });
});
