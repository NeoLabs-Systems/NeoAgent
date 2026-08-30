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
const { isTransientError } = require('../ai/providerRetry');
const { getFailureDisposition } = require('../ai/model_failure_cache');
const { isAbortError, throwIfAborted } = require('../../utils/abort');

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

function isTaskLoopPaused(taskConfig = {}) {
  const raw = taskConfig.loopBudget && typeof taskConfig.loopBudget === 'object' && !Array.isArray(taskConfig.loopBudget)
    ? taskConfig.loopBudget
    : {};
  return raw.paused === true
    || raw.paused === 'true'
    || raw.pause === true
    || raw.pause === 'true'
    || taskConfig.loopPaused === true
    || taskConfig.loopPaused === 'true'
    || taskConfig.loop_paused === true
    || taskConfig.loop_paused === 'true';
}

class TaskRuntime {
  constructor(io, agentEngine, app = null, options = {}) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.app = app;
    this.cron = options.cron || cron;
    this.taskRepository = new TaskRepository();
    this.scheduleJobs = new Map();
    this.runningTaskExecutions = new Set();
    this.activeExecutionPromises = new Set();
    this.activePolls = new Map();
    this.abortController = new AbortController();
    this.integrationEventCleanups = [];
    this.triggerRegistry = new TriggerRegistry(taskAdapters);
    this.started = false;
    this.stopping = false;
    this.stopPromise = null;
    this.state = 'idle';
    this.lastError = null;
  }

  get integrationManager() {
    return this.app?.locals?.integrationManager || null;
  }

  get timelineService() {
    return this.app?.locals?.timelineService || null;
  }

  getStatus() {
    return {
      state: this.state,
      started: this.started,
      stopping: this.stopping,
      scheduledJobCount: this.scheduleJobs.size,
      activeExecutionCount: this.activeExecutionPromises.size,
      activePolls: Array.from(this.activePolls.keys()),
      lastError: this.lastError,
    };
  }

  start() {
    if (this.started) {
      return this.getStatus();
    }
    if (this.stopPromise) {
      throw new Error('Task runtime cannot start while shutdown is in progress.');
    }

    if (this.abortController.signal.aborted) {
      this.abortController = new AbortController();
    }
    this.started = true;
    this.stopping = false;
    this.state = 'starting';
    this.lastError = null;
    try {
      this._loadFromDB();
      this._startOneTimePoller();
      this._startIntegrationPoller();
      this.integrationEventCleanups = attachIntegrationEventSources(this);
      this.state = 'running';
      console.log('[Tasks] Started');
      return this.getStatus();
    } catch (error) {
      this.lastError = error.message;
      this.started = false;
      this.stopping = false;
      this.state = 'error';
      this._stopScheduling();
      throw error;
    }
  }

  _stopScheduling() {
    for (const [, job] of this.scheduleJobs) {
      job.task.stop();
    }
    this.scheduleJobs.clear();
    for (const poller of [this.oneTimePoller, this.integrationPoller]) {
      if (poller) poller.stop();
    }
    for (const cleanup of this.integrationEventCleanups) {
      try {
        cleanup();
      } catch (error) {
        console.error('[Tasks] Event source cleanup failed:', error.message);
      }
    }
    this.integrationEventCleanups = [];
    this.oneTimePoller = null;
    this.integrationPoller = null;
  }

  async stop() {
    if (this.stopPromise) {
      return this.stopPromise;
    }
    if (
      !this.started
      && this.state === 'stopped'
      && this.scheduleJobs.size === 0
      && this.activePolls.size === 0
      && this.activeExecutionPromises.size === 0
    ) {
      return this.getStatus();
    }

    this.started = false;
    this.stopping = true;
    this.state = 'stopping';
    this.abortController.abort('Task runtime is stopping.');
    this._stopScheduling();

    this.stopPromise = (async () => {
      while (this.activePolls.size > 0 || this.activeExecutionPromises.size > 0) {
        await Promise.allSettled([
          ...this.activePolls.values(),
          ...this.activeExecutionPromises,
        ]);
      }
      this.stopping = false;
      this.state = 'stopped';
      console.log('[Tasks] Stopped');
      return this.getStatus();
    })().finally(() => {
      this.stopPromise = null;
    });
    return this.stopPromise;
  }

  getTriggerCatalog(userId, options = {}) {
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    return this.triggerRegistry.list().map((adapter) => ({
      type: adapter.type,
      label: adapter.label,
      providerKey: adapter.providerKey || null,
      appKey: adapter.appKey || null,
      available: ['schedule', 'manual', 'webhook'].includes(adapter.type)
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

  async updateTask(taskId, userId, updates) {
    const existing = this.taskRepository.getTaskById(taskId, userId);
    if (!existing) throw new Error('Task not found');
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

  deleteTask(taskId, userId) {
    const existing = this.taskRepository.getTaskById(taskId, userId);
    if (!existing) throw new Error('Task not found');
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
    if (this.stopping || this.abortController.signal.aborted) {
      return { running: false, skipped: true, reason: 'runtime_stopping' };
    }
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
    this.oneTimePoller = this.cron.schedule('* * * * *', () => {
      return this._runPoll('one_time', () => this._runDueOneTimeTasks(), (error) => {
        console.error('[Tasks] One-time task poll failed:', error.message);
      });
    });
  }

  async _runDueOneTimeTasks() {
    const due = this.taskRepository.listDueOneTimeTasks();

    for (const task of due) {
      if (this.abortController.signal.aborted) break;
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
    this.integrationPoller = this.cron.schedule(INTEGRATION_TRIGGER_POLL_CRON, () => {
      return this._runPoll('integration', async () => {
        const tasks = this.taskRepository.listEnabledByTriggerTypes(POLLED_TRIGGER_TYPES);
        for (const task of tasks) {
          if (this.abortController.signal.aborted) break;
          try {
            await pollIntegrationTask(this, task, {
              signal: this.abortController.signal,
            });
          } catch (error) {
            if (isAbortError(error, this.abortController.signal) && this.stopping) break;
            console.error(`[Tasks] Trigger poll failed for task ${task.id}:`, error.message);
          }
        }
      }, (error) => {
        console.error('[Tasks] Integration trigger poll failed:', error.message);
      });
    });
  }

  _runPoll(name, callback, onError) {
    const active = this.activePolls.get(name);
    if (active) {
      return active;
    }
    if (this.stopping || this.abortController.signal.aborted) {
      return Promise.resolve({ skipped: true, reason: 'runtime_stopping' });
    }

    const promise = Promise.resolve()
      .then(() => callback(this.abortController.signal))
      .catch((error) => {
        if (isAbortError(error, this.abortController.signal) && this.stopping) {
          return { skipped: true, reason: 'runtime_stopping' };
        }
        this.lastError = error.message;
        onError(error);
        return { error: error.message };
      })
      .finally(() => {
        if (this.activePolls.get(name) === promise) {
          this.activePolls.delete(name);
        }
      });
    this.activePolls.set(name, promise);
    return promise;
  }

  async _registerTask(task) {
    if (!task) return;
    this._unregisterTask(task.id);
    if (!task.enabled) return;
    if ((task.trigger_type || 'schedule') !== 'schedule') return;
    const triggerConfig = this._normalizeJson(task.trigger_config);
    // Resolve the cron expression from the structured trigger_config, falling
    // back to the legacy cron_expression column. An older migration could leave
    // the expression in only one of the two places; as long as either still
    // holds it, the task must keep being scheduled.
    const cronExpression = String(
      triggerConfig.cronExpression || task.cron_expression || '',
    ).trim();
    // One-time runs are driven by the one-time poller, not node-cron. Only skip
    // here when there is genuinely no recurring cron expression to honor.
    if (!cronExpression) {
      return;
    }
    const job = this.cron.schedule(cronExpression, async () => {
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
    if (this.stopping || this.abortController.signal.aborted) {
      return { skipped: true, reason: 'runtime_stopping' };
    }
    const executionKey = `${userId}:${taskId}`;
    if (this.runningTaskExecutions.has(executionKey)) {
      this._recordTaskLifecycle({
        userId,
        taskId,
        taskName: this.taskRepository.getTaskById(taskId, userId)?.name || `Task ${taskId}`,
        agentId: this.taskRepository.getTaskById(taskId, userId)?.agent_id || null,
        eventKind: 'task_skipped',
        reason: 'already_running_or_queued',
        triggerType: executionMeta.triggerType || null,
        triggerSource: executionMeta.triggerSource || null,
      });
      this.io.to(`user:${userId}`).emit('tasks:task_skipped', {
        taskId,
        reason: 'already_running_or_queued',
        timestamp: new Date().toISOString(),
      });
      return { skipped: true, reason: 'already_running_or_queued' };
    }

    this.runningTaskExecutions.add(executionKey);
    const executionPromise = this._executeTaskSerial(taskId, userId, executionMeta);
    this.activeExecutionPromises.add(executionPromise);
    try {
      return await executionPromise;
    } finally {
      this.runningTaskExecutions.delete(executionKey);
      this.activeExecutionPromises.delete(executionPromise);
    }
  }

  async _executeTaskSerial(taskId, userId, executionMeta = {}) {
    const signal = this.abortController.signal;
    if (signal.aborted) return { skipped: true, reason: 'runtime_stopping' };
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
      this._recordTaskLifecycle({
        userId,
        taskId,
        taskName: task.name || `Task ${taskId}`,
        agentId,
        eventKind: 'task_skipped',
        reason: 'stale_start_delay',
        triggerType: executionMeta.triggerType || null,
        triggerSource: executionMeta.triggerSource || null,
      });
      this.io.to(`user:${userId}`).emit('tasks:task_skipped', {
        taskId,
        reason: 'stale_start_delay',
        scheduledAt: executionMeta.scheduledAt,
        timestamp: new Date().toISOString(),
      });
      return { skipped: true, reason: 'stale_start_delay' };
    }

    if (isTaskLoopPaused(taskConfig)) {
      this._recordTaskLifecycle({
        userId,
        taskId,
        taskName: task.name || `Task ${taskId}`,
        agentId,
        eventKind: 'task_skipped',
        reason: 'loop_paused',
        triggerType: executionMeta.triggerType || null,
        triggerSource: executionMeta.triggerSource || null,
      });
      this.io.to(`user:${userId}`).emit('tasks:task_skipped', {
        taskId,
        reason: 'loop_paused',
        timestamp: new Date().toISOString(),
      });
      return {
        skipped: true,
        reason: 'loop_paused',
      };
    }

    this.taskRepository.markTaskRun(taskId, userId);
    this.io.to(`user:${userId}`).emit('tasks:task_running', { taskId, timestamp: new Date().toISOString() });
    this._recordTaskLifecycle({
      userId,
      taskId,
      taskName: task.name || `Task ${taskId}`,
      agentId,
      eventKind: 'task_started',
      triggerType: executionMeta.triggerType || null,
      triggerSource: executionMeta.triggerSource || null,
    });

    let normalizedConfig = taskConfig;
    const taskName = task.name || `Task ${taskId}`;
    const deliveryState = {
      messagingSent: false,
      noResponse: false,
      proactiveMessageStaged: false,
      stagedProactiveMessage: null,
      lastSentMessage: '',
      sentMessages: [],
    };
    let completedRunId = null;
    try {
      normalizedConfig = this._ensureDefaultNotifyTarget(userId, agentId, taskConfig, taskId);
      const triggerSummary = this._summarizeTrigger(task.trigger_type, triggerConfig);
      let notifyHint = '';
      const manualRun = executionMeta.manual === true;

      if (normalizedConfig.notifyPlatform && normalizedConfig.notifyTo) {
        notifyHint = `\n\nIf your task result is worth notifying the user about, send it proactively via send_message to platform="${normalizedConfig.notifyPlatform}" to="${normalizedConfig.notifyTo}" and set purpose="final_result" for a concrete useful outcome or purpose="blocker" for a real issue the user should know about. If nothing important or actionable changed, call send_message with purpose="no_response" and content="[NO RESPONSE]" exactly; never leave content blank for no_response. When a tool result already gives you summary fields or flags that answer the task, decide from that evidence instead of re-running nearby variants of the same lookup.${manualRun ? '' : ' For this automatic scheduled run, plain assistant text is internal only and is NOT delivered. You MUST end the run with exactly one explicit send_message decision (purpose="final_result", "blocker", or "no_response") — if you produce a real result, deliver it with send_message or it is lost.'}`;
      }

      const triggerPayloadText = executionMeta.triggerPayload
        ? `\nTrigger event context:\n${JSON.stringify(executionMeta.triggerPayload, null, 2)}\n`
        : '';
      const executionInstant = executionMeta.scheduledAt || new Date().toISOString();
      const temporalAccuracyHint = task.trigger_type === 'schedule'
        ? `Execution instant: ${executionInstant}. For any requested lead time before a calendar event, derive the target event-start time from this instant plus that lead time and use an explicit, bounded start window around that target. An event is eligible only from its actual start timestamp; never notify for an event that has already started, merely overlaps the window, or is all-day unless the task explicitly asks for those cases.`
        : '';
      const basePrompt = [
        '[SYSTEM: Executing Background Task]',
        `Task Name: ${taskName}`,
        `Trigger: ${triggerSummary}`,
        temporalAccuracyHint,
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
          triggerSource: executionMeta.triggerSource || task.trigger_type || 'schedule',
          agentId,
          app: this.app,
          conversationId,
          taskId,
          scheduledAt: executionInstant,
          bypassUserRateLimits: true,
          deliveryState,
          allowMultipleProactiveMessages: normalizedConfig.allowMultipleMessages === true || normalizedConfig.allow_multiple_messages === true,
          stageProactiveMessages: true,
          skipDeliverableWorkflow: true,
          skipGlobalRecall: true,
          skipConversationHistory: true,
          skipConversationMaintenance: true,
          skipRunContextPersistence: true,
          skipVerifier: false,
          stream: false,
          context: executionMeta.triggerPayload || {},
          signal,
        };
        try {
          const result = typeof this.agentEngine.runWithModel === 'function'
            ? await this.agentEngine.runWithModel(userId, finalPrompt, runOptions, normalizedConfig.model || null)
            : await this.agentEngine.run(userId, finalPrompt, runOptions);
          completedRunId = result?.runId || null;
          if (this.stopping || signal.aborted) {
            return { skipped: true, reason: 'runtime_stopping', runId: completedRunId };
          }
          const fallbackDelivery = await this._deliverTaskResultIfNeeded({
            userId,
            agentId,
            taskId,
            taskConfig: normalizedConfig,
            result,
            deliveryState,
            allowPlainResultFallback: manualRun,
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
          this._recordTaskLifecycle({
            userId,
            taskId,
            taskName,
            agentId,
            eventKind: 'task_completed',
            runId: completedRunId,
            triggerType: executionMeta.triggerType || null,
            triggerSource: executionMeta.triggerSource || null,
          });
          return result;
        } catch (err) {
          if (isAbortError(err, signal) && this.stopping) {
            return { skipped: true, reason: 'runtime_stopping', runId: completedRunId };
          }
          const transientExecutionError = isTransientError(err);
          if (completedRunId && !transientExecutionError) {
            this.taskRepository.markAgentRunFailed(completedRunId, userId, err.message);
          }
          if (err?.code === 'TASK_DELIVERY_FAILED') throw err;
          if (transientExecutionError) {
            this._recordTaskLifecycle({
              userId,
              taskId,
              taskName,
              agentId,
              eventKind: 'task_skipped',
              runId: completedRunId,
              reason: 'transient_rate_limit',
              error: err.message,
              triggerType: executionMeta.triggerType || null,
              triggerSource: executionMeta.triggerSource || null,
            });
            this.io.to(`user:${userId}`).emit('tasks:task_skipped', {
              taskId,
              reason: 'transient_rate_limit',
              timestamp: new Date().toISOString(),
            });
            return { skipped: true, reason: 'transient_rate_limit', runId: completedRunId, error: err.message };
          }
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
      if (isAbortError(err, signal) && this.stopping) {
        return { skipped: true, reason: 'runtime_stopping', runId: completedRunId };
      }
      console.error(`[Tasks] Task ${taskId} error:`, err.message);
      if (err?.code !== 'TASK_DELIVERY_FAILED') {
        const failureMessage = this._buildTaskFailureMessage(taskName, err);
        // A null message means the failure is transient infrastructure (rate/quota
        // limit) that is not user-actionable and would spam every run during the
        // limit window — it is logged above, but not surfaced to the user.
        if (failureMessage) {
          await this._deliverTaskResultIfNeeded({
            userId,
            agentId,
            taskId,
            taskConfig: normalizedConfig,
            result: {
              content: failureMessage,
            },
            deliveryState,
            allowPlainResultFallback: true,
          });
        }
      }
      this.io.to(`user:${userId}`).emit('tasks:task_skipped', {
        taskId,
        reason: 'execution_failed',
        error: err.message,
        timestamp: new Date().toISOString(),
      });
      this._recordTaskLifecycle({
        userId,
        taskId,
        taskName,
        agentId,
        eventKind: 'task_failed',
        runId: completedRunId,
        error: err.message,
        triggerType: executionMeta.triggerType || null,
        triggerSource: executionMeta.triggerSource || null,
      });
      return { skipped: false, error: err.message, runId: completedRunId };
    }
  }

  _recordTaskLifecycle({
    userId,
    taskId,
    taskName,
    agentId = null,
    eventKind,
    runId = null,
    reason = null,
    error = null,
    triggerType = null,
    triggerSource = null,
  }) {
    if (!this.timelineService?.recordTaskLifecycle) {
      return;
    }
    this.timelineService.recordTaskLifecycle({
      userId,
      agentId,
      taskId,
      taskName,
      eventKind,
      runId,
      reason,
      error,
      triggerType,
      triggerSource,
    });
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

    taskConfig = { ...existingTaskConfig, ...taskConfig };
    if (input.prompt !== undefined) taskConfig.prompt = String(input.prompt || '').trim();
    delete taskConfig.callTo;
    delete taskConfig.callGreeting;
    if (input.model !== undefined) {
      if (String(input.model || '').trim()) taskConfig.model = String(input.model).trim();
      else delete taskConfig.model;
    }
    if (!String(taskConfig.prompt || '').trim()) {
      throw new Error('Task prompt is required.');
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
    delete taskConfig.callTo;
    delete taskConfig.callGreeting;
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
      loopPaused: isTaskLoopPaused(taskConfig),
      prompt: taskConfig.prompt || '',
      model: taskConfig.model || null,
      agentId,
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
    const removedLegacyCallConfig = Object.prototype.hasOwnProperty.call(normalized, 'callTo')
      || Object.prototype.hasOwnProperty.call(normalized, 'callGreeting');
    delete normalized.callTo;
    delete normalized.callGreeting;
    const existingTarget = normalizeNotifyTarget({
      platform: normalized.notifyPlatform,
      to: normalized.notifyTo,
    });
    if (existingTarget) {
      normalized.notifyPlatform = existingTarget.platform;
      normalized.notifyTo = existingTarget.to;
    }
    if (!existingTarget) {
      const notifyTarget = this._buildNotifyTargets(userId, agentId, normalized)[0];
      if (notifyTarget) {
        normalized.notifyPlatform = notifyTarget.platform;
        normalized.notifyTo = notifyTarget.to;
      }
    }
    if (
      normalized.notifyPlatform !== taskConfig.notifyPlatform
      || normalized.notifyTo !== taskConfig.notifyTo
      || removedLegacyCallConfig
    ) {
      this.taskRepository.updateTaskConfig(taskId, userId, normalized);
    }
    return normalized;
  }

  // Build the user-facing notice for a task that errored out after retries.
  // Returns null when the failure should NOT be surfaced (transient infra limits).
  _buildTaskFailureMessage(taskName, err) {
    const raw = String(err?.message || '').trim();
    // Provider/model health failures are handled by the dynamic router and its
    // cooldown store. Repeating the raw provider payload on every schedule tick
    // is not actionable and can flood the delivery channel.
    if (getFailureDisposition(err) || isTransientError(err)) {
      return null;
    }
    // Genuine failure: tell the user the actual reason instead of "check the logs",
    // which they cannot do. Collapse whitespace and cap length to keep it readable.
    const reason = raw ? raw.replace(/\s+/g, ' ').slice(0, 200) : 'an unknown error';
    return `Background task "${taskName}" could not complete: ${reason}`;
  }

  async _deliverTaskResultIfNeeded({
    userId,
    agentId,
    taskId,
    taskConfig,
    result,
    deliveryState,
    allowPlainResultFallback = true,
  }) {
    throwIfAborted(this.abortController.signal, 'Task runtime is stopping.');
    if (deliveryState?.messagingSent || deliveryState?.noResponse) return null;
    const targets = this._buildNotifyTargets(userId, agentId, taskConfig);
    if (!targets.length) return null;
    const resultText = stringifyTaskResult(result).trim();
    const resultLooksLikeError = Boolean(result?.error);
    const stagedMessage = normalizeOutgoingMessageForPlatform(
      deliveryState?.stagedProactiveMessage?.platform,
      deliveryState?.stagedProactiveMessage?.content || '',
      { stripNoResponseMarker: false },
    );
    const explicitStagedDelivery = deliveryState?.proactiveMessageStaged === true && Boolean(stagedMessage);
    // A forced terminal wrap-up (read-only/blocked hard-stop) is the model's final
    // answer produced WITHOUT the ability to call send_message itself. Gating it
    // would silently drop a stuck scheduled task's result, so deliver it even on an
    // automatic run. Ordinary mid-run plain text (model had send_message available
    // and chose not to use it) is still gated below.
    const forcedTerminal = deliveryState?.terminalWrapup === true && Boolean(resultText);
    if (!allowPlainResultFallback && !resultLooksLikeError && !forcedTerminal && !explicitStagedDelivery) {
      // Automatic run produced substantive text but never made an explicit
      // send_message decision (a deliberate no_response would have short-circuited
      // above). We suppress to avoid recurring-check spam, but surface it so a
      // genuinely dropped notification is visible rather than silently lost.
      if (resultText) {
        console.warn(
          `[Tasks] Task ${taskId} produced an undelivered result on an automatic run `
          + `(no explicit send_message decision): ${resultText.slice(0, 140)}`
        );
      }
      return {
        sent: false,
        skipped: true,
        reason: 'explicit_delivery_required',
      };
    }

    const manager = this.app?.locals?.messagingManager || this.agentEngine?.messagingManager || null;
    if (!manager) {
      return {
        sent: false,
        error: 'Messaging delivery is unavailable on this server.',
      };
    }

    let lastError = null;
    const resolvedTargets = explicitStagedDelivery
      ? [{
        platform: deliveryState.stagedProactiveMessage.platform,
        to: deliveryState.stagedProactiveMessage.to,
        mediaPath: deliveryState.stagedProactiveMessage.mediaPath || null,
      }]
      : targets;
    for (const target of resolvedTargets) {
      const message = normalizeOutgoingMessageForPlatform(
        target.platform,
        resultText || stagedMessage,
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
          mediaPath: target.mediaPath || null,
          runId: result?.runId || null,
          persistConversation: true,
          signal: this.abortController.signal,
        });
        deliveryState.messagingSent = true;
        deliveryState.proactiveMessageStaged = false;
        deliveryState.stagedProactiveMessage = null;
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
