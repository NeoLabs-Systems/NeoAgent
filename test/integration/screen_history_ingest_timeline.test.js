'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

describe('screen history ingest and timeline routes', () => {
  let ctx;
  let app;
  let user;
  let otherUser;
  let client;
  let otherClient;
  let timelineService;

  function insertDevice(userId, {
    deviceId,
    activationId,
    label,
    passiveHistoryEnabled = true,
    revokedAt = null,
  }) {
    ctx.db.prepare(
      `INSERT INTO desktop_companion_devices (
         id, user_id, device_id, activation_id, label, companion_enabled, status,
         passive_history_enabled, revoked_at
       ) VALUES (?, ?, ?, ?, ?, 1, 'online', ?, ?)`
    ).run(
      crypto.randomUUID(),
      userId,
      deviceId,
      activationId,
      label,
      passiveHistoryEnabled ? 1 : 0,
      revokedAt,
    );
  }

  before(async () => {
    ctx = createTestRuntime();
    const { TimelineService } = require('../../server/services/timeline/service');
    const { DesktopCompanionRegistry } = require('../../server/services/desktop/registry');
    timelineService = new TimelineService({ db: ctx.db });
    app = createTestApp({
      locals: {
        timelineService,
        desktopCompanionRegistry: new DesktopCompanionRegistry({ db: ctx.db }),
      },
    }).app;
    user = await createTestUser(ctx.db, { username: 'timeline_user' });
    otherUser = await createTestUser(ctx.db, { username: 'timeline_other_user' });
    client = agent(app);
    otherClient = agent(app);
    await loginAs(client, user);
    await loginAs(otherClient, otherUser);
  });

  after(() => teardownTestRuntime(ctx));

  test('ingest writes raw screen history rows and grouped screen timeline sessions', async () => {
    insertDevice(user.userId, {
      deviceId: 'desktop-a',
      activationId: 'activation-a',
      label: 'Neo MacBook',
    });

    const res = await client
      .post('/api/screen-history/entries')
      .send({
        deviceId: 'desktop-a',
        activationId: 'activation-a',
        entries: [
          {
            capturedAt: '2026-06-23T09:00:00.000Z',
            frontmostApp: 'Cursor',
            windowTitle: 'NeoAgent',
            text: 'Reviewing the timeline implementation plan',
            ocrConfidence: 0.91,
          },
          {
            capturedAt: '2026-06-23T09:01:00.000Z',
            frontmostApp: 'Cursor',
            windowTitle: 'NeoAgent',
            text: 'Implementing screen history ingestion',
            ocrConfidence: 0.88,
          },
        ],
      })
      .expect(201);

    assert.equal(res.body.ok, true);
    assert.equal(res.body.insertedCount, 2);

    const rows = ctx.db.prepare(
      `SELECT device_id, device_label, app_name, window_title, captured_at, ocr_engine, ocr_confidence
       FROM screen_history
       WHERE user_id = ?
       ORDER BY captured_at ASC`
    ).all(user.userId);
    assert.equal(rows.length, 2);
    assert.equal(rows[0].device_id, 'desktop-a');
    assert.equal(rows[0].device_label, 'Neo MacBook');
    assert.equal(rows[0].app_name, 'Cursor');
    assert.equal(rows[0].window_title, 'NeoAgent');
    assert.equal(rows[0].ocr_engine, 'local_tesseract');

    const events = ctx.db.prepare(
      `SELECT source_kind, event_kind, metadata_json
       FROM timeline_events
       WHERE user_id = ?
       ORDER BY id ASC`
    ).all(user.userId);
    assert.equal(events.length, 1);
    assert.equal(events[0].source_kind, 'screen');
    assert.equal(events[0].event_kind, 'screen_session');
    const metadata = JSON.parse(events[0].metadata_json);
    assert.equal(metadata.deviceId, 'desktop-a');
    assert.equal(metadata.appName, 'Cursor');
    assert.equal(metadata.windowTitle, 'NeoAgent');
    assert.equal(metadata.entryCount, 2);

    const deviceRow = ctx.db.prepare(
      `SELECT passive_history_last_uploaded_at, passive_history_last_error
       FROM desktop_companion_devices
       WHERE user_id = ? AND device_id = ?`
    ).get(user.userId, 'desktop-a');
    assert.ok(deviceRow.passive_history_last_uploaded_at);
    assert.equal(deviceRow.passive_history_last_error, null);
  });

  test('ingest rejects mismatched, revoked, and disabled devices', async () => {
    insertDevice(user.userId, {
      deviceId: 'desktop-disabled',
      activationId: 'activation-disabled',
      label: 'Disabled Device',
      passiveHistoryEnabled: false,
    });
    insertDevice(user.userId, {
      deviceId: 'desktop-revoked',
      activationId: 'activation-revoked',
      label: 'Revoked Device',
      revokedAt: '2026-06-23T08:00:00.000Z',
    });

    await client
      .post('/api/screen-history/entries')
      .send({
        deviceId: 'desktop-a',
        activationId: 'wrong-activation',
        entries: [{ capturedAt: '2026-06-23T09:05:00.000Z', frontmostApp: 'Cursor', text: 'Bad auth' }],
      })
      .expect(403);

    await client
      .post('/api/screen-history/entries')
      .send({
        deviceId: 'desktop-disabled',
        activationId: 'activation-disabled',
        entries: [{ capturedAt: '2026-06-23T09:05:00.000Z', frontmostApp: 'Cursor', text: 'Disabled auth' }],
      })
      .expect(403);

    await client
      .post('/api/screen-history/entries')
      .send({
        deviceId: 'desktop-revoked',
        activationId: 'activation-revoked',
        entries: [{ capturedAt: '2026-06-23T09:05:00.000Z', frontmostApp: 'Cursor', text: 'Revoked auth' }],
      })
      .expect(403);
  });

  test('multiple devices can upload independently and timeline stays user-scoped', async () => {
    insertDevice(user.userId, {
      deviceId: 'desktop-b',
      activationId: 'activation-b',
      label: 'Neo ThinkPad',
    });
    insertDevice(otherUser.userId, {
      deviceId: 'desktop-other',
      activationId: 'activation-other',
      label: 'Other Device',
    });

    await client
      .post('/api/screen-history/entries')
      .send({
        deviceId: 'desktop-b',
        activationId: 'activation-b',
        entries: [{
          capturedAt: '2026-06-23T10:00:00.000Z',
          frontmostApp: 'Terminal',
          windowTitle: 'deploy',
          text: 'Running tests for the timeline feature',
        }],
      })
      .expect(201);

    await otherClient
      .post('/api/screen-history/entries')
      .send({
        deviceId: 'desktop-other',
        activationId: 'activation-other',
        entries: [{
          capturedAt: '2026-06-23T10:02:00.000Z',
          frontmostApp: 'Browser',
          windowTitle: 'Mail',
          text: 'Other user history',
        }],
      })
      .expect(201);

    timelineService.recordTaskLifecycle({
      userId: user.userId,
      taskId: 99,
      taskName: 'Nightly sync',
      eventKind: 'task_completed',
      occurredAt: '2026-06-23T10:03:00.000Z',
      runId: 'run-99',
      triggerType: 'schedule',
      triggerSource: 'schedule',
    });
    timelineService.recordRunLifecycle({
      userId: user.userId,
      runId: 'run-100',
      title: 'Implement timeline tab',
      eventKind: 'run_started',
      occurredAt: '2026-06-23T10:04:00.000Z',
      status: 'running',
      triggerSource: 'web',
    });
    timelineService.recordRunLifecycle({
      userId: otherUser.userId,
      runId: 'run-other',
      title: 'Other user run',
      eventKind: 'run_started',
      occurredAt: '2026-06-23T10:05:00.000Z',
      status: 'running',
      triggerSource: 'web',
    });

    const timelineRes = await client
      .get('/api/timeline')
      .query({ source: 'screen,tasks,runs', limit: 10 })
      .expect(200);
    assert.ok(Array.isArray(timelineRes.body.items));
    assert.equal(timelineRes.body.items.some((item) => item.title === 'Other user run'), false);
    assert.equal(timelineRes.body.items.some((item) => item.sourceKind === 'screen'), true);
    assert.equal(timelineRes.body.items.some((item) => item.sourceKind === 'tasks'), true);
    assert.equal(timelineRes.body.items.some((item) => item.sourceKind === 'runs'), true);

    const screenOnlyRes = await client
      .get('/api/timeline')
      .query({ source: 'screen', limit: 10 })
      .expect(200);
    assert.ok(screenOnlyRes.body.items.every((item) => item.sourceKind === 'screen'));
  });

  test('replayed passive-history batches are idempotent', async () => {
    insertDevice(user.userId, {
      deviceId: 'desktop-dedup',
      activationId: 'activation-dedup',
      label: 'Dedup Device',
    });

    const payload = {
      deviceId: 'desktop-dedup',
      activationId: 'activation-dedup',
      entries: [{
        capturedAt: '2026-06-23T10:30:00.000Z',
        frontmostApp: 'Browser',
        windowTitle: 'Docs',
        text: 'Reviewing the passive history dedup flow',
      }],
    };

    const first = await client
      .post('/api/screen-history/entries')
      .send(payload)
      .expect(201);
    const replay = await client
      .post('/api/screen-history/entries')
      .send(payload)
      .expect(201);

    assert.equal(first.body.insertedCount, 1);
    assert.equal(replay.body.insertedCount, 0);

    const rows = ctx.db.prepare(
      `SELECT COUNT(*) AS count
       FROM screen_history
       WHERE user_id = ? AND device_id = ? AND captured_at = ?`
    ).get(user.userId, 'desktop-dedup', '2026-06-23T10:30:00.000Z');
    assert.equal(rows.count, 1);

    const events = ctx.db.prepare(
      `SELECT COUNT(*) AS count
       FROM timeline_events
       WHERE user_id = ?
         AND source_kind = 'screen'
         AND json_extract(metadata_json, '$.deviceId') = ?
         AND json_extract(metadata_json, '$.startedAt') = ?`
    ).get(user.userId, 'desktop-dedup', '2026-06-23T10:30:00.000Z');
    assert.equal(events.count, 1);
  });

  test('screen history search returns expanded metadata fields', async () => {
    const res = await client
      .get('/api/screen-history/search')
      .query({ q: 'timeline', limit: 10 })
      .expect(200);

    assert.ok(Array.isArray(res.body.results));
    assert.ok(res.body.results.some((row) => row.deviceId === 'desktop-b'));
    const row = res.body.results.find((item) => item.deviceId === 'desktop-b');
    assert.equal(row.appName, 'Terminal');
    assert.equal(row.windowTitle, 'deploy');
    assert.equal(row.capturedAt, '2026-06-23T10:00:00.000Z');
  });

  test('screen session grouping does not merge across context switches back to the same app/window', () => {
    timelineService.storeScreenEntries({
      userId: user.userId,
      deviceId: 'desktop-a',
      deviceLabel: 'Neo MacBook',
      entries: [
        {
          capturedAt: '2026-06-23T11:00:00.000Z',
          frontmostApp: 'Cursor',
          windowTitle: 'NeoAgent',
          text: 'Session A1',
        },
        {
          capturedAt: '2026-06-23T11:01:00.000Z',
          frontmostApp: 'Terminal',
          windowTitle: 'deploy',
          text: 'Session B1',
        },
        {
          capturedAt: '2026-06-23T11:02:00.000Z',
          frontmostApp: 'Cursor',
          windowTitle: 'NeoAgent',
          text: 'Session A2',
        },
      ],
    });

    const rows = ctx.db.prepare(
      `SELECT title, metadata_json
       FROM timeline_events
       WHERE user_id = ? AND source_kind = 'screen'
       AND occurred_at >= '2026-06-23T11:00:00.000Z'
       ORDER BY occurred_at ASC, id ASC`
    ).all(user.userId);

    assert.equal(rows.length, 3);
    assert.deepEqual(
      rows.map((row) => JSON.parse(row.metadata_json).entryCount),
      [1, 1, 1],
    );
    assert.deepEqual(
      rows.map((row) => row.title),
      ['Cursor · NeoAgent', 'Terminal · deploy', 'Cursor · NeoAgent'],
    );
  });
});
