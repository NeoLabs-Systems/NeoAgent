'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const cowork = require('../services/cowork/service');

const router = express.Router();

router.use(requireAuth);

function runtimeManager(req) {
  return req.app?.locals?.runtimeManager || null;
}

router.get('/capabilities', (req, res) => {
  const manager = runtimeManager(req);
  res.json({
    device: cowork.resolveEffectiveDeviceTarget(req.session.userId, null, manager),
  });
});

router.get('/chats', (req, res) => {
  res.json({
    chats: cowork.listConversations(req.session.userId, {
      runtimeManager: runtimeManager(req),
    }),
  });
});

router.post('/chats', (req, res) => {
  const chat = cowork.createConversation(req.session.userId, req.body || {}, {
    runtimeManager: runtimeManager(req),
  });
  res.status(201).json({ chat });
});

router.get('/chats/:id', (req, res) => {
  const chat = cowork.listConversations(req.session.userId, {
    runtimeManager: runtimeManager(req),
  }).find((entry) => entry.id === req.params.id);
  if (!chat) {
    const error = new Error('Cowork chat not found.');
    error.status = 404;
    throw error;
  }
  res.json({
    chat,
    messages: cowork.listMessages(req.session.userId, req.params.id, {
      limit: req.query.limit,
    }),
    activity: cowork.listActivity(req.session.userId, req.params.id),
    inputRequests: cowork.listInputRequests(req.session.userId, req.params.id),
  });
});

router.patch('/chats/:id', (req, res) => {
  res.json({
    chat: cowork.updateConversation(req.session.userId, req.params.id, req.body || {}, {
      runtimeManager: runtimeManager(req),
    }),
  });
});

router.delete('/chats/:id', (req, res) => {
  res.json(cowork.deleteConversation(
    req.session.userId,
    req.params.id,
    req.app?.locals?.agentEngine,
  ));
});

router.post('/chats/:id/input-requests/:requestId/answer', (req, res) => {
  const runContext = cowork.getRunContext(
    req.session.userId,
    req.params.id,
    runtimeManager(req),
  );
  const answer = cowork.answerInputRequest(
    req.session.userId,
    req.params.id,
    req.params.requestId,
    req.body?.answers,
  );
  res.json({ answer, runContext });
});

module.exports = router;
