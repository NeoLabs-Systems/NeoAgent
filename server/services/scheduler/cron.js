const cron = require('node-cron');
const db = require('../../db/database');

class Scheduler {
  constructor(io, agentEngine) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.jobs = new Map();
    this.heartbeatJob = null;
  }

  start() {
    this._loadFromDB();
    this._startHeartbeat();
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
          await this.agentEngine.run(user.id, (prompt?.value || defaultPrompt) + platformHint, {
            source: 'heartbeat'
          });
        }
      } catch (err) {
        console.error(`[Heartbeat] Error for user ${user.id}:`, err.message);
      }
    }
  }

  createTask(userId, { name, cronExpression, prompt, enabled = true }) {
    if (!cron.validate(cronExpression)) {
      throw new Error(`Invalid cron expression: ${cronExpression}`);
    }

    const result = db.prepare(
      'INSERT INTO scheduled_tasks (user_id, name, cron_expression, task_type, task_config, enabled) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(userId, name, cronExpression, 'agent_prompt', JSON.stringify({ prompt }), enabled ? 1 : 0);

    const taskId = result.lastInsertRowid;

    if (enabled) {
      this._scheduleTask(taskId, userId, cronExpression, { prompt });
    }

    return { id: taskId, name, cronExpression, enabled };
  }

  updateTask(taskId, userId, updates) {
    const task = db.prepare('SELECT * FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(taskId, userId);
    if (!task) throw new Error('Task not found');

    const name = updates.name || task.name;
    const cronExpr = updates.cronExpression || task.cron_expression;
    const enabled = updates.enabled !== undefined ? updates.enabled : task.enabled;
    const config = updates.prompt ? JSON.stringify({ prompt: updates.prompt }) : task.task_config;

    if (updates.cronExpression && !cron.validate(updates.cronExpression)) {
      throw new Error(`Invalid cron expression: ${updates.cronExpression}`);
    }

    db.prepare('UPDATE scheduled_tasks SET name = ?, cron_expression = ?, task_config = ?, enabled = ? WHERE id = ?')
      .run(name, cronExpr, config, enabled ? 1 : 0, taskId);

    // Reschedule
    const existing = this.jobs.get(taskId);
    if (existing) {
      existing.task.stop();
      this.jobs.delete(taskId);
    }

    if (enabled) {
      this._scheduleTask(taskId, userId, cronExpr, JSON.parse(config));
    }

    return { id: taskId, name, cronExpression: cronExpr, enabled };
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
    return tasks.map(t => ({
      id: t.id,
      name: t.name,
      cronExpression: t.cron_expression,
      enabled: !!t.enabled,
      lastRun: t.last_run,
      nextRun: this._getNextRun(t.cron_expression),
      config: JSON.parse(t.task_config || '{}')
    }));
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

    this.io.to(`user:${userId}`).emit('scheduler:task_running', { taskId, timestamp: new Date().toISOString() });

    try {
      if (this.agentEngine && config.prompt) {
        const lastPlatform = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, 'last_platform')?.value;
        const lastChatId = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, 'last_chat_id')?.value;
        const platformHint = lastPlatform && lastChatId
          ? `\n\nIf your task result is worth notifying the user about, send it proactively via send_message to platform="${lastPlatform}" to="${lastChatId}".`
          : '';
        const result = await this.agentEngine.run(userId, config.prompt + platformHint, {
          source: 'scheduler',
          taskId
        });
        this.io.to(`user:${userId}`).emit('scheduler:task_complete', { taskId, result });
      }
    } catch (err) {
      console.error(`[Scheduler] Task ${taskId} error:`, err.message);
      this.io.to(`user:${userId}`).emit('scheduler:task_error', { taskId, error: err.message });
    }
  }

  _loadFromDB() {
    const tasks = db.prepare('SELECT * FROM scheduled_tasks WHERE enabled = 1').all();
    for (const task of tasks) {
      try {
        const config = JSON.parse(task.task_config || '{}');
        this._scheduleTask(task.id, task.user_id, task.cron_expression, config);
      } catch (err) {
        console.error(`[Scheduler] Failed to load task ${task.id}:`, err.message);
      }
    }
    console.log(`[Scheduler] Loaded ${tasks.length} tasks from DB`);
  }

  _getNextRun(cronExpression) {
    try {
      const interval = cron.schedule(cronExpression, () => {});
      interval.stop();
      // node-cron doesn't expose nextRun; we just return null
      return null;
    } catch {
      return null;
    }
  }
}

module.exports = { Scheduler };
