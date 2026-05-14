'use strict';

const express = require('express');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { CLIExecutor } = require('./services/cli/executor');
const { RUNTIME_HOME, DATA_DIR } = require('../runtime/paths');

const PORT = Number(process.env.NEOAGENT_GUEST_AGENT_PORT || 8421);
function resolveGuestToken() {
  const raw = String(process.env.NEOAGENT_VM_GUEST_TOKEN || '').trim();
  if (raw) return raw;
  const b64 = String(process.env.NEOAGENT_VM_GUEST_TOKEN_B64 || '').trim();
  if (!b64) return '';
  try {
    return Buffer.from(b64, 'base64').toString('utf8').trim();
  } catch {
    return '';
  }
}

const AUTH_TOKEN = resolveGuestToken();
const GUEST_PROFILE = String(process.env.NEOAGENT_GUEST_PROFILE || 'browser_cli').trim() === 'android'
  ? 'android'
  : 'browser_cli';
const FILE_ROOT = path.join(RUNTIME_HOME, 'guest-agent-files');
const MAX_APK_STREAM_BYTES = Number(process.env.NEOAGENT_GUEST_MAX_APK_STREAM_BYTES || 512 * 1024 * 1024);

fs.mkdirSync(FILE_ROOT, { recursive: true });

const app = express();
app.use(express.json({ limit: '100mb' }));

const cliExecutor = new CLIExecutor();
const browserController = GUEST_PROFILE === 'browser_cli'
  ? new (require('./services/browser/controller').BrowserController)({ runtimeBackend: 'vm' })
  : null;
const androidController = GUEST_PROFILE === 'android'
  ? new (require('./services/android/controller').AndroidController)({ runtimeBackend: 'vm' })
  : null;

const ALLOWED_READABLE_ROOTS = [
  FILE_ROOT,
  path.join(RUNTIME_HOME, 'data'),
  path.join(RUNTIME_HOME, 'android'),
  os.tmpdir(),
].map((value) => path.resolve(value));

const ALLOWED_READABLE_ROOTS_REAL = ALLOWED_READABLE_ROOTS
  .map((value) => {
    try {
      return fs.realpathSync.native(value);
    } catch {
      return null;
    }
  })
  .filter(Boolean);

function isInsideAllowedRoots(targetPath) {
  return ALLOWED_READABLE_ROOTS_REAL.some((root) => targetPath === root || targetPath.startsWith(`${root}${path.sep}`));
}

function requireToken(req, res, next) {
  next();
}

function sanitizeError(err) {
  return err instanceof Error ? err.message : String(err);
}

function resolveReadablePath(filePath) {
  try {
    const rawPath = String(filePath || '').trim();
    if (/^\/screenshots\//.test(rawPath)) {
      const fileName = path.basename(rawPath);
      const screenshotPath = path.join(DATA_DIR, 'screenshots', fileName);
      const realScreenshotPath = fs.realpathSync.native(screenshotPath);
      return isInsideAllowedRoots(realScreenshotPath) ? realScreenshotPath : null;
    }
    const resolved = path.resolve(String(filePath || ''));
    const realTarget = fs.realpathSync.native(resolved);
    return isInsideAllowedRoots(realTarget) ? realTarget : null;
  } catch {
    return null;
  }
}

async function handle(res, work) {
  try {
    res.json(await work());
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
}

app.use(requireToken);

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    runtime: 'guest-agent',
    profile: GUEST_PROFILE,
    platform: process.platform,
    arch: process.arch,
  });
});

app.post('/exec', async (req, res) => {
  await handle(res, async () => {
    const command = String(req.body?.command || '').trim();
    if (!command) {
      return { error: 'command is required' };
    }
    if (req.body?.pty) {
      return cliExecutor.executeInteractive(command, req.body?.inputs || [], {
        cwd: req.body?.cwd,
        timeout: req.body?.timeout,
      });
    }
    return cliExecutor.execute(command, {
      cwd: req.body?.cwd,
      timeout: req.body?.timeout,
      stdinInput: req.body?.stdin_input,
    });
  });
});

