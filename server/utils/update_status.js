'use strict';

const fs = require('fs');
const path = require('path');
const { UPDATE_STATUS_FILE } = require('../../runtime/paths');

const DEFAULT_UPDATE_STATUS = Object.freeze({
  state: 'idle',
  progress: 0,
  phase: 'idle',
  message: 'No update running',
  startedAt: null,
  completedAt: null,
  versionBefore: null,
  versionAfter: null,
  runnerPid: null,
  changelog: [],
  logs: [],
});

function isProcessAlive(pid) {
  const numericPid = Number(pid);
  if (!Number.isInteger(numericPid) || numericPid <= 0) {
    return false;
  }

  try {
    process.kill(numericPid, 0);
    return true;
  } catch {
    return false;
  }
}

function readUpdateStatusFile(filePath = UPDATE_STATUS_FILE) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return { ...DEFAULT_UPDATE_STATUS };
  }
}

function normalizeUpdateStatus(status) {
  const next = {
    ...DEFAULT_UPDATE_STATUS,
    ...(status || {}),
  };

  if (next.state === 'running' && !isProcessAlive(next.runnerPid)) {
    return {
      ...next,
      state: 'failed',
      progress: 100,
      phase: 'failed',
      message: 'Previous update job stopped unexpectedly. You can try the update again.',
      completedAt: next.completedAt || new Date().toISOString(),
      runnerPid: null,
    };
  }

  return next;
}

function writeUpdateStatusFile(patch, filePath = UPDATE_STATUS_FILE) {
  const current = normalizeUpdateStatus(readUpdateStatusFile(filePath));
  const next = normalizeUpdateStatus({
    ...current,
    ...patch,
    updatedAt: new Date().toISOString(),
  });

  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(next, null, 2));
  return next;
}

function readUpdateStatus(filePath = UPDATE_STATUS_FILE) {
  const raw = readUpdateStatusFile(filePath);
  const normalized = normalizeUpdateStatus(raw);
  if (JSON.stringify(raw) !== JSON.stringify(normalized)) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, JSON.stringify(normalized, null, 2));
  }
  return normalized;
}

module.exports = {
  DEFAULT_UPDATE_STATUS,
  isProcessAlive,
  normalizeUpdateStatus,
  readUpdateStatus,
  writeUpdateStatusFile,
};
