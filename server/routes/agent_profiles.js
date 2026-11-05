'use strict';

const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const {
  archiveAgent,
  createAgent,
  ensureMainAgent,
  getDefaultAgent,
  listAgents,
  setDefaultAgent,
  updateAgent,
} = require('../services/agents/manager');
const { agentNames, listTasks, serializeTask } = require('../services/agents/tasks');
const { cancelTaskForUser } = require('../services/ai/loop/agent_tasks');

router.use(requireAuth);

router.get('/', (req, res) => {
  try {
    ensureMainAgent(req.session.userId);
    res.json({
      agents: listAgents(req.session.userId, {
        includeArchived: req.query.includeArchived === 'true',
      }),
      defaultAgentId: getDefaultAgent(req.session.userId)?.id || null,
    });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Work agents handed to each other, open first.
router.get('/tasks', (req, res) => {
  try {
    const userId = req.session.userId;
    const names = agentNames(userId);
    res.json({ tasks: listTasks(userId).map((row) => serializeTask(row, names)) });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/tasks/:taskId/cancel', (req, res) => {
  try {
    const task = cancelTaskForUser(req.app.locals.agentEngine, req.session.userId, req.params.taskId);
    if (!task) return res.status(404).json({ error: 'Task not found.' });
    res.json(task);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/', (req, res) => {
  try {
    const agent = createAgent(req.session.userId, req.body || {});
    res.status(201).json(agent);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.put('/:id', (req, res) => {
  try {
    res.json(updateAgent(req.session.userId, req.params.id, req.body || {}));
  } catch (err) {
    if (err.message === 'Agent not found.') return res.status(404).json({ error: err.message });
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.post('/:id/default', (req, res) => {
  try {
    res.json(setDefaultAgent(req.session.userId, req.params.id));
  } catch (err) {
    if (err.message === 'Agent not found.') return res.status(404).json({ error: err.message });
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.delete('/:id', (req, res) => {
  try {
    res.json(archiveAgent(req.session.userId, req.params.id));
  } catch (err) {
    if (err.message === 'Agent not found.') return res.status(404).json({ error: err.message });
    res.status(400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
