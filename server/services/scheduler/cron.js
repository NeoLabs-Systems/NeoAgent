const cron = require('node-cron');
const crypto = require('crypto');
const db = require('../../db/database');

const MAX_SCHEDULER_AUTONOMOUS_RETRIES = 1;
const MAX_RECURRING_TASK_START_DELAY_MS = 90 * 1000;

class Scheduler {
  constructor(io, agentEngine, app = null) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.app = app;
    this.jobs = new Map();
    this.userExecutionChains = new Map();
    this.pendingTaskExecutions = new Set();
    this.runningTaskExecutions = new Set();
  }

  start() {
    this._loadFromDB();
    this._startOneTimePoller();
    console.log('[Scheduler] Started');
  }

  stop() {
    for (const [id, job] of this.jobs) {
      job.task.stop();
    }
    this.jobs.clear();
    if (this.oneTimePoller) {
      this.oneTimePoller.stop();
      this.oneTimePoller = null;
    }
    console.log('[Scheduler] Stopped');
  }

  _startOneTimePoller() {
    this.oneTimePoller = cron.schedule('* * * * *', async () => {
      const due = db.prepare(
        `SELECT * FROM scheduled_tasks WHERE one_time = 1 AND enabled = 1 AND run_at IS NOT NULL AND run_at <= datetime('now')`
      ).all();

      for (const task of due) {
        // Remove from memory before executing so a slow run can't double-fire
        this.jobs.delete(task.id);
        try {
          await this._executeTask(task.id, task.user_id, {
            scheduledAt: task.run_at || new Date().toISOString(),
            oneTime: true,
          });
        } catch (err) {
          console.error(`[Scheduler] One-time task ${task.id} error:`, err.message);
        }
        // Auto-delete after execution
        db.prepare('DELETE FROM scheduled_tasks WHERE id = ?').run(task.id);
        this.io.to(`user:${task.user_id}`).emit('scheduler:task_deleted', { taskId: task.id });
      }
    });
    console.log('[Scheduler] One-time poller active (every 1 min)');
  }

  createTask(userId, { name, cronExpression, prompt, enabled = true, callTo = null, callGreeting = null, model = null, runAt = null, oneTime = false }) {
    const notifyTarget = this._getDefaultNotifyTarget(userId);

    if (oneTime) {
      if (!runAt) throw new Error('runAt is required for one-time tasks');
      const runAtDate = new Date(runAt);
      if (isNaN(runAtDate.getTime())) throw new Error(`Invalid runAt value: ${runAt}`);

      const config = { prompt };
      if (callTo) { config.callTo = callTo; config.callGreeting = callGreeting || ''; }
      if (typeof model === 'string' && model.trim()) config.model = model.trim();
      if (notifyTarget.platform && notifyTarget.to) {
        config.notifyPlatform = notifyTarget.platform;
        config.notifyTo = notifyTarget.to;
      }

      const result = db.prepare(
        'INSERT INTO scheduled_tasks (user_id, name, cron_expression, run_at, one_time, task_type, task_config, enabled) VALUES (?, ?, NULL, ?, 1, ?, ?, ?)'
      ).run(userId, name, runAtDate.toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, ''), 'agent_prompt', JSON.stringify(config), enabled ? 1 : 0);

      return { id: result.lastInsertRowid, name, runAt: runAtDate.toISOString(), oneTime: true, enabled, model: config.model || null };
    }

    if (!cronExpression || !cron.validate(cronExpression)) {
      throw new Error(`Invalid cron expression: ${cronExpression}`);
    }

    const config = { prompt };
    if (callTo) { config.callTo = callTo; config.callGreeting = callGreeting || ''; }
    if (typeof model === 'string' && model.trim()) config.model = model.trim();
    if (notifyTarget.platform && notifyTarget.to) {
      config.notifyPlatform = notifyTarget.platform;
      config.notifyTo = notifyTarget.to;
    }

    const result = db.prepare(
      'INSERT INTO scheduled_tasks (user_id, name, cron_expression, task_type, task_config, enabled) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(userId, name, cronExpression, 'agent_prompt', JSON.stringify(config), enabled ? 1 : 0);

    const taskId = result.lastInsertRowid;

    if (enabled) {
      this._scheduleTask(taskId, userId, cronExpression, config);
    }

    return { id: taskId, name, cronExpression, enabled, callTo: config.callTo || null, model: config.model || null };
  }

  updateTask(taskId, userId, updates) {
    const task = db.prepare('SELECT * FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(taskId, userId);
    if (!task) throw new Error('Task not found');

    const name = updates.name || task.name;
    const cronExpr = updates.cronExpression || task.cron_expression;
    const enabled = updates.enabled !== undefined ? updates.enabled : task.enabled;

    // Merge config — start from existing, apply any changes
    let config = this._normalizeTaskConfig(task.task_config);
    if (updates.prompt !== undefined) config.prompt = updates.prompt;
    if (updates.callTo !== undefined) config.callTo = updates.callTo || null;
    if (updates.callGreeting !== undefined) config.callGreeting = updates.callGreeting || null;
    if (updates.model !== undefined) {
      if (typeof updates.model === 'string' && updates.model.trim()) {
        config.model = updates.model.trim();
      } else {
        delete config.model;
      }
    }
    if (!config.notifyPlatform || !config.notifyTo) {
      const notifyTarget = this._getDefaultNotifyTarget(userId);
      if (notifyTarget.platform && notifyTarget.to) {
        config.notifyPlatform = notifyTarget.platform;
        config.notifyTo = notifyTarget.to;
      }
    }
    // Clean up nulls
    if (!config.callTo) { delete config.callTo; delete config.callGreeting; }

    if (updates.cronExpression && !cron.validate(updates.cronExpression)) {
      throw new Error(`Invalid cron expression: ${updates.cronExpression}`);
    }

    db.prepare('UPDATE scheduled_tasks SET name = ?, cron_expression = ?, task_config = ?, enabled = ? WHERE id = ?')
      .run(name, cronExpr, JSON.stringify(config), enabled ? 1 : 0, taskId);

    // Reschedule
    const existing = this.jobs.get(taskId);
    if (existing) {
      existing.task.stop();
      this.jobs.delete(taskId);
    }

    if (enabled) {
      this._scheduleTask(taskId, userId, cronExpr, config);
    }

    return { id: taskId, name, cronExpression: cronExpr, enabled, callTo: config.callTo || null, model: config.model || null };
  }

  deleteTask(taskId, userId) {
    const task = db.prepare('SELECT * FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(taskId, userId);
    if (!task) throw new Error('Task not found');

    const existing = this.jobs.get(taskId);
    if (existing) {
      existing.task.stop();
      this.jobs.delete(taskId);
    }

    db.prepare('DELETE FROM scheduled_tasks WHERE id = ?').run(taskId);
    return { deleted: true };
  }

  listTasks(userId) {
    const tasks = db.prepare('SELECT * FROM scheduled_tasks WHERE user_id = ? ORDER BY created_at DESC').all(userId);
    return tasks.map(t => {
      const config = this._normalizeTaskConfig(t.task_config);
      return {
        id: t.id,
        name: t.name,
        cronExpression: t.cron_expression,
        runAt: t.run_at || null,
        oneTime: !!t.one_time,
        enabled: !!t.enabled,
        lastRun: t.last_run,
        nextRun: t.one_time ? t.run_at : this._getNextRun(t.cron_expression),
        config,
        prompt: config.prompt || '',
        model: config.model || null
      };
    });
  }

  runTaskNow(taskId, userId) {
    const task = db.prepare('SELECT * FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(taskId, userId);
    if (!task) throw new Error('Task not found');

    this._executeTask(taskId, userId, {
      scheduledAt: new Date().toISOString(),
      manual: true,
      oneTime: !!task.one_time,
    });
    return { running: true };
  }

  _scheduleTask(taskId, userId, cronExpression, _config) {
    const task = cron.schedule(cronExpression, async () => {
      await this._executeTask(taskId, userId, {
        scheduledAt: new Date().toISOString(),
        cronExpression,
        manual: false,
        oneTime: false,
      });
    });

    this.jobs.set(taskId, { task, userId });
  }

  async _executeTask(taskId, userId, executionMeta = {}) {
    const executionKey = `${userId}:${taskId}`;
    if (this.pendingTaskExecutions.has(executionKey) || this.runningTaskExecutions.has(executionKey)) {
      this.io.to(`user:${userId}`).emit('scheduler:task_skipped', {
        taskId,
        reason: 'already_running_or_queued',
        timestamp: new Date().toISOString(),
      });
      return { skipped: true, reason: 'already_running_or_queued' };
    }

    this.pendingTaskExecutions.add(executionKey);
    this.pendingTaskExecutions.delete(executionKey);
    this.runningTaskExecutions.add(executionKey);
    try {
      return await this._executeTaskSerial(taskId, userId, executionMeta);
    } finally {
      this.runningTaskExecutions.delete(executionKey);
    }
  }

  async _executeTaskSerial(taskId, userId, executionMeta = {}) {
    const task = db.prepare('SELECT * FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(taskId, userId);
    if (!task || !task.enabled) {
      return { skipped: true, reason: 'missing_or_disabled' };
    }

    const config = this._normalizeTaskConfig(task.task_config);
    const scheduledAtMs = executionMeta.scheduledAt ? new Date(executionMeta.scheduledAt).getTime() : NaN;
    const isLateRecurringRun = (
      executionMeta.manual !== true
      && executionMeta.oneTime !== true
      && Number.isFinite(scheduledAtMs)
      && (Date.now() - scheduledAtMs) > MAX_RECURRING_TASK_START_DELAY_MS
    );
    if (isLateRecurringRun) {
      this.io.to(`user:${userId}`).emit('scheduler:task_skipped', {
        taskId,
        reason: 'stale_start_delay',
        scheduledAt: executionMeta.scheduledAt,
        timestamp: new Date().toISOString(),
      });
      console.warn(
        `[Scheduler] Skipping stale recurring task ${taskId}; start delay ${Date.now() - scheduledAtMs}ms exceeded ${MAX_RECURRING_TASK_START_DELAY_MS}ms`
      );
      return { skipped: true, reason: 'stale_start_delay' };
    }

    db.prepare('UPDATE scheduled_tasks SET last_run = datetime(\'now\') WHERE id = ?').run(taskId);
    const deliveryState = {
      messagingSent: false,
      lastSentMessage: '',
      sentMessages: [],
    };

    const taskName = task.name || `Task ${taskId}`;
    const scheduleInfo = task.one_time ? 'One-time' : task.cron_expression;

    if (!config.callTo && (!config.notifyPlatform || !config.notifyTo)) {
      const notifyTarget = this._getDefaultNotifyTarget(userId);
      if (notifyTarget.platform && notifyTarget.to) {
        config.notifyPlatform = notifyTarget.platform;
        config.notifyTo = notifyTarget.to;
        db.prepare('UPDATE scheduled_tasks SET task_config = ? WHERE id = ?')
          .run(JSON.stringify(config), taskId);
      }
    }

    this.io.to(`user:${userId}`).emit('scheduler:task_running', { taskId, timestamp: new Date().toISOString() });

    try {
      if (this.agentEngine && config.prompt !== undefined) {
        let notifyHint = '';

        if (config.callTo) {
          notifyHint = `\n\nThis task is configured to notify the user by phone. Use the make_call tool to call "${config.callTo}" with an appropriate greeting based on your findings. The configured greeting hint is: "${config.callGreeting || 'Hello, this is your scheduled reminder.'}"`;
        } else {
          notifyHint = config.notifyPlatform && config.notifyTo
            ? `\n\nIf your task result is worth notifying the user about, send it proactively via send_message to platform="${config.notifyPlatform}" to="${config.notifyTo}".`
            : '';
        }

        notifyHint += [
          '',
          'Critical reliability rules for scheduled notifications:',
          '- For time-sensitive external-world claims (for example: mission status, launch timeline, incidents, markets, weather, sports, or wording like "today/now/yesterday"), do not rely on memory alone.',
          '- Verify with at least one fresh source tool in this run before notifying (for example browser_navigate, http_request, search_files where applicable).',
          '- If you cannot verify current status, send a short uncertainty notice and ask whether to retry later. Do not invent timeline details.',
          '- Send at most one proactive user notification per run unless the task explicitly requires multi-part output.'
        ].join('\n');

        const taskContext = `[SYSTEM: Executing Scheduled Task]\nTask Name: ${taskName}\nSchedule: ${scheduleInfo}\n\n`;
        const userPrompt = config.prompt || `You have been triggered by the scheduler to run the background task "${taskName}". Please execute any necessary checks or actions associated with this task.`;
        const basePrompt = taskContext + userPrompt + notifyHint;

        const convId = this._getTaskConversation(userId, taskId, taskName);

        let attempt = 0;
        let recoveryNote = '';
        while (attempt <= MAX_SCHEDULER_AUTONOMOUS_RETRIES) {
          const finalPrompt = basePrompt + recoveryNote;
          const runOptions = {
            triggerType: 'scheduler',
            triggerSource: 'scheduler',
            app: this.app,
            ...(convId ? { conversationId: convId } : {}),
            taskId,
            deliveryState,
            allowMultipleProactiveMessages: config.allowMultipleMessages === true || config.allow_multiple_messages === true,
            skipTaskAnalysis: true,
            skipGlobalRecall: true,
            skipConversationHistory: true,
            skipConversationMaintenance: true,
            skipRunContextPersistence: true,
            skipVerifier: true,
            stream: false,
          };

          try {
            const result = typeof this.agentEngine.runWithModel === 'function'
              ? await this.agentEngine.runWithModel(userId, finalPrompt, runOptions, config.model || null)
              : await this.agentEngine.run(userId, finalPrompt, runOptions);
            this.io.to(`user:${userId}`).emit('scheduler:task_complete', { taskId, result });
            return result;
          } catch (err) {
            if (attempt >= MAX_SCHEDULER_AUTONOMOUS_RETRIES) {
              throw err;
            }

            attempt += 1;
            const errMsg = String(err?.message || 'Unknown runtime error');
            recoveryNote = [
              '\n\n[SYSTEM: Previous scheduler attempt failed]',
              `Error: ${errMsg}`,
              'Continue autonomously end-to-end: retry failed steps, choose alternative tools/paths when needed, and only contact the user if no safe path remains.'
            ].join('\n');
            console.warn(`[Scheduler] Task ${taskId} autonomous retry ${attempt}/${MAX_SCHEDULER_AUTONOMOUS_RETRIES}: ${errMsg}`);
            this.io.to(`user:${userId}`).emit('scheduler:task_running', {
              taskId,
              timestamp: new Date().toISOString(),
              retry: attempt,
            });
          }
        }
      }
    } catch (err) {
      console.error(`[Scheduler] Task ${taskId} error:`, err.message);
      this.io.to(`user:${userId}`).emit('scheduler:task_error', { taskId, error: err.message });
      return { skipped: false, error: err.message };
    }
  }

  _enqueueUserExecution(userId, fn) {
    const previous = this.userExecutionChains.get(userId) || Promise.resolve();
    const current = previous
      .catch(() => { })
      .then(() => fn());
    const cleanup = current.finally(() => {
      if (this.userExecutionChains.get(userId) === cleanup) {
        this.userExecutionChains.delete(userId);
      }
    });
    this.userExecutionChains.set(userId, cleanup);
    return cleanup;
  }

  _loadFromDB() {
    const tasks = db.prepare('SELECT * FROM scheduled_tasks WHERE enabled = 1').all();
    let loaded = 0;
    for (const task of tasks) {
      try {
        const config = this._normalizeTaskConfig(task.task_config);
        if (task.one_time) {
          // One-time tasks are handled by the poller; nothing to register here
          // But if it's already past due when we restart, the poller will catch it in <1 min
        } else if (task.cron_expression) {
          this._scheduleTask(task.id, task.user_id, task.cron_expression, config);
          loaded++;
        }
      } catch (err) {
        console.error(`[Scheduler] Failed to load task ${task.id}:`, err.message);
      }
    }
    console.log(`[Scheduler] Loaded ${loaded} recurring tasks from DB`);
  }

  _normalizeTaskConfig(rawConfig) {
    let parsed = rawConfig;
    if (typeof parsed === 'string') {
      try {
        parsed = JSON.parse(parsed || '{}');
      } catch {
        const fallbackPrompt = parsed.trim();
        return fallbackPrompt ? { prompt: fallbackPrompt } : {};
      }
    }

    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return {};
    }

    const config = { ...parsed };
    if (config.prompt !== undefined && config.prompt !== null && typeof config.prompt !== 'string') {
      config.prompt = String(config.prompt);
    }
    if (config.model !== undefined && config.model !== null && typeof config.model !== 'string') {
      config.model = String(config.model);
    }

    return config;
  }

  _getNextRun(cronExpression) {
    try {
      const interval = cron.schedule(cronExpression, () => { });
      interval.stop();
      // node-cron doesn't expose nextRun; we just return null
      return null;
    } catch {
      return null;
    }
  }
  _getMessagingConversation(userId) {
    const lastPlatform = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, 'last_platform')?.value;
    const lastChatId = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, 'last_chat_id')?.value;
    if (!lastPlatform || !lastChatId) return null;

    let convRow = db.prepare(
      'SELECT id FROM conversations WHERE user_id = ? AND platform = ? AND platform_chat_id = ?'
    ).get(userId, lastPlatform, lastChatId);

    if (!convRow) {
      const convId = crypto.randomUUID();
      db.prepare(
        'INSERT INTO conversations (id, user_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?)'
      ).run(convId, userId, lastPlatform, lastChatId, `${lastPlatform} — ${lastChatId}`);
      convRow = { id: convId };
    }

    return convRow.id;
  }

  _getTaskConversation(userId, taskId, taskName) {
    const platform = 'scheduler';
    const platformChatId = `task:${taskId}`;

    let convRow = db.prepare(
      'SELECT id FROM conversations WHERE user_id = ? AND platform = ? AND platform_chat_id = ?'
    ).get(userId, platform, platformChatId);

    if (!convRow) {
      const convId = crypto.randomUUID();
      db.prepare(
        'INSERT INTO conversations (id, user_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?)'
      ).run(convId, userId, platform, platformChatId, `Scheduler — ${taskName || `Task ${taskId}`}`);
      convRow = { id: convId };
    }

    return convRow.id;
  }

  _getDefaultNotifyTarget(userId) {
    const platform = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
      .get(userId, 'last_platform')?.value || null;
    const to = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
      .get(userId, 'last_chat_id')?.value || null;
    return { platform, to };
  }
}

module.exports = { Scheduler };
