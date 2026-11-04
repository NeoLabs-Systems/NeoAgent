'use strict';

const db = require('../../../../db/database');
const taskTriggerAdapters = require('../../../tasks/adapters');

// Each trigger's fields stay out of the always-loaded schema; a config the
// trigger rejects comes back with the shape it expects.
function taskTriggerError(error, triggerType) {
 const adapter = taskTriggerAdapters.find((entry) => entry.type === triggerType);
 return adapter?.configHint
  ? { error: error.message, expectedConfig: `${adapter.type}: ${adapter.configHint}` }
  : { error: error.message };
}

// A bare 5-field cron expression: "m h dom mon dow" (seconds unsupported).
const CRON_5_FIELD_RE = /^(\S+\s+){4}\S+$/;

function coerceScheduleTriggerConfig(inputConfig) {
  // Models frequently pass the schedule config as a JSON string, or as a bare
  // cron expression / ISO datetime instead of an object. Coerce those shapes to
  // an object so a correct intent is not rejected over packaging.
  if (typeof inputConfig !== 'string') return inputConfig;
  const raw = inputConfig.trim();
  if (!raw) return inputConfig;
  if (raw.startsWith('{') || raw.startsWith('[')) {
    try {
      return JSON.parse(raw);
    } catch {
      return inputConfig;
    }
  }
  if (CRON_5_FIELD_RE.test(raw)) return { mode: 'recurring', cronExpression: raw };
  if (!Number.isNaN(Date.parse(raw))) return { mode: 'one_time', runAt: raw };
  return inputConfig;
}

function normalizeScheduleTriggerConfig(inputConfig = {}) {
  const coerced = coerceScheduleTriggerConfig(inputConfig);
  if (!coerced || typeof coerced !== 'object' || Array.isArray(coerced)) {
    return coerced;
  }

  const normalized = { ...coerced };
  const schedule = (normalized.schedule && typeof normalized.schedule === 'object' && !Array.isArray(normalized.schedule))
    ? normalized.schedule
    : null;

  const modeCandidate = String(
    normalized.mode
    || normalized.type
    || normalized.scheduleType
    || normalized.schedule_type
    || (normalized.oneTime || normalized.one_time ? 'one_time' : '')
    || ''
  ).trim().toLowerCase();
  if (modeCandidate === 'once') normalized.mode = 'one_time';
  else if (modeCandidate === 'one_time' || modeCandidate === 'recurring') normalized.mode = modeCandidate;

  const cronCandidate = normalized.cronExpression
    || normalized.cron_expression
    || normalized.cron
    || schedule?.cronExpression
    || schedule?.cron_expression
    || schedule?.cron;
  if (cronCandidate != null) {
    normalized.cronExpression = String(cronCandidate).trim();
  }

  const runAtCandidate = normalized.runAt
    || normalized.run_at
    || normalized.at
    || normalized.when
    || schedule?.runAt
    || schedule?.run_at
    || schedule?.at
    || schedule?.when;
  if (runAtCandidate != null) {
    normalized.runAt = String(runAtCandidate).trim();
  }

  if (!normalized.mode) {
    normalized.mode = normalized.runAt ? 'one_time' : 'recurring';
  }

  delete normalized.schedule;
  return normalized;
}

function normalizeTaskTriggerInput(triggerType, triggerConfig) {
  if (String(triggerType || '').trim() !== 'schedule') {
    return triggerConfig;
  }
  return normalizeScheduleTriggerConfig(triggerConfig || {});
}

function resolveTaskTriggerArgs(args = {}, fallbackTriggerType = null) {
  let triggerType = args.trigger_type !== undefined
    ? String(args.trigger_type || '').trim()
    : String(fallbackTriggerType || '').trim();
  let triggerConfig = args.trigger_config;
  let hasType = args.trigger_type !== undefined;
  let hasConfig = args.trigger_config !== undefined;

  if (args.trigger && typeof args.trigger === 'object' && !Array.isArray(args.trigger)) {
    const trigger = args.trigger;
    const unifiedType = trigger.type ?? trigger.triggerType ?? trigger.trigger_type;
    const unifiedHasType = unifiedType !== undefined && unifiedType !== null && String(unifiedType).trim().length > 0;
    if (unifiedHasType) {
      triggerType = String(unifiedType).trim();
      hasType = true;
    }

    const hasUnifiedConfig = Object.prototype.hasOwnProperty.call(trigger, 'config')
      || Object.prototype.hasOwnProperty.call(trigger, 'triggerConfig')
      || Object.prototype.hasOwnProperty.call(trigger, 'trigger_config');
    if (hasUnifiedConfig) {
      triggerConfig = trigger.config ?? trigger.triggerConfig ?? trigger.trigger_config;
      hasConfig = true;
    }
  }

  const normalizedType = String(triggerType || '').trim() || null;
  const normalizedConfig = hasConfig
    ? normalizeTaskTriggerInput(normalizedType || fallbackTriggerType || 'schedule', triggerConfig)
    : undefined;

  return {
    triggerType: normalizedType,
    triggerConfig: normalizedConfig,
    hasType,
    hasConfig,
  };
}

