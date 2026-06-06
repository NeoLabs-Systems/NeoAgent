'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  ScreenRecorder,
  hasOpenConnectionForUser,
} = require('../../../server/services/desktop/screenRecorder');

function deferred() {
  let resolve;
  const promise = new Promise((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function createHarness(options = {}) {
  const writes = [];
  const cleanupModifiers = [];
  const execCalls = [];
  const timers = [];
  const clearedTimers = [];
  let active = options.active ?? false;
  const ownerUserId = options.ownerUserId ?? 42;
  const existingUserIds = new Set(options.existingUserIds || [ownerUserId]);

  const fakeDb = {
    prepare(sql) {
      if (sql.includes('SELECT id FROM users WHERE id = ?')) {
        return {
          get(userId) {
            return existingUserIds.has(userId) ? { id: userId } : undefined;
          },
        };
      }
      if (sql.includes('INSERT INTO screen_history')) {
        return {
          run(...args) {
            writes.push(args);
            return { changes: 1 };
          },
        };
      }
      if (sql.includes('DELETE FROM screen_history')) {
        return {
          run(modifier) {
            cleanupModifiers.push(modifier);
            return { changes: 0 };
          },
        };
      }
      throw new Error(`Unexpected SQL in screen recorder test: ${sql}`);
    },
  };

  const recorder = new ScreenRecorder({
    env: {
      NEOAGENT_SCREEN_RECORDER_ENABLED: 'true',
      NEOAGENT_SCREEN_RECORDER_USER_ID: String(ownerUserId),
      ...options.env,
    },
    platform: options.platform || 'darwin',
    db: fakeDb,
    fs: {
      async access() {},
      async unlink() {},
    },
    async execFile(command, args) {
      execCalls.push([command, args]);
      if (command === 'osascript') {
        return { stdout: 'Terminal\n' };
      }
      return { stdout: '' };
    },
    recognize: options.recognize || (async () => ({
      data: { text: 'Meaningful captured text' },
    })),
    setInterval(callback, delay) {
      const timer = { callback, delay, unref() {} };
      timers.push(timer);
      return timer;
    },
    clearInterval(timer) {
      clearedTimers.push(timer);
    },
    hasActiveCaptureSessionForUser(userId) {
      assert.equal(userId, ownerUserId);
      return active;
    },
    tempFilePath: '/tmp/neoagent-screen-test.png',
    now: options.now || (() => Date.UTC(2026, 5, 6)),
  });

  return {
    recorder,
    writes,
    cleanupModifiers,
    execCalls,
    timers,
    clearedTimers,
    setActive(value) {
      active = value;
    },
  };
}

test('screen recorder is opt-in and reports unsupported platforms truthfully', async () => {
  const disabled = createHarness({
    env: { NEOAGENT_SCREEN_RECORDER_ENABLED: '' },
  });
  assert.equal(disabled.recorder.start().state, 'disabled');
  assert.equal(disabled.timers.length, 0);

  const unsupported = createHarness({ platform: 'linux' });
  assert.equal(unsupported.recorder.start().state, 'unsupported');
  assert.equal(unsupported.timers.length, 0);
});

test('screen recorder rejects missing, invalid, and unknown owners', () => {
  const missing = createHarness({
    env: { NEOAGENT_SCREEN_RECORDER_USER_ID: '' },
  });
  assert.equal(missing.recorder.start().state, 'misconfigured');
  assert.match(missing.recorder.getStatus().reason, /USER_ID is required/);

  const invalid = createHarness({
    env: { NEOAGENT_SCREEN_RECORDER_USER_ID: 'not-an-id' },
  });
  assert.equal(invalid.recorder.start().state, 'misconfigured');
  assert.match(invalid.recorder.getStatus().reason, /must be an integer/);

  const unknown = createHarness({ existingUserIds: [] });
  assert.equal(unknown.recorder.start().state, 'misconfigured');
  assert.match(unknown.recorder.getStatus().reason, /does not exist/);
});

test('screen recorder validates and applies configurable timing and retention', async () => {
  const harness = createHarness({
    env: {
      NEOAGENT_SCREEN_RECORDER_INTERVAL_MS: '2500',
      NEOAGENT_SCREEN_RECORDER_RETENTION_DAYS: '30',
    },
  });

  const status = harness.recorder.start();
  assert.equal(status.state, 'running');
  assert.equal(status.intervalMs, 2500);
  assert.equal(status.retentionDays, 30);
  assert.deepEqual(harness.timers.map((timer) => timer.delay), [2500, 24 * 60 * 60 * 1000]);
  assert.deepEqual(harness.cleanupModifiers, ['-30 days']);
  await harness.recorder.stop();
  assert.equal(harness.clearedTimers.length, 2);

  const invalid = createHarness({
    env: { NEOAGENT_SCREEN_RECORDER_INTERVAL_MS: '500' },
  });
  assert.equal(invalid.recorder.start().state, 'misconfigured');
  assert.match(invalid.recorder.getStatus().reason, /greater than or equal to 1000/);
});

test('screen recorder writes OCR history only to the configured owner', async () => {
  const harness = createHarness();
  harness.recorder.start();
  await harness.recorder.captureAndProcess();
  harness.setActive(true);

  await harness.recorder.captureAndProcess();

  assert.deepEqual(harness.writes, [[42, 'Terminal', 'Meaningful captured text']]);
  assert.deepEqual(harness.execCalls.slice(-2), [
    ['osascript', ['-e', 'tell application "System Events" to get name of first application process whose frontmost is true']],
    ['screencapture', ['-x', '/tmp/neoagent-screen-test.png']],
  ]);
  assert.equal(harness.recorder.getStatus().lastError, null);
  assert.ok(harness.recorder.getStatus().lastSuccessAt);
  await harness.recorder.stop();
});

test('connection lookup is scoped to the configured user', () => {
  const registry = {
    connectionsByUser: new Map([
      ['7', new Map([['other', { isOpen: () => true }]])],
      ['42', new Map([['closed', { isOpen: () => false }]])],
    ]),
  };

  assert.equal(hasOpenConnectionForUser(registry, 7), true);
  assert.equal(hasOpenConnectionForUser(registry, 42), false);
  assert.equal(hasOpenConnectionForUser(registry, 99), false);
});

test('screen recorder coalesces overlapping captures and does not write after stop', async () => {
  const recognizeStarted = deferred();
  const recognizeResult = deferred();
  const harness = createHarness({
    recognize: async () => {
      recognizeStarted.resolve();
      return recognizeResult.promise;
    },
  });
  harness.recorder.start();
  await harness.recorder.captureAndProcess();
  harness.setActive(true);

  const capture = harness.recorder.captureAndProcess();
  assert.equal(harness.recorder.captureAndProcess(), capture);
  await recognizeStarted.promise;

  let stopCompleted = false;
  const stop = harness.recorder.stop().then((status) => {
    stopCompleted = true;
    return status;
  });
  await Promise.resolve();
  assert.equal(stopCompleted, false);

  recognizeResult.resolve({ data: { text: 'Text returned during shutdown' } });
  const status = await stop;
  assert.equal(status.state, 'stopped');
  assert.deepEqual(harness.writes, []);
});

test('screen recorder records capture failures without phrase-based classification', async () => {
  const harness = createHarness({
    recognize: async () => {
      const error = new Error('OCR provider returned an opaque failure');
      error.code = 'OCR_FAILED';
      throw error;
    },
  });
  harness.recorder.start();
  await harness.recorder.captureAndProcess();
  harness.setActive(true);

  await harness.recorder.captureAndProcess();

  assert.equal(
    harness.recorder.getStatus().lastError,
    'OCR provider returned an opaque failure',
  );
  assert.deepEqual(harness.writes, []);
  await harness.recorder.stop();
});
