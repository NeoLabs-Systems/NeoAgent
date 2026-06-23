'use strict';

const express = require('express');
const db = require('../db/database');
const { buildFtsQuery } = require('../db/ftsQuery');
const { requireAuth } = require('../middleware/auth');
const { getErrorMessage } = require('../services/bootstrap_helpers');

const router = express.Router();

router.use(requireAuth);

function getTimelineService(req) {
  return req.app?.locals?.timelineService || null;
}

function normalizeEntries(rawEntries) {
  if (!Array.isArray(rawEntries)) {
    throw new Error('entries must be an array.');
  }
  return rawEntries.map((entry) => {
    if (!entry || typeof entry !== 'object') {
      throw new Error('Each entry must be an object.');
    }
    const text = String(entry.text || '').replace(/\s+/g, ' ').trim();
    if (!text) {
      throw new Error('Entry text is required.');
    }
    return {
      capturedAt: entry.capturedAt,
      frontmostApp: entry.frontmostApp,
      windowTitle: entry.windowTitle,
      text,
      ocrConfidence: entry.ocrConfidence,
    };
  });
}

router.get('/search', (req, res) => {
  const { q, limit = 50, offset = 0 } = req.query;
  const userId = req.session.userId;

  try {
    let results = [];
    const ftsQuery = q ? buildFtsQuery(q) : null;
    if (ftsQuery) {
      // Full text search. buildFtsQuery sanitizes user input so FTS5 operator
      // characters (hyphens, AND/OR/NOT) don't throw and 500 the request.
      results = db.prepare(`
        SELECT
          s.id,
          s.timestamp,
          s.captured_at,
          s.captured_at AS capturedAt,
          s.device_id,
          s.device_id AS deviceId,
          s.device_label,
          s.device_label AS deviceLabel,
          s.app_name,
          s.app_name AS appName,
          s.window_title,
          s.window_title AS windowTitle,
          s.text_content,
          s.ocr_engine,
          s.ocr_engine AS ocrEngine,
          s.ocr_confidence,
          s.ocr_confidence AS ocrConfidence
        FROM screen_history_fts fts
        JOIN screen_history s ON fts.rowid = s.id
        WHERE screen_history_fts MATCH ? AND s.user_id = ?
        ORDER BY s.timestamp DESC
        LIMIT ? OFFSET ?
      `).all(ftsQuery, userId, Number(limit), Number(offset));
    } else if (q) {
      // Query had no usable search tokens — return no matches rather than error.
      results = [];
    } else {
      // Recent history
      results = db.prepare(`
        SELECT
          id,
          timestamp,
          captured_at,
          captured_at AS capturedAt,
          device_id,
          device_id AS deviceId,
          device_label,
          device_label AS deviceLabel,
          app_name,
          app_name AS appName,
          window_title,
          window_title AS windowTitle,
          text_content,
          ocr_engine,
          ocr_engine AS ocrEngine,
          ocr_confidence,
          ocr_confidence AS ocrConfidence
        FROM screen_history
        WHERE user_id = ?
        ORDER BY timestamp DESC
        LIMIT ? OFFSET ?
      `).all(userId, Number(limit), Number(offset));
    }

    res.json({ results });
  } catch (err) {
    console.error('[ScreenHistory] Search error:', getErrorMessage(err));
    res.status(500).json({ error: 'Failed to search screen history' });
  }
});

router.post('/entries', express.json(), (req, res) => {
  try {
    const userId = req.session.userId;
    const deviceId = String(req.body?.deviceId || '').trim();
    const activationId = String(req.body?.activationId || '').trim();
    if (!deviceId) {
      return res.status(400).json({ error: 'deviceId is required.' });
    }
    if (!activationId) {
      return res.status(400).json({ error: 'activationId is required.' });
    }

    const device = db.prepare(
      `SELECT device_id, label, activation_id, revoked_at, passive_history_enabled
       FROM desktop_companion_devices
       WHERE user_id = ? AND device_id = ?
       LIMIT 1`
    ).get(userId, deviceId);
    if (!device) {
      return res.status(404).json({ error: 'Desktop companion device not found.' });
    }
    if (device.revoked_at) {
      return res.status(403).json({ error: 'Desktop companion device has been revoked.' });
    }
    if (String(device.activation_id || '') !== activationId) {
      return res.status(403).json({ error: 'activationId does not match the registered desktop companion device.' });
    }
    if (device.passive_history_enabled !== 1) {
      return res.status(403).json({ error: 'Passive screen history is disabled for this desktop companion device.' });
    }

    const entries = normalizeEntries(req.body?.entries);
    const timelineService = getTimelineService(req);
    if (!timelineService || typeof timelineService.storeScreenEntries !== 'function') {
      return res.status(503).json({ error: 'Timeline service is unavailable.' });
    }

    const result = timelineService.storeScreenEntries({
      userId,
      deviceId,
      deviceLabel: device.label || deviceId,
      entries,
    });
    req.app?.locals?.desktopCompanionRegistry?.updatePassiveHistoryState?.(
      userId,
      deviceId,
      {
        enabled: true,
        lastUploadedAt: new Date().toISOString(),
        lastError: null,
      },
    );
    res.status(201).json({
      ok: true,
      insertedCount: result.insertedCount,
    });
  } catch (err) {
    const message = getErrorMessage(err);
    const userId = req.session?.userId;
    const deviceId = String(req.body?.deviceId || '').trim();
    if (userId && deviceId) {
      try {
        req.app?.locals?.desktopCompanionRegistry?.updatePassiveHistoryState?.(
          userId,
          deviceId,
          {
            enabled: true,
            lastError: message,
          },
        );
      } catch {
        // Best-effort; do not mask the original ingest failure.
      }
    }
    res.status(400).json({ error: message });
  }
});

module.exports = router;
