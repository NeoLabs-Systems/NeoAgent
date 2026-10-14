'use strict';

const express = require('express');
const db = require('../db/database');
const { getErrorMessage } = require('../services/bootstrap_helpers');
const { requireAuth } = require('../middleware/auth');
const { normalizeJsonObject } = require('../services/tasks/utils');

const router = express.Router();

router.use(requireAuth);

// The fences are the enabled geofence tasks: each task watches one place.
router.get('/geofences', (req, res) => {
  const taskRuntime = req.app.locals.taskRuntime;
  const tasks = taskRuntime
    ? taskRuntime.taskRepository.listEnabledEventTasks(req.session.userId, null, 'geofence_event')
    : [];
  const geofences = tasks.map((task) => {
    const config = normalizeJsonObject(task.trigger_config);
    return {
      id: task.id,
      label: config.label,
      latitude: config.latitude,
      longitude: config.longitude,
      radius_meters: config.radiusMeters,
    };
  });
  res.json({ geofences });
});

router.post('/geofence', (req, res) => {
  const fenceId = Number(req.body?.fence_id);
  const transition = req.body?.transition === 'exit' ? 'exit' : 'enter';
  if (!Number.isInteger(fenceId) || fenceId <= 0) {
    return res.status(400).json({ error: 'fence_id is required' });
  }
  res.json({ success: true });
  req.app.locals.taskRuntime?.publishEvent('geofence', {
    userId: req.session.userId,
    fenceId,
    transition,
    latitude: Number(req.body.latitude) || null,
    longitude: Number(req.body.longitude) || null,
    occurredAt: new Date().toISOString(),
  });
});

router.post('/notification', (req, res) => {
  const { app_package, title, body, action_taken } = req.body;
  const notification = {
    appPackage: app_package || 'unknown',
    title: title || '',
    body: body || '',
    actionTaken: action_taken || 'none',
  };

  try {
    const userRow = db.prepare('SELECT id FROM users WHERE id = ?').get(req.session.userId);
    if (!userRow) return res.status(401).json({ error: 'Unauthorized' });

    console.log(`[Triggers] Notification event for user ${req.session.userId}`);

    db.prepare(`
      INSERT INTO notification_history (user_id, app_package, title, body, action_taken)
      VALUES (?, ?, ?, ?, ?)
    `).run(req.session.userId, notification.appPackage, notification.title, notification.body, notification.actionTaken);

    // Respond before the tasks run so the mobile client doesn't retry.
    res.json({ success: true, message: 'Notification trigger processed and stored' });
  } catch (err) {
    console.error('[Triggers] Notification error:', getErrorMessage(err));
    res.status(500).json({ error: 'Failed to process notification trigger' });
    return;
  }

  req.app.locals.taskRuntime?.publishEvent('android_notification', {
    userId: req.session.userId,
    ...notification,
    receivedAt: new Date().toISOString(),
  });
});

module.exports = router;
