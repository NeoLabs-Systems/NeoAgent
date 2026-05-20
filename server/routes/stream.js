'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { AndroidStream } = require('../services/streaming/android-stream');
const { BrowserStream } = require('../services/streaming/browser-stream');

const router = express.Router();
router.use(requireAuth);

function boundedInt(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(parsed)));
}

function streamHub(req) {
  const hub = req.app?.locals?.streamHub;
  if (!hub) throw new Error('Stream hub is unavailable.');
  return hub;
}

async function desktopProvider(req) {
  const factory = req.app?.locals?.getDesktopProviderForUser;
  if (typeof factory !== 'function') {
    throw new Error('Desktop provider is unavailable.');
  }
  return factory(req.session?.userId);
}

async function androidController(req) {
  const runtimeManager = req.app?.locals?.runtimeManager;
  if (runtimeManager && typeof runtimeManager.getAndroidProviderForUser === 'function') {
    return runtimeManager.getAndroidProviderForUser(req.session?.userId);
  }
  throw new Error('Android controller is unavailable.');
}

async function browserController(req) {
  const runtimeManager = req.app?.locals?.runtimeManager;
  if (runtimeManager && typeof runtimeManager.getBrowserProviderForUser === 'function') {
    return runtimeManager.getBrowserProviderForUser(req.session?.userId);
  }
  throw new Error('Browser controller is unavailable.');
}

function normalizePlatform(value) {
  const platform = String(value || '').trim().toLowerCase();
  if (platform === 'desktop' || platform === 'android' || platform === 'browser') return platform;
  const error = new Error('platform must be desktop, android, or browser.');
  error.status = 400;
  throw error;
}

function normalizeDeviceId(platform, value) {
  const deviceId = String(value || '').trim();
  if (deviceId) return deviceId;
  if (platform === 'browser') return 'browser';
  const error = new Error('deviceId is required.');
  error.status = 400;
  throw error;
}

async function resolveStartDeviceId(platform, req) {
  const rawDeviceId = String(req.body?.deviceId || '').trim();
  if (platform === 'browser') return { deviceId: 'browser', controller: null };
  if (platform === 'android') {
    const controller = await androidController(req);
    const status = typeof controller.getStatus === 'function'
      ? await controller.getStatus().catch(() => ({}))
      : {};
    const adbSerial = String(status?.adbSerial || controller.adbSerial || '').trim();
    if (rawDeviceId && adbSerial && rawDeviceId !== adbSerial) {
      const error = new Error('Android deviceId does not match the active emulator serial.');
      error.status = 400;
      throw error;
    }
    if (rawDeviceId) return { deviceId: rawDeviceId, controller };
    if (!adbSerial) throw new Error('Android deviceId is required when no emulator serial is available.');
    return { deviceId: adbSerial, controller };
  }
  if (rawDeviceId) return { deviceId: rawDeviceId, controller: null };
  return { deviceId: normalizeDeviceId(platform, rawDeviceId), controller: null };
}

async function resolveStopDeviceId(platform, req) {
  const rawDeviceId = String(req.body?.deviceId || '').trim();
  if (rawDeviceId) return rawDeviceId;
  if (platform === 'browser') return 'browser';
  if (platform === 'android') {
    const controller = await androidController(req);
    const status = typeof controller.getStatus === 'function'
      ? await controller.getStatus().catch(() => ({}))
      : {};
    const adbSerial = String(status?.adbSerial || controller.adbSerial || '').trim();
    if (adbSerial) return adbSerial;
  }
  const error = new Error('deviceId is required.');
  error.status = 400;
  throw error;
}

function sendError(res, err) {
  res.status(Number(err?.status || 500)).json({ error: sanitizeError(err) });
}

router.post('/start', async (req, res) => {
  try {
    const userId = req.session?.userId;
    const platform = normalizePlatform(req.body?.platform);
    const resolved = await resolveStartDeviceId(platform, req);
    const deviceId = resolved.deviceId;
    const fps = boundedInt(req.body?.fps, platform === 'android' ? 10 : 15, 1, platform === 'android' ? 15 : 20);
    const quality = boundedInt(req.body?.quality, platform === 'android' ? 75 : 80, 30, 95);
    const hub = streamHub(req);
    await hub.stopStream(userId, platform, deviceId, 'restart');

    if (platform === 'desktop') {
      const provider = await desktopProvider(req);
      const result = await provider.startStream({
        deviceId,
        fps,
        quality,
        displayId: req.body?.displayId || null,
      });
      const resolvedDeviceId = result?.deviceId || result?.device?.deviceId || deviceId;
      hub.markStarted(userId, resolvedDeviceId, platform, { fps, quality }, () =>
        provider.stopStream({ deviceId: resolvedDeviceId }));
      return res.json({ ok: true, platform, deviceId: resolvedDeviceId, fps, quality });
    }

    if (platform === 'android') {
      const controller = resolved.controller || await androidController(req);
      const stream = new AndroidStream({ userId, deviceId, controller, streamHub: hub, fps, quality });
      stream.start();
      hub.markStarted(userId, deviceId, platform, { fps, quality }, () => stream.stop());
      return res.json({ ok: true, platform, deviceId, fps, quality });
    }

    const controller = await browserController(req);
    const stream = new BrowserStream({ userId, deviceId, controller, streamHub: hub, fps, quality });
    stream.start();
    hub.markStarted(userId, deviceId, platform, { fps, quality }, () => stream.stop());
    return res.json({ ok: true, platform, deviceId, fps, quality });
  } catch (err) {
    sendError(res, err);
  }
});

router.post('/stop', async (req, res) => {
  try {
    const platform = normalizePlatform(req.body?.platform);
    const deviceId = await resolveStopDeviceId(platform, req);
    const stopped = await streamHub(req).stopStream(req.session?.userId, platform, deviceId, 'api_stop');
    res.json({ ok: true, stopped, platform, deviceId });
  } catch (err) {
    sendError(res, err);
  }
});

router.get('/status', async (req, res) => {
  try {
    const platform = req.query?.platform ? normalizePlatform(req.query.platform) : null;
    const deviceId = req.query?.deviceId
      ? normalizeDeviceId(platform || 'desktop', req.query.deviceId)
      : null;
    const hub = streamHub(req);
    if (deviceId) {
      return res.json(hub.status(req.session?.userId, platform || 'desktop', deviceId));
    }
    return res.json({ streams: hub.listStatus(req.session?.userId), platform });
  } catch (err) {
    sendError(res, err);
  }
});

module.exports = router;
