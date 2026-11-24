'use strict';

const { appendEvent } = require('./run_event_store');

// What a run's modules hold to write to the ledger.
class RunEventBus {
  publish(eventInput) {
    return appendEvent(eventInput);
  }
}

module.exports = {
  RunEventBus,
};
