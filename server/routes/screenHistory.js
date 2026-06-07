'use strict';

const express = require('express');
const db = require('../db/database');
const { buildFtsQuery } = require('../db/ftsQuery');
const { requireAuth } = require('../middleware/auth');
const { getErrorMessage } = require('../services/bootstrap_helpers');

const router = express.Router();

router.use(requireAuth);

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
        SELECT s.id, s.timestamp, s.app_name, s.text_content
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
        SELECT id, timestamp, app_name, text_content
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

module.exports = router;
