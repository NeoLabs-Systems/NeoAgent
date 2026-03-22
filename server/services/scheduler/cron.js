const cron = require('node-cron');
const crypto = require('crypto');
const db = require('../../db/database');

class Scheduler {
  constructor(io, agentEngine, app = null) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.app = app;
    this.jobs = new Map();
    this.heartbeatJob = null;
  }

  start() {
    this._loadFromDB();
    this._startHeartbeat();
    this._startOneTimePoller();
    console.log('[Scheduler] Started');
  }

  stop() {
    for (const [id, job] of this.jobs) {
      job.task.stop();
    }
    this.jobs.clear();
    if (this.heartbeatJob) {
      this.heartbeatJob.stop();
      this.heartbeatJob = null;
    }
    if (this.oneTimePoller) {
      this.oneTimePoller.stop();
      this.oneTimePoller = null;
    }
    console.log('[Scheduler] Stopped');
  }

  _startHeartbeat() {
    // Heartbeat runs every 5 minutes
    this.heartbeatJob = cron.schedule('*/5 * * * *', async () => {
      try {
        await this._runHeartbeat();
      } catch (err) {
        console.error('[Heartbeat] Error:', err.message);
      }
    });
    console.log('[Scheduler] Heartbeat active (every 5 min)');
  }

  _startOneTimePoller() {
    this.oneTimePoller = cron.schedule('* * * * *', async () => {
      const due = db.prepare(
        `SELECT * FROM scheduled_tasks WHERE one_time = 1 AND enabled = 1 AND run_at IS NOT NULL AND run_at <= datetime('now')`
      ).all();

      for (const task of due) {
        const config = JSON.parse(task.task_config || '{}');
        // Remove from memory before executing so a slow run can't double-fire
        this.jobs.delete(task.id);
        try {
          await this._executeTask(task.id, task.user_id, config);
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

  async _runHeartbeat() {
    const users = db.prepare('SELECT id FROM users').all();

    for (const user of users) {
      const settings = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
        .get(user.id, 'heartbeat_enabled');

      if (!settings || settings.value !== 'true') continue;

      const prompt = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
        .get(user.id, 'heartbeat_prompt');

      const defaultPrompt = 'You are running a silent background heartbeat check. Scan memory, pending tasks, and reminders. DEFAULT ACTION IS SILENCE — do NOT contact the user unless something is genuinely important (urgent deadline, critical failure, time-sensitive action required, or something the user would be upset to miss). If nothing important is found, do nothing and end the run quietly. Never send routine updates, summaries, or "all clear" messages.';

      const lastPlatform = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(user.id, 'last_platform')?.value;
      const lastChatId = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(user.id, 'last_chat_id')?.value;
      const platformHint = lastPlatform && lastChatId
        ? `\n\nOnly if you found something that genuinely requires the user's attention, send_message to platform="${lastPlatform}" to="${lastChatId}". Otherwise stay silent.`
        : '';

      this.io.to(`user:${user.id}`).emit('heartbeat:running', { timestamp: new Date().toISOString() });

      try {
        if (this.agentEngine) {
          const convId = this._getMessagingConversation(user.id);

          await this.agentEngine.run(user.id, (prompt?.value || defaultPrompt) + platformHint, {
            triggerType: 'heartbeat',
            triggerSource: 'heartbeat',
            app: this.app,
            ...(convId ? { conversationId: convId } : {}),
          });
        }
      } catch (err) {
        console.error(`[Heartbeat] Error for user ${user.id}:`, err.message);
      }
    }
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
    let config = JSON.parse(task.task_config || '{}');
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
      const config = JSON.parse(t.task_config || '{}');
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
        model: config.model || null
      };
    });
  }

  runTaskNow(taskId, userId) {
    const task = db.prepare('SELECT * FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(taskId, userId);
    if (!task) throw new Error('Task not found');

    const config = JSON.parse(task.task_config || '{}');
    this._executeTask(taskId, userId, config);
    return { running: true };
  }

  _scheduleTask(taskId, userId, cronExpression, config) {
    const task = cron.schedule(cronExpression, async () => {
      await this._executeTask(taskId, userId, config);
    });

    this.jobs.set(taskId, { task, userId, config });
  }

  async _executeTask(taskId, userId, config) {
    db.prepare('UPDATE scheduled_tasks SET last_run = datetime(\'now\') WHERE id = ?').run(taskId);

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
      if (this.agentEngine && config.prompt) {
        let notifyHint = '';

        if (config.callTo) {
          notifyHint = `\n\nThis task is configured to notify the user by phone. Use the make_call tool to call "${config.callTo}" with an appropriate greeting based on your findings. The configured greeting hint is: "${config.callGreeting || 'Hello, this is your scheduled reminder.'}"`;
        } else {
          notifyHint = config.notifyPlatform && config.notifyTo
            ? `\n\nIf your task result is worth notifying the user about, send it proactively via send_message to platform="${config.notifyPlatform}" to="${config.notifyTo}".`
            : '';
        }

        const convId = this._getMessagingConversation(userId);

        const runOptions = {
          triggerType: 'scheduler',
          triggerSource: 'scheduler',
          app: this.app,
          ...(convId ? { conversationId: convId } : {}),
          taskId,
        };
        const result = typeof this.agentEngine.runWithModel === 'function'
          ? await this.agentEngine.runWithModel(userId, config.prompt + notifyHint, runOptions, config.model || null)
          : await this.agentEngine.run(userId, config.prompt + notifyHint, runOptions);
        this.io.to(`user:${userId}`).emit('scheduler:task_complete', { taskId, result });
      }
    } catch (err) {
      console.error(`[Scheduler] Task ${taskId} error:`, err.message);
      this.io.to(`user:${userId}`).emit('scheduler:task_error', { taskId, error: err.message });
    }
  }

  _loadFromDB() {
    const tasks = db.prepare('SELECT * FROM scheduled_tasks WHERE enabled = 1').all();
    let loaded = 0;
    for (const task of tasks) {
      try {
        const config = JSON.parse(task.task_config || '{}');
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

  _getDefaultNotifyTarget(userId) {
    const platform = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
      .get(userId, 'last_platform')?.value || null;
    const to = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
      .get(userId, 'last_chat_id')?.value || null;
    return { platform, to };
  }
}

module.exports = { Scheduler };
