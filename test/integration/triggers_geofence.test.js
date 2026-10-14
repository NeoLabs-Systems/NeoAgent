'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { EventEmitter } = require('node:events');

const { attachTriggerEventSources } = require('../../server/services/tasks/trigger_events');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

// A small task runtime: the real event dispatcher over fixed tasks, recording
// what it fires.
function eventTaskRuntime(tasks) {
  const runtime = {
    fired: [],
    stopping: false,
    events: new EventEmitter(),
    app: { locals: {} },
    publishEvent(name, event) {
      runtime.events.emit(name, event);
    },
    taskRepository: {
      listEnabledEventTasks(userId, _agentId, triggerType) {
        return tasks().filter((task) => task.user_id === userId && task.trigger_type === triggerType);
      },
    },
    async fireTaskFromTrigger(taskId, _userId, payload) {
      runtime.fired.push({ taskId, payload });
      return {};
    },
  };
  attachTriggerEventSources(runtime);
  return runtime;
}

async function waitForFired(runtime, count) {
  for (let attempt = 0; attempt < 50 && runtime.fired.length < count; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

describe('triggers geofence route', () => {
  let ctx;
  let app;
  let client;
  let user;
  let runtime;

  before(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db, { username: 'geofence_user' });
    const fence = (id, transition) => ({
      id,
      user_id: user.userId,
      trigger_type: 'geofence_event',
      trigger_config: JSON.stringify({ label: 'Home', latitude: 37.77, longitude: -122.41, radiusMeters: 100, transition }),
    });
    runtime = eventTaskRuntime(() => [fence(11, 'enter'), fence(12, 'exit')]);
    app = createTestApp({ locals: { taskRuntime: runtime } }).app;
    client = agent(app);
    await loginAs(client, user);
  });

  after(() => teardownTestRuntime(ctx));

  test('the fences are the enabled geofence tasks', async () => {
    const res = await client.get('/api/triggers/geofences').expect(200);
    assert.deepEqual(res.body.geofences.map((fence) => [fence.id, fence.label, fence.radius_meters]), [
      [11, 'Home', 100],
      [12, 'Home', 100],
    ]);
  });

  test('entering a fence fires the task watching that fence and transition', async () => {
    const res = await client
      .post('/api/triggers/geofence')
      .send({ fence_id: 11, transition: 'enter', latitude: 37.77, longitude: -122.41 })
      .expect(200);
    assert.equal(res.body.success, true);
    await waitForFired(runtime, 1);
    assert.deepEqual(runtime.fired.map((entry) => entry.taskId), [11]);
    assert.equal(runtime.fired[0].payload.context.triggerEvent.event, 'geofence_entered');
  });

  test('a geofence report without a fence is rejected', async () => {
    await client.post('/api/triggers/geofence').send({ transition: 'enter' }).expect(400);
  });

  test('unauthenticated geofence trigger is rejected with 401', async () => {
    const anon = agent(app);
    await anon
      .post('/api/triggers/geofence')
      .send({ fence_id: 11 })
      .expect(401);
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
  let runtime;

  const notification = {
    app_package: 'com.example.chat',
    title: 'New message',
    body: 'Hello there',
    action_taken: 'none',
  };

  async function postNotification() {
    const before = runtime.fired.length;
    await client.post('/api/triggers/notification').send(notification).expect(200);
    // The route answers before running the trigger, so wait for the fan-out.
    await waitForFired(runtime, before + 1);
    return runtime.fired[before]?.payload || null;
  }

  before(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db, { username: 'notification_user' });
    runtime = eventTaskRuntime(() => [{
      id: 1,
      user_id: user.userId,
      trigger_type: 'android_notification_received',
      trigger_config: '{}',
    }]);
    app = createTestApp({ locals: { taskRuntime: runtime } }).app;
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
