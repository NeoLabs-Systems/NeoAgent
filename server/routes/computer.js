'use strict';

const express = require('express');
const path = require('path');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { uploadDesktopCommandOutput } = require('../services/desktop/command_output_upload');

const router = express.Router();
const noVncRoot = path.dirname(path.dirname(require.resolve('@novnc/novnc')));
const MAX_EDIT_BYTES = 1024 * 1024;

router.use(requireAuth);
router.use('/novnc', express.static(noVncRoot, {
  fallthrough: false,
  immutable: true,
  maxAge: '1d',
  index: false,
}));

function runtime(req) {
  const manager = req.app?.locals?.runtimeManager;
  if (!manager) {
    const error = new Error('Computer runtime is unavailable.');
    error.status = 503;
    throw error;
  }
  return manager;
}

function teach(req) {
  const service = req.app?.locals?.teachService;
  if (!service) {
    const error = new Error('Teach Mode is unavailable.');
    error.status = 503;
    throw error;
  }
  return service;
}

function requireUserControl(req, manager) {
  const ownerId = `session:${req.sessionID}`;
  const lease = manager.getControlLease(req.session.userId);
  if (!lease || lease.ownerType !== 'user' || lease.ownerId !== ownerId) {
    const error = new Error('Take control of the computer before sending input.');
    error.code = 'COMPUTER_USER_CONTROL_REQUIRED';
    error.status = 409;
    throw error;
  }
  manager.acquireControl(req.session.userId, 'user', ownerId);
}

function sendError(res, error) {
  res.status(error.status || 500).json({
    error: sanitizeError(error),
    code: error.code || null,
  });
}

function route(action) {
  return async (req, res) => {
    try {
      const result = await action(req, runtime(req));
      if (!res.headersSent) res.json(result);
    } catch (error) {
      if (!res.headersSent) sendError(res, error);
    }
  };
}

router.get('/status', route((req, manager) => manager.getComputerStatus(req.session.userId)));

router.get('/provider', route((req, manager) => ({
  provider: manager.getComputerProvider(req.session.userId),
  status: manager.getComputerStatus(req.session.userId),
})));

router.put('/provider', route((req, manager) => manager.setComputerProvider(
  req.session.userId,
  req.body?.provider,
)));

router.post('/start', route((req, manager) => manager.startComputer(req.session.userId, {
  signal: req.signal,
})));

router.post('/stop', route((req, manager) => manager.stopComputer(req.session.userId)));

router.post('/display-session', route(async (req, manager) => {
  await manager.startComputer(req.session.userId, { signal: req.signal });
  return manager.createDisplaySession(req.session.userId);
}));

router.get('/display/:token', (req, res) => {
  try {
    const manager = runtime(req);
    const session = manager.resolveDisplaySession(req.session.userId, req.params.token);
    if (!session) return res.status(403).type('text/plain').send('Display session expired.');
    const websocketPath = `/api/computer/display-ws?token=${encodeURIComponent(req.params.token)}`;
    res.setHeader('Cache-Control', 'private, no-store');
    res.type('html').send(`<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body,#screen{width:100%;height:100%;margin:0;overflow:hidden;background:#111}canvas{outline:none}</style></head>
<body><div id="screen"></div><script type="module">
import RFB from '/api/computer/novnc/core/rfb.js';
const scheme = location.protocol === 'https:' ? 'wss' : 'ws';
const rfb = new RFB(document.getElementById('screen'), scheme + '://' + location.host + ${JSON.stringify(websocketPath)});
rfb.scaleViewport = true;
rfb.resizeSession = true;
rfb.clipViewport = false;
rfb.viewOnly = ${session.viewOnly === true ? 'true' : 'false'};
const record = (event) => fetch('/api/computer/teach/events', {
  method: 'POST', credentials: 'same-origin', headers: {'content-type':'application/json'},
  body: JSON.stringify(event),
}).catch(() => {});
document.getElementById('screen').addEventListener('pointerup', (event) => {
  const rect = event.currentTarget.getBoundingClientRect();
  record({type:'pointer', x:Math.round(event.clientX-rect.left), y:Math.round(event.clientY-rect.top), button:event.button});
}, true);
document.addEventListener('keydown', (event) => {
  const printable = event.key && event.key.length === 1;
  record({type:printable?'text-input':'key', key:printable?null:event.key, modifiers:{alt:event.altKey,ctrl:event.ctrlKey,meta:event.metaKey,shift:event.shiftKey}});
}, true);
</script></body></html>`);
    return undefined;
  } catch (error) {
    return res.status(error.status || 500).type('text/plain').send(sanitizeError(error));
  }
});

