const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

// List scheduled tasks
router.get('/', (req, res) => {
  const scheduler = req.app.locals.scheduler;
  res.json(scheduler.listTasks(req.session.userId));
});

// Create a new scheduled task
router.post('/', (req, res) => {
  try {
    const { name, cronExpression, prompt, enabled, model } = req.body;
    if (!name || !cronExpression || !prompt) {
      return res.status(400).json({ error: 'name, cronExpression, and prompt required' });
    }

    const scheduler = req.app.locals.scheduler;
    const task = scheduler.createTask(req.session.userId, { name, cronExpression, prompt, enabled, model });
    res.status(201).json(task);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

// Update a scheduled task
router.put('/:id', (req, res) => {
  try {
    const scheduler = req.app.locals.scheduler;
    const task = scheduler.updateTask(parseInt(req.params.id), req.session.userId, req.body);
    res.json(task);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

// Delete a scheduled task
router.delete('/:id', (req, res) => {
  try {
    const scheduler = req.app.locals.scheduler;
    scheduler.deleteTask(parseInt(req.params.id), req.session.userId);
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

// Run a task immediately
router.post('/:id/run', (req, res) => {
  try {
    const scheduler = req.app.locals.scheduler;
    const result = scheduler.runTaskNow(parseInt(req.params.id), req.session.userId);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
