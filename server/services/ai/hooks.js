'use strict';

class AgentHooks {
  constructor() {
    this._hooks = new Map();
  }

  register(event, fn, { priority = 50, id } = {}) {
    if (typeof fn !== 'function') throw new TypeError(`Hook handler for "${event}" must be a function`);
    const hookId = id ?? `hook_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    if (!this._hooks.has(event)) this._hooks.set(event, []);
    const handlers = this._hooks.get(event);
    handlers.push({ fn, priority, id: hookId });
    handlers.sort((a, b) => a.priority - b.priority);
    return hookId;
  }

  deregister(event, id) {
    if (!this._hooks.has(event)) return false;
    const handlers = this._hooks.get(event);
    const idx = handlers.findIndex((h) => h.id === id);
    if (idx === -1) return false;
    handlers.splice(idx, 1);
    return true;
  }

  async run(event, ctx) {
    const handlers = this._hooks.get(event) ?? [];
    let merged = {};
    for (const { fn, id } of handlers) {
      let result;
      try {
        result = await fn(ctx);
      } catch (err) {
        console.warn(`[Hooks] Handler "${id}" for "${event}" threw:`, err.message);
        continue;
      }
      if (result?.block === true) return { ...merged, ...result };
      if (result && typeof result === 'object') {
        merged = { ...merged, ...result };
      }
    }
    return merged;
  }

  has(event) {
    return (this._hooks.get(event)?.length ?? 0) > 0;
  }

  list(event) {
    return (this._hooks.get(event) ?? []).map((h) => ({ id: h.id, priority: h.priority }));
  }
}

const globalHooks = new AgentHooks();

module.exports = { AgentHooks, globalHooks };