router.post('/control/acquire', route((req, manager) => {
  const existing = manager.getControlLease(req.session.userId);
  if (existing?.ownerType === 'agent') {
    const paused = req.app?.locals?.agentEngine?.pauseRun?.(existing.ownerId, {
      userId: req.session.userId,
      reason: 'User took control of the cloud computer.',
    });
    if (!paused) {
      const error = new Error('The active agent cannot be paused at this moment.');
      error.code = 'COMPUTER_AGENT_NOT_PAUSABLE';
      error.status = 409;
      throw error;
    }
    manager.releaseControl(req.session.userId, existing.ownerId);
  }
  return manager.acquireControl(
    req.session.userId,
    'user',
    `session:${req.sessionID}`,
  );
}));

router.post('/control/release', route((req, manager) => ({
  released: manager.releaseControl(req.session.userId, `session:${req.sessionID}`),
})));

router.get('/teach/status', (req, res) => {
  try {
    const session = teach(req).getActiveSession(req.session.userId);
    res.json(session ? teach(req).serialize(session) : { status: 'idle' });
  } catch (error) {
    sendError(res, error);
  }
});

router.post('/teach/start', route(async (req, manager) => {
  if (manager.getComputerProvider(req.session.userId) !== 'cloud') {
    const error = new Error('Teach Mode currently requires the cloud computer.');
    error.code = 'TEACH_MODE_CLOUD_REQUIRED';
    error.status = 409;
    throw error;
  }
  await manager.startComputer(req.session.userId, { signal: req.signal });
  const lease = manager.getControlLease(req.session.userId);
  if (lease?.ownerType === 'user') manager.releaseControl(req.session.userId, lease.ownerId);
  return teach(req).start(req.session.userId, {
    goal: req.body?.goal,
    agentId: req.body?.agentId || req.body?.agent_id,
  });
}));

router.post('/teach/events', async (req, res) => {
  try {
    res.json(await teach(req).record(req.session.userId, req.body || {}));
  } catch (error) {
    sendError(res, error);
  }
});

router.post('/teach/:sessionId/stop', async (req, res) => {
  try {
    res.json(await teach(req).stop(req.session.userId, req.params.sessionId));
  } catch (error) {
    sendError(res, error);
  }
});

router.post('/teach/:sessionId/cancel', (req, res) => {
  try {
    const cancelled = teach(req).cancel(req.session.userId, req.params.sessionId);
    res.status(cancelled ? 200 : 404).json({ cancelled });
  } catch (error) {
    sendError(res, error);
  }
});

router.get('/files', route((req, manager) => manager.requestComputer(
  req.session.userId,
  'GET',
  `/workspace/files?path=${encodeURIComponent(String(req.query?.path || '.'))}`,
  undefined,
  { signal: req.signal },
)));

router.get('/files/content', route((req, manager) => manager.requestComputer(
  req.session.userId,
  'GET',
  `/workspace/files/content?path=${encodeURIComponent(String(req.query?.path || ''))}`,
  undefined,
  { signal: req.signal },
)));

router.put('/files/content', route((req, manager) => {
  requireUserControl(req, manager);
  const content = String(req.body?.content ?? '');
  if (Buffer.byteLength(content, 'utf8') > MAX_EDIT_BYTES) {
    const error = new Error('File is too large to edit.');
    error.status = 400;
    throw error;
  }
  return manager.requestComputer(req.session.userId, 'PUT', '/workspace/files/content', {
    path: String(req.body?.path || ''),
    content,
  }, { signal: req.signal });
}));

