'use strict';

const express = require('express');
const { sanitizeError } = require('../utils/security');
const { wearableDeviceAuth } = require('../services/wearables/device_auth');
const db = require('../db/database');
const {
  buildIngestHttpResponse,
  requireMacAddress,
  requireWearableManager,
  readWearableAudioChunk,
  requireCharacteristicUuid,
  toWearableRouteError,
} = require('./_helpers/wearableAudioRoutes');

const router = express.Router();

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

    const manager = req.app.locals.wearableManager;
    if (manager && req.body?.macAddress && req.body?.protocol) {
      try {
        manager.registerDevice(claimed.userId, req.body.macAddress, req.body.protocol, req.body.deviceName);
      } catch (_) {
        // Device may already be present; ignore duplicate registration errors.
      }
    }

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

    const agentEngine = req.app.locals.agentEngine;
    const messagingManager = req.app.locals.messagingManager;
    if (!agentEngine || !messagingManager) {
      return res.status(503).json({ error: 'Agent services unavailable' });
    }

    const chatId = token.device_id || token.id;
    const runId = require('crypto').randomUUID();

    db.prepare(
      `INSERT INTO messages (user_id, agent_id, run_id, role, content, platform, platform_chat_id, metadata)
       VALUES (?, ?, ?, 'user', ?, 'waveshare_wearable', ?, ?)`
    ).run(
      token.user_id,
      token.agent_id || null,
      runId,
      text,
      chatId,
      JSON.stringify({
        sender: chatId,
        senderName: token.device_name || 'NeoOS Wearable',
        source: 'wearable_device_token',
      }),
    );

    const conversationId = messagingManager.getOrCreateConversation(
      token.user_id,
      'waveshare_wearable',
      chatId,
      { agentId: token.agent_id || null }
    );

    const prompt = [
      'You received a NeoOS wearable utterance.',
      '<sender_identity>',
      `platform: waveshare_wearable`,
      `chat_type: direct`,
      `chat_id: ${chatId}`,
      `sender_id: ${chatId}`,
      `sender_name: ${token.device_name || 'Wearable'}`,
      '</sender_identity>',
      '',
      'Message content:',
      '<external_message>',
      text,
      '</external_message>',
      '',
      'Respond with send_message platform="waveshare_wearable" to this same chat_id.',
      'If there are multiple useful response chunks, you may send multiple send_message calls.',
    ].join('\n');

    await agentEngine.run(token.user_id, prompt, {
      runId,
      agentId: token.agent_id || null,
      triggerSource: 'wearable',
      conversationId,
      source: 'waveshare_wearable',
      chatId,
      context: { rawUserMessage: text },
    });

    res.status(202).json({ success: true, runId });
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

router.post('/status', requireWearableToken, (req, res) => {
  try {
    const token = req.wearableToken;
    const manager = requireWearableManager(req.app.locals);

    const macAddress = requireMacAddress(req.body?.macAddress || token.mac_address);
    const status = req.body?.status || 'connected';
    const batteryLevel = req.body?.batteryLevel;

    const device = manager.updateStatus(token.user_id, macAddress, status, batteryLevel);
    if (!device) return res.status(404).json({ error: 'Device not found' });

    res.json({ success: true, device });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/stream', requireWearableToken, async (req, res) => {
  try {
    const manager = requireWearableManager(req.app.locals);

    const token = req.wearableToken;
    const rawBuffer = await readWearableAudioChunk(req);
    const characteristicUuid = requireCharacteristicUuid(req, 'Missing characteristicUuid');
    const macAddress = requireMacAddress(req.body?.macAddress || req.query.macAddress || token.mac_address);

    const ingestResult = manager.handleLiveStreamChunk(
      token.user_id,
      macAddress,
      rawBuffer,
      { characteristicUuid }
    );
    const response = buildIngestHttpResponse(ingestResult);
    return res.status(response.status).json(response.body);
  } catch (err) {
    const mapped = toWearableRouteError(err);
    res.status(mapped.status).json({ error: mapped.message });
  }
});

router.post('/sync', requireWearableToken, async (req, res) => {
  try {
    const manager = requireWearableManager(req.app.locals);

    const token = req.wearableToken;
    const rawBuffer = await readWearableAudioChunk(req);
    const macAddress = requireMacAddress(req.body?.macAddress || req.query.macAddress || token.mac_address);

    const session = await manager.syncOfflineAudio(token.user_id, macAddress, rawBuffer);
    res.status(200).json({ success: true, sessionId: session.id });
  } catch (err) {
    const mapped = toWearableRouteError(err);
    res.status(mapped.status).json({ error: mapped.message });
  }
});

module.exports = router;
