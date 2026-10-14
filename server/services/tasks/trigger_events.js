'use strict';

const adapters = require('./adapters');
const { normalizeJsonObject } = require('./utils');

/**
 * Event trigger adapters declare:
 *   event.source    a key of EVENT_SOURCES, the emitter the event comes from
 *   event.name      the emitted event name
 *   event.matches(config, event, task)  whether this task wants the event
 *   event.toPayload(event, config)      → { fingerprint, timestamp, context }
 *
 * Every event carries userId, and agentId when it belongs to one agent.
 */
const EVENT_SOURCES = Object.freeze({
  runtime: (runtime) => runtime.events,
  messaging: (runtime) => runtime.app?.locals?.messagingManager || null,
  mcp: (runtime) => runtime.app?.locals?.mcpClient || null,
  wearable: (runtime) => runtime.app?.locals?.wearableService || null,
  whatsapp_personal: (runtime) => runtime.integrationManager?.getProvider?.('whatsapp_personal') || null,
});

const EVENT_ADAPTERS = adapters.filter((adapter) => adapter.event);

// A task that is still running skips a new trigger, so events for one task
// wait their turn: two people joining at once both get their welcome.
function createTaskQueue(runtime) {
  const queues = new Map();
  return (task, payload) => {
    const previous = queues.get(task.id) || Promise.resolve();
    const next = previous
      .then(() => runtime.fireTaskFromTrigger(task.id, task.user_id, payload))
      .catch((error) => {
        const logger = runtime.logger?.error || console.error;
        logger('[Tasks] Failed to fire event trigger', {
          taskId: task.id,
          triggerType: task.trigger_type,
          error: error?.message || String(error),
        });
      })
      .finally(() => {
        if (queues.get(task.id) === next) queues.delete(task.id);
      });
    queues.set(task.id, next);
    return next;
  };
}

function attachTriggerEventSources(runtime) {
  const enqueue = createTaskQueue(runtime);
  const cleanups = [];
  for (const adapter of EVENT_ADAPTERS) {
    const emitter = EVENT_SOURCES[adapter.event.source]?.(runtime);
    if (!emitter || typeof emitter.on !== 'function') continue;
    // Sources emit from inside their own work, so a failure here is logged
    // and never thrown back into a messaging handler or an HTTP route.
    const listener = (event) => {
      if (runtime.stopping || !event?.userId) return;
      try {
        const tasks = runtime.taskRepository.listEnabledEventTasks(event.userId, event.agentId || null, adapter.type);
        for (const task of tasks) {
          const config = normalizeJsonObject(task.trigger_config);
          if (!adapter.event.matches(config, event, task)) continue;
          enqueue(task, adapter.event.toPayload(event, config));
        }
      } catch (error) {
        console.error(`[Tasks] ${adapter.type} event could not be dispatched:`, error.message);
      }
    };
    emitter.on(adapter.event.name, listener);
    cleanups.push(() => emitter.off(adapter.event.name, listener));
  }
  return cleanups;
}

module.exports = {
  EVENT_SOURCES,
  attachTriggerEventSources,
};