app.post('/exec/kill', async (req, res) => {
  await handle(res, async () => {
    const pid = Number(req.body?.pid);
    if (!Number.isInteger(pid) || pid <= 0) {
      return { error: 'pid is required' };
    }
    const reason = String(req.body?.reason || 'aborted').trim();
    if (typeof cliExecutor.isManaged === 'function' && !cliExecutor.isManaged(pid)) {
      return { error: 'pid not managed' };
    }
    const killed = cliExecutor.kill(pid, reason || 'aborted');
    return { success: killed, pid };
  });
});

app.post('/files/read', async (req, res) => {
  await handle(res, async () => {
    const filePath = String(req.body?.path || '').trim();
    const encoding = String(req.body?.encoding || 'base64').trim().toLowerCase();
    if (!filePath) {
      return { error: 'path is required' };
    }
    const realTarget = resolveReadablePath(filePath);
    if (!realTarget) {
      console.warn('[GuestAgent] files/read rejected path', { requestedPath: filePath });
      return { error: 'path is outside guest-agent readable roots' };
    }
    const data = fs.readFileSync(realTarget);
    return {
      path: realTarget,
      encoding,
      content: encoding === 'utf8' ? data.toString('utf8') : data.toString('base64'),
      byteSize: data.length,
    };
  });
});

app.get('/browser/status', async (_req, res) => {
  await handle(res, async () => {
    const controller = requireCapability(browserController, 'browser');
    return {
      launched: await Promise.resolve(controller.isLaunched()),
      pages: await Promise.resolve(controller.getPageCount()),
      headless: controller.headless,
      pageInfo: await controller.getPageInfo(),
    };
  });
});
function requireCapability(controller, name) {
  if (!controller) {
    throw new Error(`${name} runtime is unavailable in this guest profile.`);
  }
  return controller;
}

