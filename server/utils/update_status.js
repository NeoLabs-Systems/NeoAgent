'use strict';

// The admin UI and the update runner talk through this file: the runner is a
// separate process because it has to outlive the server it restarts.

const fs = require('node:fs');
const { UPDATE_STATUS_FILE } = require('../../runtime/paths');
const { writeAtomicFile } = require('../../lib/setup/atomic_file');

const MAX_LOG_LINES = 220;

const DEFAULT_UPDATE_STATUS = Object.freeze({
  state: 'idle',
  progress: 0,
  phase: 'idle',
  message: '',
  startedAt: null,
  completedAt: null,
  versionBefore: null,
  versionAfter: null,
  targetBranch: null,
  runnerPid: null,
  changelog: [],
  logs: [],
});

function isProcessAlive(pid) {
  const numericPid = Number(pid);
  if (!Number.isInteger(numericPid) || numericPid <= 0) return false;
  try {
    process.kill(numericPid, 0);
    return true;
  } catch (error) {
    return error?.code === 'EPERM';
  }
}

function readStatusFile(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return {};
  }
}

// A runner that died without saying so must not leave the UI waiting forever.
function normalizeUpdateStatus(status) {
  const next = { ...DEFAULT_UPDATE_STATUS, ...status };
  if (next.state === 'running' && !isProcessAlive(next.runnerPid)) {
    return {
      ...next,
      state: 'failed',
      progress: 100,
      phase: 'failed',
      message: 'The update stopped unexpectedly. Nothing was lost; you can try again.',
      completedAt: next.completedAt || new Date().toISOString(),
      runnerPid: null,
    };
  }
  return next;
}

function readUpdateStatus(filePath = UPDATE_STATUS_FILE) {
  return normalizeUpdateStatus(readStatusFile(filePath));
}

function writeUpdateStatus(patch, filePath = UPDATE_STATUS_FILE) {
  const next = normalizeUpdateStatus({
    ...readUpdateStatus(filePath),
    ...patch,
    updatedAt: new Date().toISOString(),
  });
  writeAtomicFile(filePath, JSON.stringify(next, null, 2), { mode: 0o600 });
  return next;
}

function appendUpdateLog(message, filePath = UPDATE_STATUS_FILE) {
  const { logs } = readUpdateStatus(filePath);
  return writeUpdateStatus({ logs: [...logs, `${new Date().toISOString()} ${message}`].slice(-MAX_LOG_LINES) }, filePath);
}

module.exports = {
  DEFAULT_UPDATE_STATUS,
  appendUpdateLog,
  isProcessAlive,
  readUpdateStatus,
  writeUpdateStatus,
};
