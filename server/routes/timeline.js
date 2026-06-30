'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth);

router.get('/', (req, res) => {
  const timelineService = req.app?.locals?.timelineService;
  if (!timelineService || typeof timelineService.listEvents !== 'function') {
    return res.status(503).json({ error: 'Timeline service is unavailable.' });
  }

  const rawSources = []
    .concat(req.query.source || [])
    .concat(req.query.sources || []);
  const sources = rawSources
    .flatMap((value) => String(value || '').split(','))
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);
  const items = timelineService.listEvents(req.session.userId, {
    limit: req.query.limit,
    beforeOccurredAt: req.query.beforeOccurredAt,
    beforeId: req.query.beforeId,
    agentId: req.query.agentId,
    sources,
  });
  const lastItem = items[items.length - 1] || null;

  res.json({
    items,
    nextCursor: lastItem
      ? {
        beforeOccurredAt: lastItem.occurredAt,
        beforeId: lastItem.id,
      }
      : null,
  });
});

module.exports = router;
