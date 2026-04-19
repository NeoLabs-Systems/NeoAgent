const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

const MAX_TEXT_LENGTH = 8000;
const MAX_KEY_LENGTH = 128;
const MAX_APP_LENGTH = 256;

function badRequest(message) {
  const error = new Error(message);
  error.status = 400;
  return error;
}

function parseDeviceId(value) {
  if (value == null) return null;
  const normalized = String(value).trim();
  if (!normalized) return null;
  if (normalized.length > 256) {
    throw badRequest('deviceId is too long.');
  }
  return normalized;
}

function parseFiniteNumber(value, field, options = {}) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw badRequest(`${field} must be a finite number.`);
  }
  if (options.min != null && parsed < options.min) {
    throw badRequest(`${field} must be >= ${options.min}.`);
  }
  if (options.max != null && parsed > options.max) {
    throw badRequest(`${field} must be <= ${options.max}.`);
  }
  return parsed;
}

function parseRequiredString(value, field, maxLength) {
  const normalized = String(value || '').trim();
  if (!normalized) {
    throw badRequest(`${field} is required.`);
  }
  if (normalized.length > maxLength) {
    throw badRequest(`${field} is too long.`);
  }
  return normalized;
}

function parseOptionalBoolean(value, fallback = false) {
  if (value == null) return fallback;
  return value === true;
}

function parseOptionalQueryBoolean(value) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') return true;
    if (normalized === 'false' || normalized === '0') return false;
  }
  return undefined;
}

function parseOptionalQueryNumber(value) {
  if (value == null || value === '') return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function parseTypedDisplayQuery(query = {}) {
  const typed = {
    deviceId: parseDeviceId(query?.deviceId),
  };
  const page = parseOptionalQueryNumber(query?.page);
  const limit = parseOptionalQueryNumber(query?.limit);
  const active = parseOptionalQueryBoolean(query?.active);
  if (page != null) typed.page = page;
  if (limit != null) typed.limit = limit;
  if (active != null) typed.active = active;
  return typed;
}

function safeErrorDetails(err) {
  if (err?.code !== 'DESKTOP_COMPANION_SELECTION_REQUIRED') {
    return null;
  }
  const devices = Array.isArray(err?.details?.devices) ? err.details.devices : [];
  return {
    devices: devices
      .filter((item) => item && typeof item === 'object')
      .map((item) => ({
        deviceId: String(item.deviceId || ''),
        label: String(item.label || ''),
        hostname: String(item.hostname || ''),
        platform: String(item.platform || ''),
      })),
  };
}

function getDesktopProvider(req) {
  const resolver = req.app?.locals?.getDesktopProviderForUser;
  if (typeof resolver === 'function') {
    return resolver(req.session?.userId);
  }
  return req.app?.locals?.desktopProvider || null;
}

async function handleDesktopAction(req, res, action) {
  try {
    const provider = await getDesktopProvider(req);
    if (!provider) {
      throw new Error('Desktop provider is not available.');
    }
    const result = await action(provider, req);
    res.json(result);
  } catch (err) {
    const status = err.status || (err.code === 'DESKTOP_COMPANION_SELECTION_REQUIRED' ? 409 : 500);
    res.status(status).json({
      error: sanitizeError(err),
      code: err.code || null,
      details: safeErrorDetails(err),
    });
  }
}

router.get('/status', (req, res) =>
  handleDesktopAction(req, res, (provider) => provider.getStatus()));

router.get('/devices', (req, res) =>
  handleDesktopAction(req, res, (provider) => ({
    selectedDeviceId: provider.registry?.getSelectedDeviceId(req.session.userId) || null,
    devices: provider.listDevices(),
  })));

router.post('/select-device', (req, res) =>
  handleDesktopAction(req, res, (provider, request) =>
    provider.selectDevice(parseRequiredString(request.body?.deviceId, 'deviceId', 256))));

router.post('/screenshot', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.screenshot({
    ...(request.body || {}),
    deviceId: parseDeviceId(request.body?.deviceId),
  })));

router.post('/observe', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.observe({
    ...(request.body || {}),
    deviceId: parseDeviceId(request.body?.deviceId),
    includeTree: parseOptionalBoolean(request.body?.includeTree, false),
  })));

router.post('/click', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.clickPoint(
    parseFiniteNumber(request.body?.x, 'x', { min: -100000, max: 100000 }),
    parseFiniteNumber(request.body?.y, 'y', { min: -100000, max: 100000 }),
    {
      ...(request.body || {}),
      deviceId: parseDeviceId(request.body?.deviceId),
    },
  )));

router.post('/drag', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.drag({
    ...(request.body || {}),
    deviceId: parseDeviceId(request.body?.deviceId),
    x1: parseFiniteNumber(request.body?.x1, 'x1', { min: -100000, max: 100000 }),
    y1: parseFiniteNumber(request.body?.y1, 'y1', { min: -100000, max: 100000 }),
    x2: parseFiniteNumber(request.body?.x2, 'x2', { min: -100000, max: 100000 }),
    y2: parseFiniteNumber(request.body?.y2, 'y2', { min: -100000, max: 100000 }),
    durationMs: Math.round(parseFiniteNumber(request.body?.durationMs ?? 280, 'durationMs', { min: 20, max: 5000 })),
  })));

router.post('/scroll', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.scroll({
    ...(request.body || {}),
    deviceId: parseDeviceId(request.body?.deviceId),
    deltaX: Math.round(parseFiniteNumber(request.body?.deltaX ?? 0, 'deltaX', { min: -5000, max: 5000 })),
    deltaY: Math.round(parseFiniteNumber(request.body?.deltaY ?? 0, 'deltaY', { min: -5000, max: 5000 })),
  })));

router.post('/type-text', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.typeText(
    parseRequiredString(request.body?.text, 'text', MAX_TEXT_LENGTH),
    {
      ...(request.body || {}),
      deviceId: parseDeviceId(request.body?.deviceId),
      pressEnter: parseOptionalBoolean(request.body?.pressEnter, false),
    },
  )));

router.post('/press-key', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.pressKey(
    parseRequiredString(request.body?.key, 'key', MAX_KEY_LENGTH),
    {
      ...(request.body || {}),
      deviceId: parseDeviceId(request.body?.deviceId),
    },
  )));

router.post('/launch-app', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.launchApp({
    ...(request.body || {}),
    deviceId: parseDeviceId(request.body?.deviceId),
    app: parseRequiredString(request.body?.app, 'app', MAX_APP_LENGTH),
  })));

router.get('/displays', (req, res) =>
  handleDesktopAction(req, res, (provider, request) =>
    provider.listDisplays(parseTypedDisplayQuery(request.query))));

router.post('/select-display', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.selectDisplay(
    parseRequiredString(request.body?.displayId, 'displayId', 256),
    {
      ...(request.body || {}),
      deviceId: parseDeviceId(request.body?.deviceId),
    },
  )));

router.post('/revoke-device', (req, res) =>
  handleDesktopAction(req, res, (provider, request) =>
    provider.revokeDevice(parseRequiredString(request.body?.deviceId, 'deviceId', 256))));

router.post('/pause-device', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.pauseDevice(
    parseRequiredString(request.body?.deviceId, 'deviceId', 256),
    parseOptionalBoolean(request.body?.paused, true),
  )));

router.post('/tree', (req, res) =>
  handleDesktopAction(req, res, (provider, request) => provider.getAccessibilityTree({
    ...(request.body || {}),
    deviceId: parseDeviceId(request.body?.deviceId),
  })));

module.exports = router;
