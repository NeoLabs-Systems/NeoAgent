const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');

router.use(requireAuth);

router.get('/', (req, res) => {
  try {
    const tasks = req.app.locals.taskRuntime;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    res.json(tasks.listTasks(req.session.userId, { agentId }));
  } catch (error) {
    (req.app.locals.logger?.error || console.error)('[Tasks] Failed to list tasks', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/catalog', (req, res) => {
  try {
    const tasks = req.app.locals.taskRuntime;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    res.json(tasks.getTriggerCatalog(req.session.userId, { agentId }));
  } catch (error) {
    (req.app.locals.logger?.error || console.error)('[Tasks] Failed to load trigger catalog', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/', async (req, res) => {
  try {
    const tasks = req.app.locals.taskRuntime;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const {
      name, triggerType, trigger_type, triggerConfig, trigger_config,
      taskType, task_type, taskConfig, task_config, enabled,
      prompt, callTo, callGreeting, model,
      oneTime, one_time, cronExpression, cron_expression, runAt, run_at,
    } = req.body || {};
    const task = await tasks.createTask(req.session.userId, {
      name, triggerType, trigger_type, triggerConfig, trigger_config,
      taskType, task_type, taskConfig, task_config, enabled,
      prompt, callTo, callGreeting, model,
      oneTime, one_time, cronExpression, cron_expression, runAt, run_at,
      agentId,
    });
    res.status(201).json(task);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const taskId = Number.parseInt(req.params.id, 10);
    if (!Number.isInteger(taskId) || taskId <= 0) {
      return res.status(400).json({ error: 'Invalid task id' });
    }
    const tasks = req.app.locals.taskRuntime;
    const {
      name, triggerType, trigger_type, triggerConfig, trigger_config,
      taskType, task_type, taskConfig, task_config, enabled,
      prompt, callTo, callGreeting, model,
      oneTime, one_time, cronExpression, cron_expression, runAt, run_at,
    } = req.body || {};
    const task = await tasks.updateTask(taskId, req.session.userId, {
      name, triggerType, trigger_type, triggerConfig, trigger_config,
      taskType, task_type, taskConfig, task_config, enabled,
      prompt, callTo, callGreeting, model,
      oneTime, one_time, cronExpression, cron_expression, runAt, run_at,
    });
    res.json(task);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.delete('/:id', (req, res) => {
  try {
    const taskId = Number.parseInt(req.params.id, 10);
    if (!Number.isInteger(taskId) || taskId <= 0) {
      return res.status(400).json({ error: 'Invalid task id' });
    }
    const tasks = req.app.locals.taskRuntime;
    tasks.deleteTask(taskId, req.session.userId);
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.post('/:id/run', (req, res) => {
  try {
    const taskId = Number.parseInt(req.params.id, 10);
    if (!Number.isInteger(taskId) || taskId <= 0) {
      return res.status(400).json({ error: 'Invalid task id' });
    }
    const tasks = req.app.locals.taskRuntime;
    const result = tasks.runTaskNow(taskId, req.session.userId);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
