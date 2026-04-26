'use strict';

const cron = require('node-cron');
const crypto = require('crypto');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const taskAdapters = require('./adapters');
const {
  POLLED_TRIGGER_TYPES,
  attachIntegrationEventSources,
  pollIntegrationTask,
} = require('./integration_runtime');
const { TaskRepository } = require('./task_repository');
const { TriggerRegistry } = require('./trigger_registry');
const scheduleAdapter = require('./adapters/schedule');
const { normalizeJsonObject } = require('./utils');

const MAX_AUTONOMOUS_RETRIES = 1;
const MAX_RECURRING_TASK_START_DELAY_MS = 90 * 1000;
const INTEGRATION_TRIGGER_POLL_CRON = '* * * * *';

class TaskRuntime {
  constructor(io, agentEngine, app = null) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.app = app;
    this.taskRepository = new TaskRepository();
    this.scheduleJobs = new Map();
    this.runningTaskExecutions = new Set();
    this.integrationEventCleanups = [];
    this.triggerRegistry = new TriggerRegistry(taskAdapters);
  }

  get integrationManager() {
    return this.app?.locals?.integrationManager || null;
  }

  start() {
    this._loadFromDB();
    this._startOneTimePoller();
    this._startIntegrationPoller();
    this.integrationEventCleanups = attachIntegrationEventSources(this);
    console.log('[Tasks] Started');
  }

  stop() {
    for (const [, job] of this.scheduleJobs) {
      job.task.stop();
    }
    this.scheduleJobs.clear();
    for (const poller of [this.oneTimePoller, this.integrationPoller]) {
      if (poller) poller.stop();
    }
    for (const cleanup of this.integrationEventCleanups) {
      cleanup();
    }
    this.integrationEventCleanups = [];
    this.oneTimePoller = null;
    this.integrationPoller = null;
    console.log('[Tasks] Stopped');
  }

  getTriggerCatalog(userId, options = {}) {
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    return this.triggerRegistry.list().map((adapter) => ({
      type: adapter.type,
      label: adapter.label,
      providerKey: adapter.providerKey || null,
      appKey: adapter.appKey || null,
      available: adapter.type === 'schedule' || adapter.type === 'manual'
        ? true
        : this._hasConnectedApp(userId, agentId, adapter.providerKey, adapter.appKey),
    }));
  }

  async createTask(userId, input = {}) {
    const normalized = await this._normalizeTaskInput(userId, input);
    const taskId = this.taskRepository.createTask(userId, normalized);
    if (normalized.enabled) {
      await this._registerTask(this.taskRepository.getTaskById(taskId, userId));
    }
    return this._serializeTask(this.taskRepository.getTaskById(taskId, userId), userId);
  }

  async updateTask(taskId, userId, updates, options = {}) {
    const existing = this.taskRepository.getTaskById(taskId, userId);
    if (!existing) throw new Error('Task not found');
    if (existing.task_type === 'widget_refresh' && options.allowManaged !== true) {
      throw new Error('Managed widget tasks must be updated via widgets.');
    }
    const normalized = await this._normalizeTaskInput(userId, {
      id: taskId,
      name: updates.name ?? existing.name,
      triggerType: updates.triggerType ?? updates.trigger_type ?? existing.trigger_type,
      triggerConfig: updates.triggerConfig ?? updates.trigger_config ?? this._normalizeJson(existing.trigger_config),
      prompt: updates.prompt,
      enabled: updates.enabled ?? !!existing.enabled,
      model: updates.model,
      agentId: updates.agentId ?? updates.agent_id ?? existing.agent_id,
      taskType: updates.taskType ?? updates.task_type ?? existing.task_type,
      taskConfig: updates.taskConfig ?? updates.task_config ?? this._normalizeJson(existing.task_config),
      callTo: updates.callTo,
      callGreeting: updates.callGreeting,
    }, {
      existingTask: existing,
    });

    this.taskRepository.updateTask(taskId, userId, normalized);
    this._unregisterTask(taskId);
    if (normalized.enabled) {
      await this._registerTask(this.taskRepository.getTaskById(taskId, userId));
    }
    return this._serializeTask(this.taskRepository.getTaskById(taskId, userId), userId);
  }

  deleteTask(taskId, userId, options = {}) {
    const existing = this.taskRepository.getTaskById(taskId, userId);
    if (!existing) throw new Error('Task not found');
    if (existing.task_type === 'widget_refresh' && options.allowManaged !== true) {
      throw new Error('Managed widget tasks must be deleted via widgets.');
    }
    this._unregisterTask(taskId);
    this.taskRepository.deleteTask(taskId, userId);
    return { deleted: true };
  }

  listTasks(userId, options = {}) {
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    const includeLegacyMainTasks = isMainAgent(userId, agentId);
    const rows = this.taskRepository.listTasksForAgent(userId, agentId, includeLegacyMainTasks);
    return rows.map((row) => this._serializeTask(row, userId));
  }

  runTaskNow(taskId, userId) {
    const task = this.taskRepository.getTaskById(taskId, userId);
    if (!task) throw new Error('Task not found');
    void this._executeTask(taskId, userId, {
      scheduledAt: new Date().toISOString(),
      manual: true,
      triggerType: task.trigger_type || 'schedule',
      triggerSource: 'manual',
    });
    return { running: true };
  }

  async fireTaskFromTrigger(taskId, userId, triggerPayload = {}) {
    const task = this.taskRepository.getTaskById(taskId, userId);
    if (!task || !task.enabled) return { skipped: true, reason: 'missing_or_disabled' };
    const fingerprint = String(triggerPayload.fingerprint || '').trim();
    if (!fingerprint) {
      throw new Error('Trigger fingerprint is required.');
    }
    if (String(task.last_trigger_fingerprint || '') === fingerprint) {
      return { skipped: true, reason: 'duplicate_trigger' };
    }
    this.taskRepository.markTaskTriggered(taskId, userId, fingerprint);

    return this._executeTask(taskId, userId, {
      manual: false,
      oneTime: false,
      scheduledAt: triggerPayload.timestamp || new Date().toISOString(),
      triggerType: task.trigger_type || 'schedule',
      triggerSource: task.trigger_type || 'schedule',
      triggerPayload: triggerPayload.context || {},
    });
  }

  _startOneTimePoller() {
    this.oneTimePoller = cron.schedule('* * * * *', async () => {
      const due = this.taskRepository.listDueOneTimeTasks();

      for (const task of due) {
        this.scheduleJobs.delete(task.id);
        try {
          await this._executeTask(task.id, task.user_id, {
            scheduledAt: task.run_at || new Date().toISOString(),
            oneTime: true,
            triggerType: 'schedule',
            triggerSource: 'schedule',
          });
        } catch (err) {
          console.error(`[Tasks] One-time task ${task.id} error:`, err.message);
        }
        this.taskRepository.deleteById(task.id, task.user_id);
        this.io.to(`user:${task.user_id}`).emit('tasks:task_deleted', { taskId: task.id });
      }
    });
  }

  _startIntegrationPoller() {
    this.integrationPoller = cron.schedule(INTEGRATION_TRIGGER_POLL_CRON, async () => {
      const tasks = this.taskRepository.listEnabledByTriggerTypes(POLLED_TRIGGER_TYPES);
      for (const task of tasks) {
        try {
          await pollIntegrationTask(this, task);
        } catch (error) {
          console.error(`[Tasks] Trigger poll failed for task ${task.id}:`, error.message);
        }
      }
    });
  }

  async _registerTask(task) {
    if (!task || !task.enabled) return;
    if ((task.trigger_type || 'schedule') !== 'schedule') return;
    const triggerConfig = this._normalizeJson(task.trigger_config);
    if (triggerConfig.mode === 'one_time') return;
    const cronExpression = String(triggerConfig.cronExpression || '').trim();
    if (!cronExpression) return;
    const job = cron.schedule(cronExpression, async () => {
      await this._executeTask(task.id, task.user_id, {
        scheduledAt: new Date().toISOString(),
        manual: false,
        oneTime: false,
        triggerType: 'schedule',
        triggerSource: 'schedule',
      });
    });
    this.scheduleJobs.set(task.id, { task: job, userId: task.user_id });
  }

  _unregisterTask(taskId) {
    const existing = this.scheduleJobs.get(taskId);
    if (existing) {
      existing.task.stop();
    }
    this.scheduleJobs.delete(taskId);
  }

  async _executeTask(taskId, userId, executionMeta = {}) {
    const executionKey = `${userId}:${taskId}`;
    if (this.runningTaskExecutions.has(executionKey)) {
      this.io.to(`user:${userId}`).emit('tasks:task_skipped', {
        taskId,
        reason: 'already_running_or_queued',
        timestamp: new Date().toISOString(),
      });
      return { skipped: true, reason: 'already_running_or_queued' };
    }

    this.runningTaskExecutions.add(executionKey);
    try {
      return await this._executeTaskSerial(taskId, userId, executionMeta);
    } finally {
      this.runningTaskExecutions.delete(executionKey);
    }
  }

  async _executeTaskSerial(taskId, userId, executionMeta = {}) {
    const task = this.taskRepository.getTaskById(taskId, userId);
    if (!task || !task.enabled) return { skipped: true, reason: 'missing_or_disabled' };

    const taskConfig = this._normalizeJson(task.task_config);
    const triggerConfig = this._normalizeJson(task.trigger_config);
    const agentId = task.agent_id || resolveAgentId(userId, taskConfig.agentId || taskConfig.agent_id || null);
    const scheduledAtMs = executionMeta.scheduledAt ? new Date(executionMeta.scheduledAt).getTime() : NaN;
    const isLateRecurringRun = (
      executionMeta.manual !== true
      && executionMeta.oneTime !== true
      && executionMeta.triggerType === 'schedule'
      && Number.isFinite(scheduledAtMs)
      && (Date.now() - scheduledAtMs) > MAX_RECURRING_TASK_START_DELAY_MS
    );
    if (isLateRecurringRun) {
      this.io.to(`user:${userId}`).emit('tasks:task_skipped', {
        taskId,
        reason: 'stale_start_delay',
        scheduledAt: executionMeta.scheduledAt,
        timestamp: new Date().toISOString(),
      });
      return { skipped: true, reason: 'stale_start_delay' };
    }

    this.taskRepository.markTaskRun(taskId, userId);
    this.io.to(`user:${userId}`).emit('tasks:task_running', { taskId, timestamp: new Date().toISOString() });

    try {
      if (task.task_type === 'widget_refresh') {
        const widgetService = this.app?.locals?.widgetService;
        if (!widgetService || !taskConfig.widgetId) {
          throw new Error('Widget refresh task is missing widget context.');
        }
        const result = await widgetService.refreshWidget(userId, taskConfig.widgetId, {
          taskId,
          manual: executionMeta.manual === true,
          scheduledAt: executionMeta.scheduledAt || null,
        });
        this.io.to(`user:${userId}`).emit('tasks:task_complete', { taskId, result });
        return result;
      }

      const normalizedConfig = this._ensureDefaultNotifyTarget(userId, agentId, taskConfig, taskId);
      const taskName = task.name || `Task ${taskId}`;
      const triggerSummary = this._summarizeTrigger(task.trigger_type, triggerConfig);
      let notifyHint = '';

      if (normalizedConfig.callTo) {
        notifyHint = `\n\nThis task is configured to notify the user by phone. Use the make_call tool to call "${normalizedConfig.callTo}" with an appropriate greeting based on your findings. The configured greeting hint is: "${normalizedConfig.callGreeting || 'Hello, this is your task reminder.'}"`;
      } else if (normalizedConfig.notifyPlatform && normalizedConfig.notifyTo) {
        notifyHint = `\n\nIf your task result is worth notifying the user about, send it proactively via send_message to platform="${normalizedConfig.notifyPlatform}" to="${normalizedConfig.notifyTo}".`;
      }

      const triggerPayloadText = executionMeta.triggerPayload
        ? `\nTrigger event context:\n${JSON.stringify(executionMeta.triggerPayload, null, 2)}\n`
        : '';
      const basePrompt = [
        '[SYSTEM: Executing Background Task]',
        `Task Name: ${taskName}`,
        `Trigger: ${triggerSummary}`,
        '',
        task.task_type === 'agent_prompt'
          ? (normalizedConfig.prompt || `You have been triggered to run the background task "${taskName}".`)
          : '',
        triggerPayloadText.trim(),
        notifyHint,
      ].filter(Boolean).join('\n\n');

      const conversationId = this._getTaskConversation(userId, taskId, taskName, agentId);
      const deliveryState = { messagingSent: false, lastSentMessage: '', sentMessages: [] };
      let attempt = 0;
      let recoveryNote = '';
      while (attempt <= MAX_AUTONOMOUS_RETRIES) {
        const finalPrompt = basePrompt + recoveryNote;
        const runOptions = {
          triggerType: task.trigger_type || 'schedule',
          triggerSource: task.trigger_type || 'schedule',
          agentId,
          app: this.app,
          conversationId,
          taskId,
          deliveryState,
          allowMultipleProactiveMessages: normalizedConfig.allowMultipleMessages === true || normalizedConfig.allow_multiple_messages === true,
          skipTaskAnalysis: true,
          skipGlobalRecall: true,
          skipConversationHistory: true,
          skipConversationMaintenance: true,
          skipRunContextPersistence: true,
          skipVerifier: true,
          stream: false,
          context: executionMeta.triggerPayload || {},
        };
        try {
          const result = typeof this.agentEngine.runWithModel === 'function'
            ? await this.agentEngine.runWithModel(userId, finalPrompt, runOptions, normalizedConfig.model || null)
            : await this.agentEngine.run(userId, finalPrompt, runOptions);
          this.io.to(`user:${userId}`).emit('tasks:task_complete', { taskId, result });
          return result;
        } catch (err) {
          if (attempt >= MAX_AUTONOMOUS_RETRIES) throw err;
          attempt += 1;
          recoveryNote = [
            '\n\n[SYSTEM: Previous task attempt failed]',
            `Error: ${String(err?.message || 'Unknown runtime error')}`,
            'Continue autonomously end-to-end, retrying failed steps safely and using alternate tools when appropriate.',
          ].join('\n');
          this.io.to(`user:${userId}`).emit('tasks:task_running', {
            taskId,
            timestamp: new Date().toISOString(),
            retry: attempt,
          });
        }
      }
    } catch (err) {
      console.error(`[Tasks] Task ${taskId} error:`, err.message);
      this.io.to(`user:${userId}`).emit('tasks:task_error', { taskId, error: err.message });
      return { skipped: false, error: err.message };
    }
  }

  _normalizeJson(value) {
    return normalizeJsonObject(value);
  }

  async _normalizeTaskInput(userId, input = {}, { existingTask = null } = {}) {
    const agentId = resolveAgentId(userId, input.agentId || input.agent_id || existingTask?.agent_id || null);
    const name = String(input.name || existingTask?.name || '').trim();
    if (!name) throw new Error('Task name is required.');
    const triggerType = String(input.triggerType || input.trigger_type || existingTask?.trigger_type || '').trim() || 'schedule';
    const adapter = this.triggerRegistry.get(triggerType);
    if (!adapter) throw new Error(`Unsupported trigger type: ${triggerType}`);

    const existingTaskConfig = this._normalizeJson(existingTask?.task_config);
    const taskType = String(input.taskType || input.task_type || existingTask?.task_type || 'agent_prompt').trim() || 'agent_prompt';
    let taskConfig = input.taskConfig !== undefined || input.task_config !== undefined
      ? this._normalizeJson(input.taskConfig ?? input.task_config)
      : existingTaskConfig;

    if (taskType === 'widget_refresh') {
      if (!taskConfig.widgetId) {
        throw new Error('widget_refresh tasks require widgetId.');
      }
    } else {
      taskConfig = { ...existingTaskConfig, ...taskConfig };
      if (input.prompt !== undefined) taskConfig.prompt = String(input.prompt || '').trim();
      if (input.callTo !== undefined) taskConfig.callTo = input.callTo || null;
      if (input.callGreeting !== undefined) taskConfig.callGreeting = input.callGreeting || null;
      if (input.model !== undefined) {
        if (String(input.model || '').trim()) taskConfig.model = String(input.model).trim();
        else delete taskConfig.model;
      }
      if (!String(taskConfig.prompt || '').trim()) {
        throw new Error('Task prompt is required.');
      }
    }

    const rawTriggerConfig = input.triggerConfig ?? input.trigger_config ?? (
      triggerType === 'schedule'
        ? {
          mode: input.oneTime || input.one_time ? 'one_time' : 'recurring',
          cronExpression: input.cronExpression || input.cron_expression || existingTask?.cron_expression || null,
          runAt: input.runAt || input.run_at || existingTask?.run_at || null,
        }
        : existingTask?.trigger_config
    ) ?? {};
    const triggerConfig = await adapter.validateConfig(this._normalizeJson(rawTriggerConfig), {
      userId,
      agentId,
      integrationManager: this.integrationManager,
    });
    const enabled = input.enabled !== undefined ? input.enabled !== false : existingTask ? !!existingTask.enabled : true;

    return {
      name,
      agentId,
      triggerType,
      triggerConfig,
      enabled,
      executionMode: 'prompt',
      taskType,
      taskConfig,
      legacyCronExpression: triggerType === 'schedule' && triggerConfig.mode === 'recurring'
        ? triggerConfig.cronExpression
        : null,
      legacyRunAt: triggerType === 'schedule' && triggerConfig.mode === 'one_time'
        ? String(triggerConfig.runAt || '').replace('T', ' ').replace(/\.\d{3}Z$/, '')
        : null,
      legacyOneTime: triggerType === 'schedule' && triggerConfig.mode === 'one_time',
    };
  }

  _serializeTask(row, userId) {
    const triggerType = String(row.trigger_type || 'schedule').trim() || 'schedule';
    const triggerConfig = this._normalizeJson(row.trigger_config);
    const taskConfig = this._normalizeJson(row.task_config);
    const agentId = row.agent_id || resolveAgentId(userId, null);
    const triggerSummary = this._summarizeTrigger(triggerType, triggerConfig);
    return {
      id: row.id,
      name: row.name,
      triggerType,
      triggerConfig,
      triggerSummary,
      nextRun: triggerType === 'schedule' ? scheduleAdapter.nextRun(triggerConfig) : null,
      enabled: !!row.enabled,
      lastRun: row.last_run || null,
      lastTriggeredAt: row.last_triggered_at || null,
      taskType: row.task_type || 'agent_prompt',
      taskConfig,
      prompt: taskConfig.prompt || '',
      model: taskConfig.model || null,
      agentId,
      widgetId: taskConfig.widgetId || null,
      connectionLabel: triggerConfig.accountEmail || null,
    };
  }

  _summarizeTrigger(triggerType, triggerConfig) {
    return this.triggerRegistry.get(triggerType)?.summarize?.(triggerConfig) || triggerType;
  }

  _loadFromDB() {
    const tasks = this.taskRepository.listEnabledTasks();
    for (const task of tasks) {
      void this._registerTask(task).catch((error) => {
        console.error(`[Tasks] Failed to restore task ${task.id}:`, error.message);
      });
    }
  }

  _getAgentSetting(userId, agentId, key) {
    const row = this.taskRepository.getAgentSetting(userId, agentId, key);
    if (row) return row.value;
    if (!isMainAgent(userId, agentId)) return null;
    return this.taskRepository.getUserSetting(userId, key)?.value || null;
  }

  _getDefaultNotifyTarget(userId, agentId = null) {
    const scopedAgentId = resolveAgentId(userId, agentId);
    return {
      platform: this._getAgentSetting(userId, scopedAgentId, 'last_platform'),
      to: this._getAgentSetting(userId, scopedAgentId, 'last_chat_id'),
    };
  }

  _ensureDefaultNotifyTarget(userId, agentId, taskConfig, taskId) {
    const normalized = { ...taskConfig };
    if (!normalized.callTo && (!normalized.notifyPlatform || !normalized.notifyTo)) {
      const notifyTarget = this._getDefaultNotifyTarget(userId, agentId);
      if (notifyTarget.platform && notifyTarget.to) {
        normalized.notifyPlatform = notifyTarget.platform;
        normalized.notifyTo = notifyTarget.to;
        this.taskRepository.updateTaskConfig(taskId, userId, normalized);
      }
    }
    return normalized;
  }

  _getTaskConversation(userId, taskId, taskName, agentId = null) {
    const scopedAgentId = resolveAgentId(userId, agentId);
    const platform = 'tasks';
    const platformChatId = `task:${taskId}`;
    let row = this.taskRepository.getTaskConversation(userId, scopedAgentId, platform, platformChatId);
    if (!row) {
      const id = crypto.randomUUID();
      this.taskRepository.createTaskConversation({
        id,
        userId,
        agentId: scopedAgentId,
        platform,
        platformChatId,
        title: `Task — ${taskName || `Task ${taskId}`}`,
      });
      row = { id };
    }
    return row.id;
  }

  _hasConnectedApp(userId, agentId, providerKey, appKey) {
    if (!providerKey || !this.integrationManager) return true;
    const connections = this.integrationManager.listConnections(userId, providerKey, agentId);
    return connections.some((connection) =>
      connection.status === 'connected' &&
      (!appKey || String(connection.app_key || '').trim() === String(appKey).trim()),
    );
  }
}

module.exports = {
  TaskRuntime,
};
