'use strict';

class TriggerRegistry {
  constructor(adapters = []) {
    this.adapters = new Map();
    for (const adapter of adapters) {
      this.register(adapter);
    }
  }

  register(adapter) {
    if (!adapter?.type) {
      throw new Error('Trigger adapters must define a type.');
    }
    this.adapters.set(adapter.type, adapter);
  }

  get(type) {
    return this.adapters.get(String(type || '').trim()) || null;
  }

  list() {
    return Array.from(this.adapters.values());
  }
}

module.exports = {
  TriggerRegistry,
};
