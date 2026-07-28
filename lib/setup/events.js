'use strict';

const crypto = require('crypto');
const { SETUP_CONTRACT, SETUP_EVENT_STAGES } = require('./contract');

const SETUP_EVENT_SCHEMA_VERSION = SETUP_CONTRACT.schemaVersion;
const setupEventStages = new Set(SETUP_EVENT_STAGES);

function normalizeEventStage(value) {
  const stage = String(value || '').trim();
  if (!setupEventStages.has(stage)) {
    const error = new Error(`Invalid setup event stage: ${stage || '(empty)'}.`);
    error.code = 'SETUP_EVENT_STAGE_INVALID';
    throw error;
  }
  return stage;
}

class SetupEventWriter {
  constructor({ profile = 'quick', json = false, output = process.stdout } = {}) {
    this.profile = profile;
    this.json = Boolean(json);
    this.output = output;
    this.runId = crypto.randomUUID();
    this.stage = 'prepare';
  }

  emit(state, options = {}) {
    const stage = normalizeEventStage(options.stage || this.stage);
    const event = {
      schemaVersion: SETUP_EVENT_SCHEMA_VERSION,
      runId: this.runId,
      profile: this.profile,
      stage,
      state,
      timestamp: new Date().toISOString(),
    };
    if (Number.isFinite(options.progress)) {
      event.progress = Math.max(0, Math.min(1, Number(options.progress)));
    }
    if (options.message) event.message = String(options.message);
    if (options.error) {
      event.error = {
        code: String(options.error.code || 'SETUP_FAILED'),
        retryable: options.error.retryable !== false,
        action: String(options.error.action || 'retry'),
        detail: String(options.error.detail || options.error.message || ''),
      };
    }
    if (options.result) event.result = options.result;

    if (this.json) {
      this.output.write(`${JSON.stringify(event)}\n`);
    }
    return event;
  }

  start(stage, message, progress) {
    this.stage = normalizeEventStage(stage);
    return this.emit('started', { stage: this.stage, message, progress });
  }

  complete(stage, message, progress) {
    this.stage = normalizeEventStage(stage);
    return this.emit('completed', { stage: this.stage, message, progress });
  }

  message(message, options = {}) {
    return this.emit('message', { ...options, message });
  }

  fail(error, options = {}) {
    return this.emit('failed', {
      ...options,
      error: {
        code: error?.code || options.code || 'SETUP_FAILED',
        retryable: options.retryable,
        action: options.action,
        detail: error?.message || String(error || 'Setup failed.'),
      },
    });
  }
}

module.exports = {
  SETUP_EVENT_SCHEMA_VERSION,
  SetupEventWriter,
};