router.get('/files/download', async (req, res) => {
  try {
    const result = await runtime(req).requestComputer(
      req.session.userId,
      'GET',
      `/workspace/files/download?path=${encodeURIComponent(String(req.query?.path || ''))}`,
      undefined,
      { signal: req.signal, maxResponseBytes: 24 * 1024 * 1024 },
    );
    const content = Buffer.from(String(result.content || ''), 'base64');
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Content-Type', result.contentType || 'application/octet-stream');
    res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(result.filename || 'download')}`);
    res.send(content);
  } catch (error) {
    sendError(res, error);
  }
});

router.post('/desktop/screenshot', route(async (req, manager) => {
  const provider = manager.getDesktopProviderForUser(req.session.userId);
  return provider.screenshot({ signal: req.signal });
}));

router.post('/desktop/observe', route(async (req, manager) => {
  const provider = manager.getDesktopProviderForUser(req.session.userId);
  return provider.observe({ includeTree: req.body?.includeTree === true, signal: req.signal });
}));

router.post('/desktop/click', route(async (req, manager) => {
  requireUserControl(req, manager);
  const provider = manager.getDesktopProviderForUser(req.session.userId);
  return provider.clickPoint(req.body?.x, req.body?.y, {
    button: req.body?.button,
    signal: req.signal,
  });
}));

router.post('/desktop/type', route(async (req, manager) => {
  requireUserControl(req, manager);
  const provider = manager.getDesktopProviderForUser(req.session.userId);
  return provider.typeText(String(req.body?.text || ''), {
    pressEnter: req.body?.pressEnter === true,
    signal: req.signal,
  });
}));

router.post('/desktop/key', route(async (req, manager) => {
  requireUserControl(req, manager);
  const provider = manager.getDesktopProviderForUser(req.session.userId);
  return provider.pressKey(String(req.body?.key || ''), { signal: req.signal });
}));

router.post('/desktop/launch', route(async (req, manager) => {
  requireUserControl(req, manager);
  const provider = manager.getDesktopProviderForUser(req.session.userId);
  return provider.launchApp({
    app: String(req.body?.app || ''),
    signal: req.signal,
  });
}));

router.post('/shell/execute', route((req, manager) => {
  requireUserControl(req, manager);
  return manager.executeCommand(
    req.session.userId,
    String(req.body?.command || ''),
    {
      cwd: req.body?.cwd,
      timeout: req.body?.timeout,
      stdinInput: req.body?.stdinInput,
      pty: req.body?.pty === true,
      signal: req.signal,
    },
  );
}));

router.post('/local/command-output', async (req, res) => {
  try {
    if (!String(req.get('content-type') || '').toLowerCase().startsWith('application/octet-stream')) {
      const error = new Error('Content-Type must be application/octet-stream.');
      error.status = 400;
      throw error;
    }
    const requiredHeader = (name) => {
      const value = String(req.get(name) || '').trim();
      if (!value || value.length > 256) {
        const error = new Error(`${name} is required.`);
        error.status = 400;
        throw error;
      }
      return value;
    };
    const artifact = await uploadDesktopCommandOutput({
      userId: req.session.userId,
      deviceId: requiredHeader('x-neoagent-device-id'),
      commandId: requiredHeader('x-neoagent-command-id'),
      contentLength: req.get('content-length'),
      checksum: req.get('x-neoagent-output-sha256'),
      complete: req.get('x-neoagent-output-complete') !== 'false',
      stdoutBytes: Number(req.get('x-neoagent-stdout-bytes') || 0),
      stderrBytes: Number(req.get('x-neoagent-stderr-bytes') || 0),
      stream: req,
      registry: req.app?.locals?.desktopCompanionRegistry,
      artifactStore: req.app?.locals?.artifactStore,
    });
    res.status(201).json({ outputArtifact: artifact });
  } catch (error) {
    sendError(res, error);
  }
});

router.get('/browser/status', route(async (req, manager) => {
  const provider = await manager.getBrowserProviderForUser(req.session.userId, { signal: req.signal });
  return {
    launched: await Promise.resolve(provider.isLaunched()),
    pages: await Promise.resolve(provider.getPageCount()),
    headless: provider.headless,
    pageInfo: await provider.getPageInfo(),
  };
}));

router.post('/browser/navigate', route(async (req, manager) => {
  requireUserControl(req, manager);
  const provider = await manager.getBrowserProviderForUser(req.session.userId, { signal: req.signal });
  return provider.navigate(String(req.body?.url || ''), {
    waitFor: req.body?.waitFor,
    signal: req.signal,
  });
}));

router.post('/browser/click', route(async (req, manager) => {
  requireUserControl(req, manager);
  const provider = await manager.getBrowserProviderForUser(req.session.userId, { signal: req.signal });
  return provider.click(
    req.body?.selector,
    req.body?.text,
    req.body?.screenshot !== false,
    { signal: req.signal },
  );
}));

router.post('/browser/type', route(async (req, manager) => {
  requireUserControl(req, manager);
  const provider = await manager.getBrowserProviderForUser(req.session.userId, { signal: req.signal });
  return provider.typeText(String(req.body?.text || ''), {
    pressEnter: req.body?.pressEnter === true,
    screenshot: req.body?.screenshot !== false,
    signal: req.signal,
  });
}));

router.post('/browser/screenshot', route(async (req, manager) => {
  const provider = await manager.getBrowserProviderForUser(req.session.userId, { signal: req.signal });
  return provider.screenshot({
    fullPage: req.body?.fullPage === true,
    selector: req.body?.selector,
    signal: req.signal,
  });
}));

module.exports = router;
