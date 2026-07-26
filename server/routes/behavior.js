'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const {
  MODULE_IDS,
  cloneDefaults,
  getBehaviorConfig,
  setBehaviorConfig,
  resolveBehaviorConfig,
} = require('../services/behavior');
const {
  getAgentIdFromRequest,
  resolveAgentId,
} = require('../services/agents/manager');
const { invalidateSystemPromptCache } = require('../services/ai/systemPrompt');

const router = express.Router();
router.use(requireAuth);

function requestAgentId(req) {
  return resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
}

router.get('/', (req, res) => {
  const userId = req.session.userId;
  const agentId = requestAgentId(req);
  res.json({
    agentId,
    modules: MODULE_IDS,
    defaults: cloneDefaults(),
    config: getBehaviorConfig(userId, agentId),
  });
});

router.put('/', (req, res) => {
  if (!req.body?.config || typeof req.body.config !== 'object' || Array.isArray(req.body.config)) {
    return res.status(400).json({ error: 'config must be an object' });
  }
  const userId = req.session.userId;
  const agentId = requestAgentId(req);
  const config = setBehaviorConfig(userId, agentId, req.body.config);
  invalidateSystemPromptCache(userId, agentId);
  return res.json({ agentId, config });
});

router.get('/effective', (req, res) => {
  const userId = req.session.userId;
  const agentId = requestAgentId(req);
  const platform = String(req.query.platform || '').trim();
  const chatId = String(req.query.chatId || '').trim();
  if (!platform || !chatId) {
    return res.status(400).json({ error: 'platform and chatId are required' });
  }
  return res.json({
    agentId,
    config: resolveBehaviorConfig(userId, agentId, {
      platform,
      chatId,
      isGroup: req.query.isGroup !== 'false',
    }),
  });
});

router.get('/diagnostics', (req, res) => {
  const userId = req.session.userId;
  const agentId = requestAgentId(req);
  const platform = String(req.query.platform || '').trim();
  const chatId = String(req.query.chatId || '').trim();
  if (!platform || !chatId) {
    return res.status(400).json({ error: 'platform and chatId are required' });
  }
  const pipeline = req.app?.locals?.behaviorPipeline;
  if (!pipeline?.getDiagnostics) {
    return res.status(503).json({ error: 'Behavior runtime is not initialized' });
  }
  return res.json(pipeline.getDiagnostics(userId, agentId, platform, chatId));
});

module.exports = router;
