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
const { normalizeOutgoingMessageForPlatform } = require('../messaging/formatting_guides');

const MAX_AUTONOMOUS_RETRIES = 1;
const MAX_RECURRING_TASK_START_DELAY_MS = 90 * 1000;
const INTEGRATION_TRIGGER_POLL_CRON = '* * * * *';

function normalizeStoredString(value) {
  if (value == null) return '';
  if (typeof value !== 'string') return String(value || '').trim();
  let current = value.trim();
  for (let i = 0; i < 2; i += 1) {
    if (!current) return '';
    try {
      const parsed = JSON.parse(current);
      if (typeof parsed === 'string') {
        current = parsed.trim();
        continue;
      }
      return '';
    } catch {
      return current;
    }
  }
  return current;
}

function normalizeNotifyTarget(target = {}) {
  const platform = normalizeStoredString(target.platform);
  const to = normalizeStoredString(target.to);
  if (!platform || !to) return null;
  return { platform, to };
}

function stringifyTaskResult(result) {
  if (typeof result === 'string') return result;
  if (result == null) return '';
  if (typeof result !== 'object') return String(result);

  for (const key of ['content', 'message', 'text', 'summary', 'finalResponse', 'final_response']) {
    if (typeof result[key] === 'string' && result[key].trim()) {
      return result[key];
    }
  }

  if (result.result != null && result.result !== result) {
    const nested = stringifyTaskResult(result.result);
    if (nested) return nested;
  }

  return '';
}

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
    }).catch((error) => {
      console.error(`[Tasks] Manual task ${taskId} error:`, error.message);
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

    const result = await this._executeTask(taskId, userId, {
      manual: false,
      oneTime: false,
      scheduledAt: triggerPayload.timestamp || new Date().toISOString(),
      triggerType: task.trigger_type || 'schedule',
      triggerSource: task.trigger_type || 'schedule',
      triggerPayload: triggerPayload.context || {},
    });
    if (!result?.error && !result?.skipped) {
      this.taskRepository.markTaskTriggered(taskId, userId, fingerprint);
    }
    return result;
  }

  _startOneTimePoller() {
    this.oneTimePoller = cron.schedule('* * * * *', async () => {
      try {
        await this._runDueOneTimeTasks();
      } catch (error) {
        console.error('[Tasks] One-time task poll failed:', error.message);
      }
    });
  }

  async _runDueOneTimeTasks() {
    const due = this.taskRepository.listDueOneTimeTasks();

    for (const task of due) {
      this.scheduleJobs.delete(task.id);
      try {
        const result = await this._executeTask(task.id, task.user_id, {
          scheduledAt: task.run_at || new Date().toISOString(),
          oneTime: true,
          triggerType: 'schedule',
          triggerSource: 'schedule',
        });
        if (result?.skipped) {
          continue;
        }
        this.taskRepository.deleteTask(task.id, task.user_id);
        this.io.to(`user:${task.user_id}`).emit('tasks:task_deleted', { taskId: task.id });
      } catch (err) {
        console.error(`[Tasks] One-time task ${task.id} error:`, err.message);
      }
    }
  }

  _startIntegrationPoller() {
    this.integrationPoller = cron.schedule(INTEGRATION_TRIGGER_POLL_CRON, async () => {
      try {
        const tasks = this.taskRepository.listEnabledByTriggerTypes(POLLED_TRIGGER_TYPES);
        for (const task of tasks) {
          try {
            await pollIntegrationTask(this, task);
          } catch (error) {
            console.error(`[Tasks] Trigger poll failed for task ${task.id}:`, error.message);
          }
        }
      } catch (error) {
        console.error('[Tasks] Integration trigger poll failed:', error.message);
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
      try {
        await this._executeTask(task.id, task.user_id, {
          scheduledAt: new Date().toISOString(),
          manual: false,
          oneTime: false,
          triggerType: 'schedule',
          triggerSource: 'schedule',
        });
      } catch (error) {
        console.error(`[Tasks] Scheduled task ${task.id} error:`, error.message);
      }
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

    let normalizedConfig = taskConfig;
    const taskName = task.name || `Task ${taskId}`;
    const deliveryState = {
      messagingSent: false,
      noResponse: false,
      lastSentMessage: '',
      sentMessages: [],
    };
    let completedRunId = null;
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

      normalizedConfig = this._ensureDefaultNotifyTarget(userId, agentId, taskConfig, taskId);
      const triggerSummary = this._summarizeTrigger(task.trigger_type, triggerConfig);
      let notifyHint = '';

      if (normalizedConfig.callTo) {
        notifyHint = `\n\nThis task is configured to notify the user by phone. Use the make_call tool to call "${normalizedConfig.callTo}" with an appropriate greeting based on your findings. The configured greeting hint is: "${normalizedConfig.callGreeting || 'Hello, this is your task reminder.'}"`;
      } else if (normalizedConfig.notifyPlatform && normalizedConfig.notifyTo) {
        notifyHint = `\n\nIf your task result is worth notifying the user about, send it proactively via send_message to platform="${normalizedConfig.notifyPlatform}" to="${normalizedConfig.notifyTo}" and set purpose="final_result" for a concrete useful outcome or purpose="blocker" for a real issue the user should know about. If nothing important or actionable changed, call send_message with purpose="no_response" and content="[NO RESPONSE]".`;
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
          skipDeliverableWorkflow: true,
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
          completedRunId = result?.runId || null;
          const fallbackDelivery = await this._deliverTaskResultIfNeeded({
            userId,
            agentId,
            taskId,
            taskConfig: normalizedConfig,
            result,
            deliveryState,
          });
          if (fallbackDelivery && result && typeof result === 'object') {
            result.taskDelivery = fallbackDelivery;
          }
          if (fallbackDelivery?.error) {
            const deliveryError = new Error(fallbackDelivery.error);
            deliveryError.code = 'TASK_DELIVERY_FAILED';
            throw deliveryError;
          }
          if (
            !deliveryState.messagingSent
            && !deliveryState.noResponse
            && !stringifyTaskResult(result).trim()
          ) {
            throw new Error(
              'Background task completed without producing a result or an explicit no-response decision.',
            );
          }
          this.io.to(`user:${userId}`).emit('tasks:task_complete', { taskId, result });
          return result;
        } catch (err) {
          if (completedRunId) {
            this.taskRepository.markAgentRunFailed(completedRunId, userId, err.message);
          }
          if (err?.code === 'TASK_DELIVERY_FAILED') throw err;
          if (attempt >= MAX_AUTONOMOUS_RETRIES) throw err;
          attempt += 1;
          completedRunId = null;
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
      if (err?.code !== 'TASK_DELIVERY_FAILED') {
        await this._deliverTaskResultIfNeeded({
          userId,
          agentId,
          taskId,
          taskConfig: normalizedConfig,
          result: {
            content: `Background task "${taskName}" could not complete after retrying. Check the task run logs for details.`,
          },
          deliveryState,
        });
      }
      this.io.to(`user:${userId}`).emit('tasks:task_skipped', {
        taskId,
        reason: 'execution_failed',
        timestamp: new Date().toISOString(),
      });
      return { skipped: false, error: err.message, runId: completedRunId };
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
      lastRun: row.last_run_started_at || row.last_run || null,
      lastRunId: row.last_run_id || null,
      lastRunStatus: row.last_run_status || null,
      lastRunError: row.last_run_error || null,
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
    return normalizeNotifyTarget({
      platform: this._getAgentSetting(userId, scopedAgentId, 'last_platform'),
      to: this._getAgentSetting(userId, scopedAgentId, 'last_chat_id'),
    });
  }

  _buildNotifyTargets(userId, agentId, taskConfig = {}) {
    const scopedAgentId = resolveAgentId(userId, agentId);
    const candidates = [
      normalizeNotifyTarget({
        platform: taskConfig.notifyPlatform,
        to: taskConfig.notifyTo,
      }),
      this._getDefaultNotifyTarget(userId, scopedAgentId),
      ...this.taskRepository.listRecentMessageTargets(userId, scopedAgentId).map((row) => normalizeNotifyTarget({
        platform: row.platform,
        to: row.platform_chat_id,
      })),
    ];

    const unique = [];
    const seen = new Set();
    for (const target of candidates) {
      if (!target) continue;
      const key = `${target.platform}:${target.to}`;
      if (seen.has(key)) continue;
      seen.add(key);
      unique.push(target);
    }
    return unique;
  }

  _ensureDefaultNotifyTarget(userId, agentId, taskConfig, taskId) {
    const normalized = { ...taskConfig };
    const existingTarget = normalizeNotifyTarget({
      platform: normalized.notifyPlatform,
      to: normalized.notifyTo,
    });
    if (existingTarget) {
      normalized.notifyPlatform = existingTarget.platform;
      normalized.notifyTo = existingTarget.to;
    }
    if (!normalized.callTo && !existingTarget) {
      const notifyTarget = this._buildNotifyTargets(userId, agentId, normalized)[0];
      if (notifyTarget) {
        normalized.notifyPlatform = notifyTarget.platform;
        normalized.notifyTo = notifyTarget.to;
      }
    }
    if (
      normalized.notifyPlatform !== taskConfig.notifyPlatform
      || normalized.notifyTo !== taskConfig.notifyTo
    ) {
      this.taskRepository.updateTaskConfig(taskId, userId, normalized);
    }
    return normalized;
  }

  async _deliverTaskResultIfNeeded({
    userId,
    agentId,
    taskId,
    taskConfig,
    result,
    deliveryState,
  }) {
    if (deliveryState?.messagingSent || deliveryState?.noResponse || taskConfig.callTo) return null;
    const targets = this._buildNotifyTargets(userId, agentId, taskConfig);
    if (!targets.length) return null;

    const manager = this.app?.locals?.messagingManager || this.agentEngine?.messagingManager || null;
    if (!manager) {
      return {
        sent: false,
        error: 'Messaging delivery is unavailable on this server.',
      };
    }

    let lastError = null;
    for (const target of targets) {
      const message = normalizeOutgoingMessageForPlatform(
        target.platform,
        stringifyTaskResult(result),
        { stripNoResponseMarker: false },
      );
      if (!message || message.toUpperCase() === '[NO RESPONSE]') return null;

      const status = typeof manager.getPlatformStatus === 'function'
        ? manager.getPlatformStatus(userId, target.platform, { agentId })
        : null;
      if (!status || status.status !== 'connected') {
        lastError = new Error(`Platform ${target.platform} is not connected on this server.`);
        continue;
      }

      try {
        const sendResult = await manager.sendMessage(userId, target.platform, target.to, message, {
          agentId,
          runId: result?.runId || null,
          persistConversation: true,
        });
        deliveryState.messagingSent = true;
        deliveryState.lastSentMessage = message;
        if (!Array.isArray(deliveryState.sentMessages)) {
          deliveryState.sentMessages = [];
        }
        deliveryState.sentMessages.push(message);

        if (taskConfig.notifyPlatform !== target.platform || taskConfig.notifyTo !== target.to) {
          this.taskRepository.updateTaskConfig(taskId, userId, {
            ...taskConfig,
            notifyPlatform: target.platform,
            notifyTo: target.to,
          });
        }

        return {
          sent: true,
          platform: target.platform,
          to: target.to,
          result: sendResult,
        };
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError) {
      console.error(`[Tasks] Task ${taskId} notification delivery failed:`, lastError.message);
      return {
        sent: false,
        error: lastError.message,
      };
    }
    return null;
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
