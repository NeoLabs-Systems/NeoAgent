'use strict';

class TurnCoordinator {
  constructor() {
    this._stateByKey = new Map();
  }

  async run(key, taskFactory) {
    const normalizedKey = String(key || '').trim();
    if (!normalizedKey) {
      return taskFactory();
    }

    const state = this._stateByKey.get(normalizedKey) || { running: false, pending: null };
    this._stateByKey.set(normalizedKey, state);

    if (state.running) {
      return new Promise((resolve, reject) => {
        state.pending = { taskFactory, resolve, reject };
      });
    }

    state.running = true;
    try {
      let result = await taskFactory();

      // Coalesce concurrent requests: keep only latest pending task.
      while (state.pending) {
        const pending = state.pending;
        state.pending = null;
        try {
          result = await pending.taskFactory();
          pending.resolve(result);
        } catch (err) {
          pending.reject(err);
        }
      }

      return result;
    } finally {
      state.running = false;
      if (!state.pending) {
        this._stateByKey.delete(normalizedKey);
      }
    }
  }
}

module.exports = {
  TurnCoordinator,
};
