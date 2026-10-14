'use strict';

// A run executes until the model answers, then delivers that answer. It can
// also wait for structured input, be paused, or end cancelled or failed.
const RUNTIME_STATES = Object.freeze({
  ACCEPTED: 'accepted',
  EXECUTING: 'executing',
  WAITING: 'waiting',
  PAUSED: 'paused',
  DELIVERING: 'delivering',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled',
  FAILED: 'failed',
});

const TERMINAL_RUNTIME_STATES = new Set([
  RUNTIME_STATES.COMPLETED,
  RUNTIME_STATES.CANCELLED,
  RUNTIME_STATES.FAILED,
]);

const PRODUCT_STATUS_BY_RUNTIME = Object.freeze({
  [RUNTIME_STATES.ACCEPTED]: 'running',
  [RUNTIME_STATES.EXECUTING]: 'running',
  [RUNTIME_STATES.WAITING]: 'running',
  [RUNTIME_STATES.PAUSED]: 'paused',
  [RUNTIME_STATES.DELIVERING]: 'running',
  [RUNTIME_STATES.COMPLETED]: 'completed',
  [RUNTIME_STATES.CANCELLED]: 'stopped',
  [RUNTIME_STATES.FAILED]: 'failed',
});

const ALLOWED_TRANSITIONS = Object.freeze({
  [RUNTIME_STATES.ACCEPTED]: [
    RUNTIME_STATES.EXECUTING,
    RUNTIME_STATES.CANCELLED,
    RUNTIME_STATES.FAILED,
  ],
  [RUNTIME_STATES.EXECUTING]: [
    RUNTIME_STATES.WAITING,
    RUNTIME_STATES.PAUSED,
    RUNTIME_STATES.DELIVERING,
    RUNTIME_STATES.CANCELLED,
    RUNTIME_STATES.FAILED,
  ],
  [RUNTIME_STATES.WAITING]: [
    RUNTIME_STATES.EXECUTING,
    RUNTIME_STATES.PAUSED,
    RUNTIME_STATES.CANCELLED,
    RUNTIME_STATES.FAILED,
  ],
  [RUNTIME_STATES.PAUSED]: [
    RUNTIME_STATES.EXECUTING,
    RUNTIME_STATES.CANCELLED,
    RUNTIME_STATES.FAILED,
  ],
  [RUNTIME_STATES.DELIVERING]: [
    RUNTIME_STATES.COMPLETED,
    RUNTIME_STATES.FAILED,
  ],
  [RUNTIME_STATES.COMPLETED]: [],
  [RUNTIME_STATES.CANCELLED]: [],
  [RUNTIME_STATES.FAILED]: [],
});

const DECISION_KINDS = Object.freeze({
  ACT: 'act',
  ANSWER: 'answer',
  BLANK: 'blank',
});

const MESSAGE_KINDS = Object.freeze({
  ACK: 'ack',
  INTERIM: 'interim',
  FINAL: 'final',
  ERROR: 'error',
  APPROVAL: 'approval',
  PROGRESS: 'progress',
});

const DEFAULT_LEASE_MS = 60_000;

// A progress line is trimmed to 400 characters after the call; there is no
// reason to let the model write more than that.
const NARRATION_MAX_TOKENS = 300;

module.exports = {
  NARRATION_MAX_TOKENS,
  RUNTIME_STATES,
  TERMINAL_RUNTIME_STATES,
  PRODUCT_STATUS_BY_RUNTIME,
  ALLOWED_TRANSITIONS,
  DECISION_KINDS,
  MESSAGE_KINDS,
  DEFAULT_LEASE_MS,
};
