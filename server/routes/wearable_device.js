'use strict';

const express = require('express');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');
const { wearableDeviceAuth } = require('../services/wearables/device_auth');
const { createVoiceMessage } = require('../services/voice/message');

const router = express.Router();

router.post('/pairing/code', (req, res) => {
  try {
    const sessionUserId = req.session?.userId;
    if (!sessionUserId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const agentId = resolveAgentId(sessionUserId, getAgentIdFromRequest(req));
    const pairing = wearableDeviceAuth.createPairingCode(req.session.userId, {
      agentId,
      ttlMinutes: req.body?.ttlMinutes,
      source: 'messaging_tab',
      deviceHint: req.body?.deviceHint,
    });
    res.status(201).json(pairing);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

function extractBearerToken(req) {
  const auth = String(req.get('authorization') || '');
  if (!auth.toLowerCase().startsWith('bearer ')) return null;
  return auth.slice(7).trim();
}

function requireWearableToken(req, res, next) {
  const token = extractBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  const tokenRow = wearableDeviceAuth.validateBearerToken(token);
  if (!tokenRow) return res.status(401).json({ error: 'Invalid wearable token' });
  wearableDeviceAuth.touchToken(tokenRow.id);
  req.wearableToken = tokenRow;
  next();
}

router.post('/pair/claim', (req, res) => {
  try {
    const code = String(req.body?.code || '').trim();
    if (!code) return res.status(400).json({ error: 'code is required' });

    const claimed = wearableDeviceAuth.claimPairingCode(code, {
      deviceId: req.body?.deviceId,
      deviceName: req.body?.deviceName,
      macAddress: req.body?.macAddress,
      protocol: req.body?.protocol,
      firmwareVersion: req.body?.firmwareVersion,
    });

    res.status(201).json({
      token: claimed.token,
      tokenId: claimed.tokenId,
      agentId: claimed.agentId,
      deviceId: claimed.deviceId,
      deviceName: claimed.deviceName,
      protocol: claimed.protocol,
    });
  } catch (err) {
    res.status(err.status || 500).json({ error: sanitizeError(err) });
  }
});

router.post('/utterance', requireWearableToken, async (req, res) => {
  try {
    const token = req.wearableToken;
    const text = String(req.body?.text || '').trim();
    if (!text) return res.status(400).json({ error: 'text is required' });

    const messagingManager = req.app.locals.messagingManager;
    if (!messagingManager) {
      return res.status(503).json({ error: 'Agent services unavailable' });
    }

    const chatId = token.device_id || token.id;
    const message = createVoiceMessage({
      platform: 'waveshare_wearable',
      agentId: token.agent_id || null,
      chatId,
      sender: chatId,
      senderName: token.device_name || 'NeoOS Wearable',
      content: text,
      mediaType: 'audio',
      metadata: {
        source: 'wearable_device_token',
      },
    });

    await messagingManager.ingestMessage(
      token.user_id,
      'waveshare_wearable',
      message,
      { agentId: token.agent_id || null },
    );

    res.status(202).json({ success: true, accepted: true });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/me', requireWearableToken, (req, res) => {
  const token = req.wearableToken;
  res.json({
    deviceId: token.device_id,
    name: token.device_name,
    macAddress: token.mac_address,
    protocol: token.protocol,
    firmwareVersion: token.firmware_version,
    lastSeenAt: token.last_seen_at,
  });
});

router.get('/responses/next', requireWearableToken, (req, res) => {
  try {
    const token = req.wearableToken;
    const limit = Number(req.query.limit || 5);
    const responses = wearableDeviceAuth.getPendingResponses(token, limit);
    res.json({ responses });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/responses/ack', requireWearableToken, (req, res) => {
  try {
    const token = req.wearableToken;
    const lastMessageId = Number(req.body?.lastMessageId || 0);
    if (!Number.isFinite(lastMessageId) || lastMessageId <= 0) {
      return res.status(400).json({ error: 'lastMessageId must be a positive number' });
    }
    wearableDeviceAuth.setLastCursor(token.id, lastMessageId);
    res.json({ success: true, lastMessageId });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
