'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

const router = express.Router();

function parseTaskId(value) {
  const taskId = Number.parseInt(value, 10);
  if (!Number.isInteger(taskId) || taskId <= 0) throw new Error('Invalid task id.');
  return taskId;
}

router.post('/:taskId/deliver', async (req, res) => {
  try {
    const result = await req.app.locals.taskWebhookService.deliver(
      parseTaskId(req.params.taskId),
      req.headers,
      req.rawBody || JSON.stringify(req.body || {}),
      req.body || {},
    );
    res.status(202).json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: sanitizeError(err) });
  }
});

router.use(requireAuth);

router.get('/:taskId', (req, res) => {
  try {
    res.json(req.app.locals.taskWebhookService.getConfiguration(
      req.session.userId,
      parseTaskId(req.params.taskId),
    ));
  } catch (err) {
    res.status(err.status || 400).json({ error: sanitizeError(err) });
  }
});

router.post('/:taskId/rotate', (req, res) => {
  try {
    res.json(req.app.locals.taskWebhookService.rotateSecret(
      req.session.userId,
      parseTaskId(req.params.taskId),
    ));
  } catch (err) {
    res.status(err.status || 400).json({ error: sanitizeError(err) });
  }
});

router.get('/:taskId/deliveries', (req, res) => {
  try {
    res.json(req.app.locals.taskWebhookService.listDeliveries(
      req.session.userId,
      parseTaskId(req.params.taskId),
      req.query?.limit,
    ));
  } catch (err) {
    res.status(err.status || 400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
