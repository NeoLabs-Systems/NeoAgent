'use strict';

const crypto = require('crypto');

const SETUP_EVENT_SCHEMA_VERSION = 1;

class SetupEventWriter {
  constructor({ profile = 'quick', json = false, output = process.stdout } = {}) {
    this.profile = profile;
    this.json = Boolean(json);
    this.output = output;
    this.runId = crypto.randomUUID();
    this.stage = 'prepare';
  }

  emit(state, options = {}) {
    const event = {
      schemaVersion: SETUP_EVENT_SCHEMA_VERSION,
      runId: this.runId,
      profile: this.profile,
      stage: String(options.stage || this.stage),
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
    this.stage = stage;
    return this.emit('started', { stage, message, progress });
  }

  complete(stage, message, progress) {
    this.stage = stage;
    return this.emit('completed', { stage, message, progress });
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
