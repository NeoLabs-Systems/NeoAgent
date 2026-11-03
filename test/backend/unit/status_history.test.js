'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createStatusHistory } = require('../../../server/status_history');

test('history stores the worst observation per hour and leaves gaps unknown', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'status-history-'));
  let now = Date.UTC(2026, 0, 3, 12, 15);
  try {
    const store = createStatusHistory({ directory: dir, clock: () => now });
    assert.ok(store.history().every((entry) => entry.status === null));
    store.record('operational');
    store.record('degraded');
    store.record('operational');
    now += 2 * 60 * 60 * 1000;
    store.record('operational');
    const reopened = createStatusHistory({ directory: dir, clock: () => now }).history();
    assert.equal(reopened.length, 48);
    assert.deepEqual(reopened.slice(-3).map((entry) => entry.status), ['degraded', null, 'operational']);
    now += 49 * 60 * 60 * 1000;
    store.record('operational');
    assert.equal(JSON.parse(fs.readFileSync(path.join(dir, 'public-status-history.json'), 'utf8')).length, 1);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('unwritable history does not interrupt sampling', () => {
  const store = createStatusHistory({ directory: '/dev/null/status-history' });
  assert.doesNotThrow(() => store.record('operational'));
  assert.ok(store.history().every((entry) => entry.status === null));
});
