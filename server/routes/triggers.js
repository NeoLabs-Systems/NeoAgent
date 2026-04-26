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
    const userRow = db.prepare('SELECT id FROM users WHERE id = ?').get(req.user.id);
    if (!userRow) return res.status(401).json({ error: 'Unauthorized' });

    console.log(`[Triggers] Geofence entered: ${label} by user ${req.user.id}`);

    // If an agentEngine is running, we can inject a prompt to process this context
    const agentEngine = req.app.locals.agentEngine;
    if (agentEngine) {
      // Find active agent or use default
      const defaultAgentId = db.prepare('SELECT id FROM agents WHERE user_id = ? ORDER BY is_default DESC LIMIT 1').get(req.user.id)?.id;
      
      if (defaultAgentId) {
        // Fire and forget a trigger message to the agent
        agentEngine.handleBackgroundTrigger(req.user.id, defaultAgentId, {
          source: 'geofence',
          label,
          action: action || 'User entered a geofenced area. Check if there are any active reminders or tasks related to this location.'
        }).catch(err => console.error('[Triggers] Agent evaluation failed:', err));
      }
    }

    res.json({ success: true, message: 'Geofence trigger processed' });
  } catch (err) {
    console.error('[Triggers] Geofence error:', getErrorMessage(err));
    res.status(500).json({ error: 'Failed to process geofence trigger' });
  }
});

router.post('/notification', async (req, res) => {
  const { app_package, title, body, action_taken } = req.body;

  try {
    const userRow = db.prepare('SELECT id FROM users WHERE id = ?').get(req.user.id);
    if (!userRow) return res.status(401).json({ error: 'Unauthorized' });

    console.log(`[Triggers] Notification received: ${app_package} - ${title}`);

    db.prepare(`
      INSERT INTO notification_history (user_id, app_package, title, body, action_taken)
      VALUES (?, ?, ?, ?, ?)
    `).run(req.user.id, app_package || 'unknown', title || '', body || '', action_taken || 'none');

    // Notify agent engine to proactively evaluate the notification
    const agentEngine = req.app.locals.agentEngine;
    if (agentEngine) {
      const defaultAgentId = db.prepare('SELECT id FROM agents WHERE user_id = ? ORDER BY is_default DESC LIMIT 1').get(req.user.id)?.id;
      
      if (defaultAgentId) {
        agentEngine.handleBackgroundTrigger(req.user.id, defaultAgentId, {
          source: 'notification',
          app_package,
          title,
          body,
          instruction: 'Evaluate this notification. If it is an important reminder, calendar event, or urgent message, inform the user or take appropriate action.'
        }).catch(err => console.error('[Triggers] Agent evaluation failed:', err));
      }
    }

    res.json({ success: true, message: 'Notification trigger processed and stored' });
  } catch (err) {
    console.error('[Triggers] Notification error:', getErrorMessage(err));
    res.status(500).json({ error: 'Failed to process notification trigger' });
  }
});

module.exports = router;