app.post('/browser/launch', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').launch(req.body || {})));
app.post('/browser/navigate', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').navigate(req.body?.url, req.body || {})));
app.post('/browser/screenshot', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').screenshot(req.body || {})));
app.post('/browser/click', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').click(req.body?.selector, req.body?.text, req.body?.screenshot !== false)));
app.post('/browser/click-point', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').clickPoint(req.body?.x, req.body?.y, req.body?.screenshot !== false)));
app.post('/browser/fill', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').type(req.body?.selector, String(req.body?.value ?? req.body?.text ?? ''), req.body || {})));
app.post('/browser/type-text', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').typeText(String(req.body?.text || ''), req.body || {})));
app.post('/browser/press-key', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').pressKey(req.body?.key, req.body?.screenshot !== false)));
app.post('/browser/scroll', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').scroll(req.body?.deltaX ?? 0, req.body?.deltaY ?? 0, req.body?.screenshot !== false)));
app.post('/browser/extract', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').extractContent(req.body || {})));
app.post('/browser/execute', async (req, res) => handle(res, () => requireCapability(browserController, 'browser').executeJS(req.body?.code)));
app.post('/browser/close', async (_req, res) => handle(res, () => requireCapability(browserController, 'browser').closeBrowser().then(() => ({ success: true }))));

app.get('/android/status', async (_req, res) => handle(res, () => requireCapability(androidController, 'android').getStatus()));
app.post('/android/start', async (req, res) => handle(res, () => requireCapability(androidController, 'android').requestStartEmulator(req.body || {})));
app.post('/android/stop', async (_req, res) => handle(res, () => requireCapability(androidController, 'android').stopEmulator()));
app.get('/android/devices', async (_req, res) => handle(res, async () => ({ devices: await requireCapability(androidController, 'android').listDevices() })));
app.post('/android/screenshot', async (req, res) => handle(res, () => requireCapability(androidController, 'android').screenshot(req.body || {})));
app.post('/android/observe', async (req, res) => handle(res, () => requireCapability(androidController, 'android').observe(req.body || {})));
app.post('/android/ui-dump', async (req, res) => handle(res, () => requireCapability(androidController, 'android').dumpUi(req.body || {})));
app.get('/android/apps', async (req, res) => handle(res, () => requireCapability(androidController, 'android').listApps({ includeSystem: req.query.includeSystem === 'true' })));
app.post('/android/open-app', async (req, res) => handle(res, () => requireCapability(androidController, 'android').openApp(req.body || {})));
app.post('/android/open-intent', async (req, res) => handle(res, () => requireCapability(androidController, 'android').openIntent(req.body || {})));
app.post('/android/tap', async (req, res) => handle(res, () => requireCapability(androidController, 'android').tap(req.body || {})));
app.post('/android/long-press', async (req, res) => handle(res, () => requireCapability(androidController, 'android').longPress(req.body || {})));
app.post('/android/type', async (req, res) => handle(res, () => requireCapability(androidController, 'android').type(req.body || {})));
app.post('/android/swipe', async (req, res) => handle(res, () => requireCapability(androidController, 'android').swipe(req.body || {})));
app.post('/android/press-key', async (req, res) => handle(res, () => requireCapability(androidController, 'android').pressKey(req.body || {})));
app.post('/android/wait-for', async (req, res) => handle(res, () => requireCapability(androidController, 'android').waitFor(req.body || {})));
app.post('/android/shell', async (req, res) => handle(res, () => requireCapability(androidController, 'android').shell(req.body || {})));
app.post('/android/install-apk', async (req, res) => {
  await handle(res, async () => {
    requireCapability(androidController, 'android');
    const filename = String(req.body?.filename || 'upload.apk').trim() || 'upload.apk';
    const contentBase64 = String(req.body?.contentBase64 || '').trim();
    if (!contentBase64) {
      return { error: 'contentBase64 is required' };
    }
    const uploadDir = path.join(FILE_ROOT, 'uploads');
    fs.mkdirSync(uploadDir, { recursive: true });
    const tempPath = path.join(uploadDir, `${Date.now()}-${path.basename(filename)}`);
    fs.writeFileSync(tempPath, Buffer.from(contentBase64, 'base64'));
    try {
      return await androidController.installApk({ apkPath: tempPath });
    } finally {
      fs.rmSync(tempPath, { force: true });
    }
  });
});

app.post('/android/install-apk-stream', async (req, res) => {
  const filename = decodeURIComponent(
    String(req.headers['x-neoagent-filename'] || 'upload.apk').trim() || 'upload.apk',
  );
  const uploadDir = path.join(FILE_ROOT, 'uploads');
  fs.mkdirSync(uploadDir, { recursive: true });
  const tempPath = path.join(uploadDir, `${Date.now()}-${path.basename(filename)}`);
  const output = fs.createWriteStream(tempPath);
  let finished = false;
  let receivedBytes = 0;

  const cleanup = async () => {
    await fs.promises.unlink(tempPath).catch(() => {});
  };

  const fail = async (status, error) => {
    if (!finished) {
      finished = true;
      output.destroy();
      await cleanup();
      if (!res.headersSent) {
        res.status(status).json({ error: sanitizeError(error) });
      }
    }
  };

  req.on('error', (err) => {
    void fail(500, err);
  });
  req.on('data', (chunk) => {
    if (finished) {
      return;
    }
    receivedBytes += chunk.length;
    if (receivedBytes > MAX_APK_STREAM_BYTES) {
      void fail(413, `APK stream exceeds limit of ${MAX_APK_STREAM_BYTES} bytes.`);
      req.destroy();
    }
  });
  output.on('error', (err) => {
    void fail(500, err);
  });

  output.on('finish', async () => {
    if (finished) {
      return;
    }
    try {
      requireCapability(androidController, 'android');
      const result = await androidController.installApk({ apkPath: tempPath });
      finished = true;
      await cleanup();
      res.json(result);
    } catch (err) {
      await fail(500, err);
    }
  });

  req.pipe(output);
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`NeoAgent guest agent listening on http://0.0.0.0:${PORT}`);
});

async function shutdown() {
  try {
    await browserController?.closeBrowser?.();
  } catch (err) {
    console.warn('[GuestAgent] Failed to close browser:', err?.message);
  }
  try {
    await androidController?.close?.();
  } catch (err) {
    console.warn('[GuestAgent] Failed to close android controller:', err?.message);
  }
  cliExecutor.killAll('shutdown');
  server.close(() => process.exit(0));
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
