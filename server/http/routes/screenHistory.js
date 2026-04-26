'use strict';

const express = require('express');
const db = require('../../db/database');
const { getErrorMessage } = require('../bootstrap_helpers');

const router = express.Router();

router.get('/search', (req, res) => {
  const { q, limit = 50, offset = 0 } = req.query;

  if (!req.user || !req.user.id) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    let results = [];
    if (q) {
      // Full text search
      results = db.prepare(\`
        SELECT s.id, s.timestamp, s.app_name, s.text_content
        FROM screen_history_fts fts
        JOIN screen_history s ON fts.rowid = s.id
        WHERE screen_history_fts MATCH ? AND s.user_id = ?
        ORDER BY s.timestamp DESC
        LIMIT ? OFFSET ?
      \`).all(q, req.user.id, Number(limit), Number(offset));
    } else {
      // Recent history
      results = db.prepare(\`
        SELECT id, timestamp, app_name, text_content
        FROM screen_history
        WHERE user_id = ?
        ORDER BY timestamp DESC
        LIMIT ? OFFSET ?
      \`).all(req.user.id, Number(limit), Number(offset));
    }

    res.json({ results });
  } catch (err) {
    console.error('[ScreenHistory] Search error:', getErrorMessage(err));
    res.status(500).json({ error: 'Failed to search screen history' });
  }
});

module.exports = router;
