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

  test('authenticated geofence list returns the user fences', async () => {
    ctx.db.prepare(`
      INSERT INTO geofences (user_id, label, latitude, longitude, radius_meters, trigger_action)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(user.userId, 'Home', 37.77, -122.41, 100, 'remind');
    const res = await client.get('/api/triggers/geofences').expect(200);
    assert.equal(res.body.geofences.length, 1);
    assert.equal(res.body.geofences[0].label, 'Home');
  });
});

// Regression coverage: the Android notification trigger used to build its
// fingerprint from Date.now() plus Math.random(), so the de-duplication in
// TaskRuntime.fireTaskFromTrigger could never match and a retried delivery
// fired the task a second time. The fingerprint now identifies the event.
describe('triggers notification route', () => {
  let ctx;
  let app;
  let client;
  let user;
  let fired;

  const notification = {
    app_package: 'com.example.chat',
    title: 'New message',
    body: 'Hello there',
    action_taken: 'none',
  };

  async function postNotification() {
    await client.post('/api/triggers/notification').send(notification).expect(200);
    // The route answers before running the trigger, so wait for the fan-out.
    for (let attempt = 0; attempt < 50 && fired.length === 0; attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 10));
    }
    return fired.shift() || null;
  }

  before(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db, { username: 'notification_user' });
    fired = [];
    app = createTestApp({
      locals: {
        taskRuntime: {
          taskRepository: {
            listEnabledByTriggerTypes: () => [{
              id: 1,
              user_id: user.userId,
              trigger_config: '{}',
            }],
          },
          fireTaskFromTrigger: async (taskId, userId, payload) => {
            fired.push(payload);
          },
        },
      },
    }).app;
    client = agent(app);
    await loginAs(client, user);
  });

  after(() => teardownTestRuntime(ctx));

  test('the same notification delivered twice yields the same fingerprint', async () => {
    const first = await postNotification();
    const second = await postNotification();
    assert.ok(first, 'first delivery should fire the task');
    assert.ok(second, 'second delivery should fire the task');
    assert.equal(first.fingerprint, second.fingerprint);
  });

  test('a different notification yields a different fingerprint', async () => {
    const baseline = await postNotification();
    notification.body = 'A different body';
    const changed = await postNotification();
    assert.notEqual(baseline.fingerprint, changed.fingerprint);
  });
});
