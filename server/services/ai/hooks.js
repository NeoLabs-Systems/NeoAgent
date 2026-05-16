/**
 * hooks.js — Agent loop lifecycle hook system
 *
 * Inspired by OpenClaw's plugin hook architecture. Hooks let integrations,
 * skills, and agent configs reshape context, observe state, or block
 * specific operations without touching engine.js core.
 *
 * ── WIRED in engine.js ─────────────────────────────────────────────────────
 *
 *   before_tool_call(ctx: { toolName, toolArgs, runId, userId, agentId, iteration })
 *     → Blockable. Return { block: true } to skip the tool call (soft skip,
 *       not counted as a failure). Return { toolArgs } to mutate arguments.
 *     Context: fires before DB insert and before executeTool().
 *
 *   on_loop_end(ctx: { userId, runId, agentId, status, iterations, totalTokens, taskAnalysis, finalContent })
 *     → Observer. Fires fire-and-forget after every completed run.
 *       Use for self-improvement, memory consolidation, analytics.
 *       Errors are swallowed — this hook must not affect run outcome.
 *
 * ── NOT YET WIRED (planned) ────────────────────────────────────────────────
 *
 *   before_prompt_build — inject extra system messages before model call
 *   after_tool_call     — observe/transform tool result after execution
 *   on_loop_iteration   — called at the top of each iteration; can inject steering
 *
 *   To wire one, call globalHooks.run(event, ctx) at the relevant point in
 *   engine.js and handle the returned object. Follow the before_tool_call
 *   pattern as a template.
 *
 * ── Usage ──────────────────────────────────────────────────────────────────
 *
 *   const { globalHooks } = require('./hooks');
 *
 *   globalHooks.register('before_tool_call', async (ctx) => {
 *     if (ctx.toolName === 'execute_command' && ctx.userId === 'restricted') {
 *       return { block: true };
 *     }
 *   }, { priority: 10, id: 'command-guard' });
 *
 *   globalHooks.register('on_loop_end', async (ctx) => {
 *     // fire-and-forget: distill learnings, update memory, post analytics
 *   }, { id: 'self-improve' });
 */

class AgentHooks {
  constructor() {
    /** @type {Map<string, Array<{fn: Function, priority: number, id: string}>>} */
    this._hooks = new Map();
  }

  /**
   * Register a hook handler.
   *
   * @param {string}   event     - Hook event name
   * @param {Function} fn        - async (ctx) => result | void
   * @param {object}   [opts]
   * @param {number}   [opts.priority=50] - Lower fires first
   * @param {string}   [opts.id]          - Unique ID for deregistration/tracing
   */
  register(event, fn, { priority = 50, id } = {}) {
    if (typeof fn !== 'function') throw new TypeError(`Hook handler for "${event}" must be a function`);
    const hookId = id ?? `hook_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    if (!this._hooks.has(event)) this._hooks.set(event, []);
    const handlers = this._hooks.get(event);
    handlers.push({ fn, priority, id: hookId });
    handlers.sort((a, b) => a.priority - b.priority);
    return hookId;
  }

  /**
   * Deregister a hook by ID.
   */
  deregister(event, id) {
    if (!this._hooks.has(event)) return false;
    const handlers = this._hooks.get(event);
    const idx = handlers.findIndex((h) => h.id === id);
    if (idx === -1) return false;
    handlers.splice(idx, 1);
    return true;
  }

  /**
   * Run all handlers for an event, merging their return values.
   * If any handler returns { block: true }, short-circuits and returns { block: true }.
   *
   * @param {string} event
   * @param {object} ctx   - Context passed to every handler
   * @returns {Promise<object>} Merged result from all handlers
   */
  async run(event, ctx) {
    const handlers = this._hooks.get(event) ?? [];
    let merged = {};
    for (const { fn, id } of handlers) {
      let result;
      try {
        result = await fn(ctx);
      } catch (err) {
        console.warn(`[Hooks] Handler "${id}" for "${event}" threw:`, err.message);
        continue; // don't let a bad hook crash the loop
      }
      if (result?.block === true) return { block: true };
      if (result && typeof result === 'object') {
        merged = { ...merged, ...result };
      }
    }
    return merged;
  }

  /** True if any handlers are registered for this event. */
  has(event) {
    return (this._hooks.get(event)?.length ?? 0) > 0;
  }

  /** List registered hook IDs for an event (useful for debugging). */
  list(event) {
    return (this._hooks.get(event) ?? []).map((h) => ({ id: h.id, priority: h.priority }));
  }
}

/**
 * Global hook registry shared across all runs.
 * Plugins and integrations register here at startup.
 * Per-run scoped hooks can be created with `new AgentHooks()`.
 */
const globalHooks = new AgentHooks();

module.exports = { AgentHooks, globalHooks };
