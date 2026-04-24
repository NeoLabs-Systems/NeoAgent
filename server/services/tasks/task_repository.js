'use strict';

const db = require('../../db/database');

class TaskRepository {
  createTask(userId, normalizedTask) {
    const result = db.prepare(
      `INSERT INTO scheduled_tasks (
        user_id, agent_id, name, trigger_type, trigger_config, cron_expression, run_at, one_time,
        execution_mode, task_type, task_config, enabled
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      userId,
      normalizedTask.agentId,
      normalizedTask.name,
      normalizedTask.triggerType,
      JSON.stringify(normalizedTask.triggerConfig),
      normalizedTask.legacyCronExpression,
      normalizedTask.legacyRunAt,
      normalizedTask.legacyOneTime ? 1 : 0,
      normalizedTask.executionMode,
      normalizedTask.taskType,
      JSON.stringify(normalizedTask.taskConfig),
      normalizedTask.enabled ? 1 : 0,
    );
    return result.lastInsertRowid;
  }

  updateTask(taskId, userId, normalizedTask) {
    db.prepare(
      `UPDATE scheduled_tasks
       SET agent_id = ?, name = ?, trigger_type = ?, trigger_config = ?, cron_expression = ?, run_at = ?,
           one_time = ?, execution_mode = ?, task_type = ?, task_config = ?, enabled = ?
       WHERE id = ? AND user_id = ?`
    ).run(
      normalizedTask.agentId,
      normalizedTask.name,
      normalizedTask.triggerType,
      JSON.stringify(normalizedTask.triggerConfig),
      normalizedTask.legacyCronExpression,
      normalizedTask.legacyRunAt,
      normalizedTask.legacyOneTime ? 1 : 0,
      normalizedTask.executionMode,
      normalizedTask.taskType,
      JSON.stringify(normalizedTask.taskConfig),
      normalizedTask.enabled ? 1 : 0,
      taskId,
      userId,
    );
  }

  deleteTask(taskId, userId) {
    db.prepare('DELETE FROM scheduled_tasks WHERE id = ? AND user_id = ?').run(taskId, userId);
  }

  deleteById(taskId, userId) {
    db.prepare('DELETE FROM scheduled_tasks WHERE id = ? AND user_id = ?').run(taskId, userId);
  }

  getTaskById(taskId, userId) {
    return db.prepare('SELECT * FROM scheduled_tasks WHERE id = ? AND user_id = ?').get(taskId, userId);
  }

  listTasksForAgent(userId, agentId, includeLegacyMainTasks) {
    return includeLegacyMainTasks
      ? db.prepare(
        `SELECT * FROM scheduled_tasks
         WHERE user_id = ? AND (agent_id = ? OR agent_id IS NULL)
         ORDER BY created_at DESC`
      ).all(userId, agentId)
      : db.prepare(
        `SELECT * FROM scheduled_tasks
         WHERE user_id = ? AND agent_id = ?
         ORDER BY created_at DESC`
      ).all(userId, agentId);
  }

  listEnabledTasks() {
    return db.prepare('SELECT * FROM scheduled_tasks WHERE enabled = 1').all();
  }

  listDueOneTimeTasks() {
    return db.prepare(
      `SELECT * FROM scheduled_tasks
       WHERE trigger_type = 'schedule'
         AND one_time = 1
         AND enabled = 1
         AND run_at IS NOT NULL
         AND run_at <= datetime('now')`
    ).all();
  }

  listEnabledByTriggerTypes(triggerTypes) {
    if (!Array.isArray(triggerTypes) || triggerTypes.length === 0) {
      return [];
    }
    const placeholders = triggerTypes.map(() => '?').join(', ');
    return db.prepare(
      `SELECT * FROM scheduled_tasks
       WHERE enabled = 1
         AND trigger_type IN (${placeholders})`
    ).all(...triggerTypes);
  }

  listEnabledWhatsappEventTasks(userId, agentId) {
    return db.prepare(
      `SELECT * FROM scheduled_tasks
       WHERE enabled = 1 AND user_id = ? AND agent_id = ? AND trigger_type = 'whatsapp_personal_message_received'`
    ).all(userId, agentId);
  }

  markTaskTriggered(taskId, userId, fingerprint) {
    db.prepare(
      `UPDATE scheduled_tasks
       SET last_triggered_at = datetime('now'), last_trigger_fingerprint = ?
       WHERE id = ? AND user_id = ?`
    ).run(fingerprint, taskId, userId);
  }

  markTaskTriggerCheckpoint(taskId, fingerprint) {
    db.prepare(
      `UPDATE scheduled_tasks
       SET last_triggered_at = datetime('now'), last_trigger_fingerprint = ?
       WHERE id = ?`
    ).run(fingerprint, taskId);
  }

  markTaskRun(taskId, userId) {
    db.prepare('UPDATE scheduled_tasks SET last_run = datetime(\'now\') WHERE id = ? AND user_id = ?').run(taskId, userId);
  }

  updateTaskConfig(taskId, userId, taskConfig) {
    db.prepare('UPDATE scheduled_tasks SET task_config = ? WHERE id = ? AND user_id = ?')
      .run(JSON.stringify(taskConfig), taskId, userId);
  }

  getAgentSetting(userId, agentId, key) {
    return db.prepare('SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?')
      .get(userId, agentId, key);
  }

  getUserSetting(userId, key) {
    return db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
      .get(userId, key);
  }

  getTaskConversation(userId, agentId, platform, platformChatId) {
    return db.prepare(
      'SELECT id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id = ?'
    ).get(userId, agentId, platform, platformChatId);
  }

  createTaskConversation({ id, userId, agentId, platform, platformChatId, title }) {
    db.prepare(
      'INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(id, userId, agentId, platform, platformChatId, title);
  }
}

module.exports = {
  TaskRepository,
};
