'use strict';

const express = require('express');
const db = require('../db/database');
const { getErrorMessage } = require('../services/bootstrap_helpers');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth);

router.post('/geofence', async (req, res) => {
  const { label, latitude, longitude, radius_meters, action } = req.body;

  try {
    const userRow = db.prepare('SELECT id FROM users WHERE id = ?').get(req.session.userId);
    if (!userRow) return res.status(401).json({ error: 'Unauthorized' });

    console.log(`[Triggers] Geofence event for user ${req.session.userId}`);

    res.json({ success: true, message: 'Geofence trigger processed' });
  } catch (err) {
    console.error('[Triggers] Geofence error:', getErrorMessage(err));
    res.status(500).json({ error: 'Failed to process geofence trigger' });
    return;
  }

  // Fire-and-forget after response is sent — errors here must never touch res.
  Promise.resolve().then(() => {
    const agentEngine = req.app.locals.agentEngine;
    if (!agentEngine) return;
    const defaultAgentId = db.prepare('SELECT id FROM agents WHERE user_id = ? ORDER BY is_default DESC LIMIT 1').get(req.session.userId)?.id;
    if (!defaultAgentId) return;
    const prompt = [
      `A geofence event was triggered.`,
      `Location label: ${label || 'unknown'}`,
      action ? `Suggested action: ${action}` : 'Check if there are any active reminders or tasks related to this location.',
    ].join('\n');
    return agentEngine.run(req.session.userId, prompt, {
      agentId: defaultAgentId,
      triggerSource: 'tasks',
      context: { source: 'geofence', label, latitude, longitude, radius_meters },
    });
  }).catch(err => console.error('[Triggers] Geofence agent run failed:', err.message));
});

router.post('/notification', async (req, res) => {
  const { app_package, title, body, action_taken } = req.body;

  try {
    const userRow = db.prepare('SELECT id FROM users WHERE id = ?').get(req.session.userId);
    if (!userRow) return res.status(401).json({ error: 'Unauthorized' });

    console.log(`[Triggers] Notification event for user ${req.session.userId}`);

    db.prepare(`
      INSERT INTO notification_history (user_id, app_package, title, body, action_taken)
      VALUES (?, ?, ?, ?, ?)
    `).run(req.session.userId, app_package || 'unknown', title || '', body || '', action_taken || 'none');

    // Respond immediately so the mobile client doesn't retry
    res.json({ success: true, message: 'Notification trigger processed and stored' });
  } catch (err) {
    console.error('[Triggers] Notification error:', getErrorMessage(err));
    res.status(500).json({ error: 'Failed to process notification trigger' });
    return;
  }

  // Fire-and-forget after response is sent — errors here must never touch res.
  Promise.resolve().then(async () => {
    const taskRuntime = req.app.locals.taskRuntime;
    if (!taskRuntime) return;
    
    const tasks = taskRuntime.taskRepository.listEnabledByTriggerTypes(['android_notification_received']) || [];
    for (const task of tasks) {
      if (task.user_id !== req.session.userId) continue;
      
      let config = {};
      try {
        config = JSON.parse(task.trigger_config || '{}');
      } catch (e) {}
      
      if (config.appPackage && config.appPackage.trim() && config.appPackage.trim() !== app_package) {
        continue;
      }
      
      const payload = {
        fingerprint: `notification:${Date.now()}:${Math.random().toString(36).substr(2, 5)}`,
        timestamp: new Date().toISOString(),
        context: {
          triggerEvent: {
            provider: 'android_notification',
            appPackage: app_package,
            title: title,
            body: body,
            actionTaken: action_taken
          }
        }
      };
      
      await taskRuntime.fireTaskFromTrigger(task.id, task.user_id, payload).catch(err => {
        console.error('[Triggers] Notification task trigger failed:', err.message);
      });
    }
  }).catch(err => console.error('[Triggers] Notification background processing failed:', err.message));
});

module.exports = router;
