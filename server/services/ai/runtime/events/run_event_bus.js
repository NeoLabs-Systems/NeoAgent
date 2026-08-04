'use strict';

const { EventEmitter } = require('events');
const { appendEvent } = require('./run_event_store');
const { VISIBILITY } = require('./event_types');

class RunEventBus extends EventEmitter {
  constructor({ engine = null } = {}) {
    super();
    this.engine = engine;
    this.setMaxListeners(100);
  }

  publish(eventInput) {
    const persisted = appendEvent(eventInput);
    if (!persisted) return null;

    this.emit('event', persisted);
    this.emit(persisted.eventType, persisted);

    const visibility = persisted.payload?.visibility || VISIBILITY.OPERATOR;
    if (this.engine && typeof this.engine.emit === 'function' && visibility !== VISIBILITY.INTERNAL) {
      try {
        this.engine.emit(persisted.userId, 'run:event', {
          runId: persisted.runId,
          eventType: persisted.eventType,
          sequenceIndex: persisted.sequenceIndex,
          payload: persisted.payload,
          createdAt: persisted.createdAt,
        });
      } catch {
        // Socket emission must never break orchestration.
      }
    }

    return persisted;
  }
}

module.exports = {
  RunEventBus,
};
