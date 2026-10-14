'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { readUpdateStatus, writeUpdateStatusFile } = require('../../../server/utils/update_status');

function statusFile(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-update-status-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return path.join(dir, 'status.json');
}

test('reading an interrupted job reports failure without overwriting the runner status', (t) => {
  const file = statusFile(t);
  fs.writeFileSync(file, JSON.stringify({ state: 'running', runnerPid: null, logs: ['Downloading'] }));
  const original = fs.readFileSync(file, 'utf8');
  assert.equal(readUpdateStatus(file).state, 'failed');
  assert.equal(fs.readFileSync(file, 'utf8'), original);
  writeUpdateStatusFile({ state: 'running', runnerPid: process.pid, phase: 'installing' }, file);
  assert.equal(readUpdateStatus(file).state, 'running');
  assert.deepEqual(readUpdateStatus(file).logs, ['Downloading']);
});

test('status updates preserve progress and diagnostics, and atomically replace complete JSON', (t) => {
  const file = statusFile(t);
  writeUpdateStatusFile({ state: 'running', runnerPid: process.pid, progress: 70, logs: ['Installing'] }, file);
  writeUpdateStatusFile({ state: 'failed', runnerPid: null, message: 'Restored the previous version' }, file);
  const status = JSON.parse(fs.readFileSync(file, 'utf8'));
  assert.equal(status.state, 'failed');
  assert.equal(status.progress, 70);
  assert.deepEqual(status.logs, ['Installing']);
  assert.deepEqual(fs.readdirSync(path.dirname(file)), ['status.json']);
  if (process.platform !== 'win32') assert.equal(fs.statSync(file).mode & 0o777, 0o600);
});
