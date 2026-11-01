'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

function seedRun(db, userId, { id, tool, stepStatus = 'completed' }) {
  db.prepare(`
    INSERT INTO agent_runs (id, user_id, title, status, total_tokens, created_at, completed_at)
    VALUES (?, ?, 'private title', 'completed', 100, datetime('now'), datetime('now', '+30 seconds'))
  `).run(id, userId);
  db.prepare(`
    INSERT INTO agent_steps (id, run_id, type, status, tool_name, tool_input)
    VALUES (?, ?, 'cli', ?, ?, 'secret input')
  `).run(`${id}_step`, id, stepStatus, tool);
}

test('consent defaults off, keeps only coarse client fields, and forgets them on opt-out', async () => {
  ctx = createTestRuntime();
  const sharing = require('../../../server/services/account/data_sharing');
  const { userId } = await createTestUser(ctx.db, { username: 'sharer' });

  assert.deepEqual(sharing.getDataSharing(userId), { enabled: false, since: null, client: null });
  assert.throws(() => sharing.setDataSharing(userId, { enabled: 'yes' }), /enabled must be/);

  const on = sharing.setDataSharing(userId, {
    enabled: true,
    client: { platform: 'Android', appVersion: '3.6.1-beta.50', deviceName: 'Pixel of Neo' },
  });
  assert.equal(on.enabled, true);
  assert.ok(on.since);
  assert.deepEqual(on.client, { platform: 'android', appVersion: '3.6.1-beta.50' });

  const updated = sharing.recordClientSnapshot(userId, { platform: 'toaster', appVersion: '<script>' });
  assert.deepEqual(updated.client, { platform: null, appVersion: null });
  assert.equal(updated.since, on.since);

  const off = sharing.setDataSharing(userId, { enabled: false });
  assert.deepEqual(off, { enabled: false, since: null, client: null });
  assert.deepEqual(
    sharing.recordClientSnapshot(userId, { platform: 'ios' }),
    { enabled: false, since: null, client: null },
  );
});

test('shared usage pools only opted-in accounts and carries no content', async () => {
  ctx = createTestRuntime();
  const { setDataSharing } = require('../../../server/services/account/data_sharing');
  const { getAnalytics } = require('../../../server/services/admin/analytics');
  const sharer = await createTestUser(ctx.db, { username: 'sharer' });
  const private_ = await createTestUser(ctx.db, { username: 'private' });

  assert.deepEqual(getAnalytics(30).sharedUsage, { participants: { sharing: 0, total: 2 } });

  setDataSharing(sharer.userId, { enabled: true, client: { platform: 'ios', appVersion: '1.2.3' } });
  ctx.db.prepare("INSERT INTO user_settings (user_id, key, value) VALUES (?, 'timezone', '\"Europe/Berlin\"')")
    .run(sharer.userId);
  seedRun(ctx.db, sharer.userId, { id: 'run_a', tool: 'execute_command', stepStatus: 'failed' });
  seedRun(ctx.db, sharer.userId, { id: 'run_b', tool: 'execute_command' });
  seedRun(ctx.db, private_.userId, { id: 'run_c', tool: 'browser_navigate' });

  const shared = getAnalytics(30).sharedUsage;
  assert.deepEqual(shared.participants, { sharing: 1, total: 2 });
  assert.deepEqual(shared.audience.platforms, [{ label: 'ios', count: 1 }]);
  assert.deepEqual(shared.audience.regions, [{ label: 'Europe', count: 1 }]);
  assert.deepEqual(shared.tools, [{ tool: 'execute_command', calls: 2, failures: 1 }]);
  assert.equal(shared.outcomes.runs, 2);
  assert.equal(shared.outcomes.avgDurationSeconds, 30);
  assert.equal(shared.activity.reduce((sum, cell) => sum + cell.runs, 0), 2);

  const serialized = JSON.stringify(shared);
  for (const leaked of ['private title', 'secret input', 'browser_navigate', 'sharer', 'Berlin']) {
    assert.equal(serialized.includes(leaked), false, `${leaked} must not appear`);
  }
});