const handlers = {
  async create_task(args, ctx) {
    const { agentId, taskRuntime, userId } = ctx;
    const s = taskRuntime();
    if (!s) return { error: 'Task runtime not available' };
    let resolvedTrigger = null;
    try {
    resolvedTrigger = resolveTaskTriggerArgs(args, 'schedule');
    if (!resolvedTrigger.hasType || !resolvedTrigger.triggerType) {
      return { error: 'Task trigger type is required (use trigger.type or trigger_type).' };
    }
    const normalizedTriggerType = String(resolvedTrigger.triggerType || '').trim();
    const triggerConfig = (!resolvedTrigger.hasConfig || resolvedTrigger.triggerConfig === undefined)
      ? (normalizedTriggerType === 'manual' ? {} : undefined)
      : resolvedTrigger.triggerConfig;
    if (triggerConfig === undefined) {
      return { error: 'Task trigger config is required (use trigger.config or trigger_config).' };
    }
    const task = await s.createTask(userId, {
      name: args.name,
      triggerType: normalizedTriggerType,
      triggerConfig,
      prompt: args.prompt,
      enabled: args.enabled !== false,
      model: args.model || null,
      agentId
    });
    return { success: true, task, message: `Task "${args.name}" created.` };
    } catch (err) {
    return taskTriggerError(err, String(resolvedTrigger?.triggerType || '').trim());
    }
  },

  async list_tasks(args, ctx) {
    const { agentId, taskRuntime, userId } = ctx;
    const s = taskRuntime();
    if (!s) return { error: 'Task runtime not available' };
    const tasks = s.listTasks(userId).filter((task) => !agentId || task.agentId === agentId);
    return { tasks, count: tasks.length };
  },

  async delete_task(args, ctx) {
    const { agentId, taskRuntime, userId } = ctx;
    const s = taskRuntime();
    if (!s) return { error: 'Task runtime not available' };
    try {
    const task = db.prepare('SELECT agent_id FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(args.task_id, userId);
    if (!task || task.agent_id !== agentId) return { error: 'Task not found for this agent.' };
    s.deleteTask(args.task_id, userId);
    return { success: true, deleted: args.task_id };
    } catch (err) {
    return { error: err.message };
    }
  },

  async update_task(args, ctx) {
    const { agentId, taskRuntime, userId } = ctx;
    const s = taskRuntime();
    if (!s) return { error: 'Task runtime not available' };
    let resolvedTrigger = null;
    try {
    const existing = db.prepare('SELECT agent_id, trigger_type FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(args.task_id, userId);
    if (!existing || existing.agent_id !== agentId) return { error: 'Task not found for this agent.' };
    const updates = {};
    resolvedTrigger = resolveTaskTriggerArgs(args, existing.trigger_type || 'schedule');
    if (args.name !== undefined) updates.name = args.name;
    if (resolvedTrigger.hasType && resolvedTrigger.triggerType) updates.triggerType = resolvedTrigger.triggerType;
    if (resolvedTrigger.hasConfig && resolvedTrigger.triggerConfig !== undefined) updates.triggerConfig = resolvedTrigger.triggerConfig;
    if (args.prompt !== undefined) updates.prompt = args.prompt;
    if (args.enabled !== undefined) updates.enabled = args.enabled;
    if (args.model !== undefined) updates.model = args.model || null;
    const updated = await s.updateTask(args.task_id, userId, updates);
    return { success: true, task: updated };
    } catch (err) {
    return taskTriggerError(err, String(resolvedTrigger?.triggerType || '').trim());
    }
  },
};

module.exports = {
  handlers,
  resolveTaskTriggerArgs,
  normalizeScheduleTriggerConfig,
};
