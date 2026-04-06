'use strict';

const express = require('express');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { CLIExecutor } = require('./services/cli/executor');
const { BrowserController } = require('./services/browser/controller');
const { AndroidController } = require('./services/android/controller');
const { RUNTIME_HOME } = require('../runtime/paths');

const PORT = Number(process.env.NEOAGENT_GUEST_AGENT_PORT || 8421);
const AUTH_TOKEN = String(process.env.NEOAGENT_VM_GUEST_TOKEN || '').trim();
const FILE_ROOT = path.join(RUNTIME_HOME, 'guest-agent-files');

fs.mkdirSync(FILE_ROOT, { recursive: true });

const app = express();
app.use(express.json({ limit: '100mb' }));

const cliExecutor = new CLIExecutor();
const browserController = new BrowserController({ runtimeBackend: 'vm' });
const androidController = new AndroidController({ runtimeBackend: 'vm' });

function requireToken(req, res, next) {
  if (!AUTH_TOKEN) {
    return next();
  }
  const header = String(req.headers.authorization || '').trim();
  if (header !== `Bearer ${AUTH_TOKEN}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

function sanitizeError(err) {
  return err instanceof Error ? err.message : String(err);
}

function isReadablePath(filePath) {
  const resolved = path.resolve(String(filePath || ''));
  const allowedRoots = [
    FILE_ROOT,
    path.join(RUNTIME_HOME, 'data'),
    path.join(RUNTIME_HOME, 'android'),
    os.tmpdir(),
  ].map((value) => path.resolve(value));
  return allowedRoots.some((root) => resolved === root || resolved.startsWith(`${root}${path.sep}`));
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

app.post('/files/read', async (req, res) => {
  await handle(res, async () => {
    const filePath = String(req.body?.path || '').trim();
    const encoding = String(req.body?.encoding || 'base64').trim().toLowerCase();
    if (!filePath) {
      return { error: 'path is required' };
    }
    if (!isReadablePath(filePath)) {
      return { error: 'path is outside guest-agent readable roots' };
    }
    const resolved = path.resolve(filePath);
    const data = fs.readFileSync(resolved);
    return {
      path: resolved,
      encoding,
      content: encoding === 'utf8' ? data.toString('utf8') : data.toString('base64'),
      byteSize: data.length,
    };
  });
});

app.get('/browser/status', async (_req, res) => {
  await handle(res, async () => ({
    launched: await Promise.resolve(browserController.isLaunched()),
    pages: await Promise.resolve(browserController.getPageCount()),
    headless: browserController.headless,
    pageInfo: await browserController.getPageInfo(),
  }));
});
app.post('/browser/launch', async (req, res) => handle(res, () => browserController.launch(req.body || {})));
app.post('/browser/navigate', async (req, res) => handle(res, () => browserController.navigate(req.body?.url, req.body || {})));
app.post('/browser/screenshot', async (req, res) => handle(res, () => browserController.screenshot(req.body || {})));
app.post('/browser/click', async (req, res) => handle(res, () => browserController.click(req.body?.selector, req.body?.text, req.body?.screenshot !== false)));
app.post('/browser/click-point', async (req, res) => handle(res, () => browserController.clickPoint(req.body?.x, req.body?.y, req.body?.screenshot !== false)));
app.post('/browser/fill', async (req, res) => handle(res, () => browserController.type(req.body?.selector, String(req.body?.value ?? req.body?.text ?? ''), req.body || {})));
app.post('/browser/type-text', async (req, res) => handle(res, () => browserController.typeText(String(req.body?.text || ''), req.body || {})));
app.post('/browser/press-key', async (req, res) => handle(res, () => browserController.pressKey(req.body?.key, req.body?.screenshot !== false)));
app.post('/browser/scroll', async (req, res) => handle(res, () => browserController.scroll(req.body?.deltaX ?? 0, req.body?.deltaY ?? 0, req.body?.screenshot !== false)));
app.post('/browser/extract', async (req, res) => handle(res, () => browserController.extractContent(req.body || {})));
app.post('/browser/execute', async (req, res) => handle(res, () => browserController.executeJS(req.body?.code)));
app.post('/browser/close', async (_req, res) => handle(res, () => browserController.closeBrowser().then(() => ({ success: true }))));

app.get('/android/status', async (_req, res) => handle(res, () => androidController.getStatus()));
app.post('/android/start', async (req, res) => handle(res, () => androidController.requestStartEmulator(req.body || {})));
app.post('/android/stop', async (_req, res) => handle(res, () => androidController.stopEmulator()));
app.get('/android/devices', async (_req, res) => handle(res, async () => ({ devices: await androidController.listDevices() })));
app.post('/android/screenshot', async (req, res) => handle(res, () => androidController.screenshot(req.body || {})));
app.post('/android/observe', async (req, res) => handle(res, () => androidController.observe(req.body || {})));
app.post('/android/ui-dump', async (req, res) => handle(res, () => androidController.dumpUi(req.body || {})));
app.get('/android/apps', async (req, res) => handle(res, () => androidController.listApps({ includeSystem: req.query.includeSystem === 'true' })));
app.post('/android/open-app', async (req, res) => handle(res, () => androidController.openApp(req.body || {})));
app.post('/android/open-intent', async (req, res) => handle(res, () => androidController.openIntent(req.body || {})));
app.post('/android/tap', async (req, res) => handle(res, () => androidController.tap(req.body || {})));
app.post('/android/long-press', async (req, res) => handle(res, () => androidController.longPress(req.body || {})));
app.post('/android/type', async (req, res) => handle(res, () => androidController.type(req.body || {})));
app.post('/android/swipe', async (req, res) => handle(res, () => androidController.swipe(req.body || {})));
app.post('/android/press-key', async (req, res) => handle(res, () => androidController.pressKey(req.body || {})));
app.post('/android/wait-for', async (req, res) => handle(res, () => androidController.waitFor(req.body || {})));
app.post('/android/shell', async (req, res) => handle(res, () => androidController.shell(req.body || {})));
app.post('/android/install-apk', async (req, res) => {
  await handle(res, async () => {
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
  output.on('error', (err) => {
    void fail(500, err);
  });

  output.on('finish', async () => {
    if (finished) {
      return;
    }
    try {
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

const server = app.listen(PORT, () => {
  console.log(`NeoAgent guest agent listening on http://127.0.0.1:${PORT}`);
});

async function shutdown() {
  try {
    await browserController.closeBrowser();
  } catch {}
  try {
    await androidController.close();
  } catch {}
  cliExecutor.killAll('shutdown');
  server.close(() => process.exit(0));
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
