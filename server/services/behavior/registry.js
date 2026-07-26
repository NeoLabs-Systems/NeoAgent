'use strict';

const LIFECYCLE_STAGES = Object.freeze([
  'observe',
  'decide',
  'composeContext',
  'composeSystemPrompt',
  'refineDraft',
  'deliver',
  'afterTurn',
]);

function createBehaviorRegistry(modules) {
  const byId = new Map();
  for (const module of modules) {
    const id = String(module?.id || '').trim();
    if (!id) throw new Error('Behavior modules require a stable id.');
    if (byId.has(id)) throw new Error(`Duplicate behavior module id: ${id}`);
    byId.set(id, module);
  }

  function list() {
    return [...byId.values()];
  }

  function get(id) {
    return byId.get(id) || null;
  }

  async function run(stage, ctx) {
    if (!LIFECYCLE_STAGES.includes(stage)) {
      throw new Error(`Unknown behavior lifecycle stage: ${stage}`);
    }
    const results = [];
    for (const module of byId.values()) {
      if (ctx.isModuleEnabled && !ctx.isModuleEnabled(module.id)) continue;
      if (typeof module[stage] !== 'function') continue;
      results.push({ moduleId: module.id, value: await module[stage](ctx) });
    }
    return results;
  }

  async function composeContext(ctx) {
    const contributions = [];
    const keys = new Set();
    for (const { moduleId, value } of await run('composeContext', ctx)) {
      const entries = Array.isArray(value) ? value : [value];
      for (const entry of entries) {
        if (!entry?.content) continue;
        const key = String(entry.key || moduleId).trim();
        if (keys.has(key)) {
          throw new Error(`Duplicate behavior prompt contribution: ${key}`);
        }
        keys.add(key);
        contributions.push({
          key,
          priority: Number(entry.priority || 0),
          content: String(entry.content).trim(),
        });
      }
    }
    return contributions
      .sort((left, right) => right.priority - left.priority)
      .map((entry) => entry.content);
  }

  return {
    get,
    list,
    run,
    composeContext,
  };
}

module.exports = {
  LIFECYCLE_STAGES,
  createBehaviorRegistry,
};
