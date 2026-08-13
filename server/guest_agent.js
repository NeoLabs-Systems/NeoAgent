'use strict';

const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
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
const RAW_GUEST_PROFILE = String(process.env.NEOAGENT_GUEST_PROFILE || 'browser_cli').trim();
const GUEST_PROFILE = ['android', 'browser', 'cli', 'browser_cli'].includes(RAW_GUEST_PROFILE)
  ? RAW_GUEST_PROFILE
  : 'browser_cli';
const FILE_ROOT = path.join(RUNTIME_HOME, 'guest-agent-files');
const WORKSPACE_ROOT = path.resolve(process.env.NEOAGENT_WORKSPACE_DIR || path.join(os.homedir(), 'workspace'));
const MAX_WORKSPACE_FILE_BYTES = 16 * 1024 * 1024;
const MAX_WORKSPACE_IMPORT_BYTES = Number(
  process.env.NEOAGENT_GUEST_MAX_WORKSPACE_IMPORT_BYTES || 4 * 1024 * 1024 * 1024,
);
const MIN_FREE_DISK_BYTES = Number(
  process.env.NEOAGENT_GUEST_MIN_FREE_DISK_BYTES || 256 * 1024 * 1024,
);
const MAX_APK_STREAM_BYTES = Number(process.env.NEOAGENT_GUEST_MAX_APK_STREAM_BYTES || 512 * 1024 * 1024);
const CLOUD_INIT_BOOT_FINISHED = '/var/lib/cloud/instance/boot-finished';

fs.mkdirSync(FILE_ROOT, { recursive: true });
fs.mkdirSync(WORKSPACE_ROOT, { recursive: true });

const app = express();
app.use(express.json({ limit: '100mb' }));

const cliExecutor = ['cli', 'browser_cli', 'android'].includes(GUEST_PROFILE)
  ? new (require('./services/cli/executor').CLIExecutor)()
  : null;
const browserController = ['browser', 'browser_cli'].includes(GUEST_PROFILE)
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
  WORKSPACE_ROOT,
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
  if (!AUTH_TOKEN) {
    // Token not configured in this environment — allow but unauthenticated.
    // Pass NEOAGENT_VM_GUEST_TOKEN to the container to enforce auth.
    return next();
  }
  const header = String(req.headers?.authorization || '').trim();
  const prefix = 'Bearer ';
  const provided = header.startsWith(prefix) ? header.slice(prefix.length).trim() : '';
  if (!provided || provided !== AUTH_TOKEN) {
    return res.status(401).json({ error: 'Unauthorized.' });
  }
  return next();
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

function resolveWorkspacePath(value = '.', options = {}) {
  const requested = String(value || '.').trim() || '.';
  if (requested.includes('\0')) throw new Error('Workspace path contains invalid characters.');
  const candidate = path.resolve(WORKSPACE_ROOT, requested);
  const relative = path.relative(WORKSPACE_ROOT, candidate);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error('Workspace path is outside the computer workspace.');
  }
  if (options.mustExist !== false && !fs.existsSync(candidate)) {
    const error = new Error('Workspace path does not exist.');
    error.code = 'ENOENT';
    throw error;
  }
  return candidate;
}

function relativeWorkspacePath(value) {
  const relative = path.relative(WORKSPACE_ROOT, value);
  return relative && relative !== '.' ? relative.split(path.sep).join('/') : '';
}

function availableDiskBytes(target = WORKSPACE_ROOT) {
  const stats = fs.statfsSync(target);
  return Number(stats.bavail) * Number(stats.bsize);
}

function assertDiskSafety(requiredBytes = 0) {
  if (availableDiskBytes() - Number(requiredBytes || 0) < MIN_FREE_DISK_BYTES) {
    const error = new Error('The computer data disk has reached its safety limit. Remove files before continuing.');
    error.code = 'COMPUTER_DISK_LIMIT';
    throw error;
  }
}

function runSudo(args, options = {}) {
  return spawnSync('sudo', ['-n', ...args], {
    encoding: 'utf8',
    timeout: Number(options.timeoutMs || 30000),
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function writePrivilegedFile(filePath, content) {
  const encoded = Buffer.from(String(content)).toString('base64');
  const result = runSudo([
    '/bin/sh',
    '-c',
    `install -d -m 0755 ${JSON.stringify(path.posix.dirname(filePath))} && echo ${encoded} | base64 -d > ${JSON.stringify(filePath)}`,
  ]);
  if (result.status !== 0) {
    throw new Error(String(result.stderr || result.stdout || `Failed to write ${filePath}`).trim());
  }
}

function displayServerAlive() {
  const probe = spawnSync('xdpyinfo', ['-display', ':0'], {
    encoding: 'utf8',
    timeout: 3000,
    env: { ...process.env, DISPLAY: ':0' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  return probe.status === 0;
}

async function waitForDisplay(timeoutMs = 12000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (displayServerAlive()) return true;
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  return displayServerAlive();
}

function runDesktopCommand(command, args = [], options = {}) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    timeout: Number(options.timeoutMs || 15000),
    env: { ...process.env, DISPLAY: process.env.DISPLAY || ':0' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.error || result.status !== 0) {
    const detail = String(result.stderr || result.stdout || result.error?.message || '').trim();
    throw new Error(detail || `${command} failed with exit code ${result.status}.`);
  }
  return String(result.stdout || '').trim();
}

function desktopPoint(body = {}) {
  const x = Number(body.x);
  const y = Number(body.y);
  if (!Number.isFinite(x) || !Number.isFinite(y)) {
    throw new Error('x and y must be finite coordinates.');
  }
  return { x: Math.round(x), y: Math.round(y) };
}

async function handle(res, work) {
  try {
    res.json(await work());
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
}

async function handleRequest(req, res, work) {
  const controller = new AbortController();
  const abort = () => {
    if (!res.writableEnded) controller.abort('Guest runtime request disconnected.');
  };
  req.once('aborted', abort);
  res.once('close', abort);
  try {
    const result = await work(controller.signal);
    if (!res.headersSent && !res.writableEnded) res.json(result);
  } catch (err) {
    if (!res.headersSent && !res.writableEnded) {
      res.status(controller.signal.aborted ? 499 : 500).json({ error: sanitizeError(err) });
    }
  } finally {
    req.removeListener('aborted', abort);
    res.removeListener('close', abort);
  }
}

app.use(requireToken);

app.get('/health', (_req, res) => {
  const cloudInitFinished = fs.existsSync(CLOUD_INIT_BOOT_FINISHED);
  res.json({
    status: cloudInitFinished ? 'ok' : 'starting',
    runtime: 'guest-agent',
    profile: GUEST_PROFILE,
    platform: process.platform,
    arch: process.arch,
    cloudInitFinished,
  });
});

app.get('/system/boot-assets', async (_req, res) => {
  await handle(res, async () => {
    const release = os.release();
    const kernelPath = `/boot/vmlinuz-${release}`;
    const initrdPath = `/boot/initrd.img-${release}`;
    const kernel = fs.readFileSync(kernelPath);
    const initrd = fs.readFileSync(initrdPath);
    const encode = (data) => ({
      sha256: crypto.createHash('sha256').update(data).digest('hex'),
      size: data.length,
      content: data.toString('base64'),
    });
    return {
      release,
      kernel: encode(kernel),
      initrd: encode(initrd),
    };
  });
});

app.post('/exec', async (req, res) => {
  await handleRequest(req, res, async (signal) => {
    assertDiskSafety();
    const executor = requireCapability(cliExecutor, 'cli');
    const command = String(req.body?.command || '').trim();
    if (!command) {
      return { error: 'command is required' };
    }
    if (req.body?.pty) {
      return executor.executeInteractive(command, req.body?.inputs || [], {
        cwd: req.body?.cwd,
        timeout: req.body?.timeout,
        signal,
      });
    }
    return executor.execute(command, {
      cwd: req.body?.cwd,
      timeout: req.body?.timeout,
      stdinInput: req.body?.stdin_input,
      signal,
    });
  });
});

app.post('/exec/kill', async (req, res) => {
  await handle(res, async () => {
    const executor = requireCapability(cliExecutor, 'cli');
    const pid = Number(req.body?.pid);
    if (!Number.isInteger(pid) || pid <= 0) {
      return { error: 'pid is required' };
    }
    const reason = String(req.body?.reason || 'aborted').trim();
    if (typeof executor.isManaged === 'function' && !executor.isManaged(pid)) {
      return { error: 'pid not managed' };
    }
    const killed = executor.kill(pid, reason || 'aborted');
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
    const deleteAfterRead = req.body?.delete_after_read === true
      && (
        realTarget.startsWith(`${path.resolve(os.tmpdir())}${path.sep}`)
        || realTarget.startsWith(`${path.resolve(FILE_ROOT)}${path.sep}`)
      );
    if (deleteAfterRead) {
      try {
        fs.unlinkSync(realTarget);
        fs.rmdirSync(path.dirname(realTarget));
      } catch {}
    }
    return {
      path: realTarget,
      encoding,
      content: encoding === 'utf8' ? data.toString('utf8') : data.toString('base64'),
      byteSize: data.length,
    };
  });
});

app.post('/workspace/import', async (req, res) => {
  const expectedDigest = String(req.headers['x-neoagent-sha256'] || '').trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(expectedDigest)) {
    res.status(400).json({ error: 'A valid workspace archive checksum is required.' });
    return;
  }
  try {
    assertDiskSafety(Number(req.headers['content-length'] || 0));
  } catch (error) {
    res.status(507).json({ error: sanitizeError(error), code: error.code });
    return;
  }
  const importRoot = path.join(os.homedir(), '.neoagent', 'imports');
  fs.mkdirSync(importRoot, { recursive: true });
  const archivePath = path.join(importRoot, `${crypto.randomUUID()}.tar.gz`);
  const output = fs.createWriteStream(archivePath, { mode: 0o600 });
  const hash = crypto.createHash('sha256');
  let receivedBytes = 0;
  let settled = false;

  const cleanup = () => fs.promises.rm(archivePath, { force: true }).catch(() => {});
  const fail = async (status, error) => {
    if (settled) return;
    settled = true;
    output.destroy();
    await cleanup();
    if (!res.headersSent) res.status(status).json({ error: sanitizeError(error) });
  };

  req.on('error', (error) => { void fail(500, error); });
  req.on('data', (chunk) => {
    if (settled) return;
    receivedBytes += chunk.length;
    if (receivedBytes > MAX_WORKSPACE_IMPORT_BYTES) {
      void fail(413, 'Workspace import exceeds the guest disk safety limit.');
      req.destroy();
      return;
    }
    hash.update(chunk);
  });
  req.pipe(output);
  output.once('error', (error) => { void fail(500, error); });
  output.once('finish', async () => {
    if (settled) return;
    const digest = hash.digest('hex');
    if (digest !== expectedDigest) {
      await fail(400, 'Workspace import checksum verification failed.');
      return;
    }
    const listing = spawnSync('tar', ['-tzf', archivePath], {
      encoding: 'utf8',
      timeout: 120000,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const entries = String(listing.stdout || '').split(/\r?\n/).filter(Boolean);
    const unsafe = listing.status !== 0 || entries.some((entry) => {
      const normalized = entry.replaceAll('\\', '/');
      return normalized.startsWith('/') || normalized.split('/').includes('..');
    });
    if (unsafe) {
      await fail(400, 'Workspace archive contains an unsafe path.');
      return;
    }
    const extracted = spawnSync('tar', [
      '-xzf', archivePath,
      '-C', WORKSPACE_ROOT,
      '--no-same-owner',
      '--no-same-permissions',
    ], {
      encoding: 'utf8',
      timeout: 10 * 60 * 1000,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    if (extracted.status !== 0) {
      await fail(500, String(extracted.stderr || 'Workspace extraction failed.'));
      return;
    }
    settled = true;
    await cleanup();
    res.json({ success: true, sha256: digest, entries: entries.length });
  });
});

app.get('/workspace/files', async (req, res) => {
  await handle(res, async () => {
    const directory = resolveWorkspacePath(req.query?.path || '.');
    const stats = fs.statSync(directory);
    if (!stats.isDirectory()) throw new Error('Workspace path is not a directory.');
    const entries = fs.readdirSync(directory, { withFileTypes: true })
      .slice(0, 1000)
      .map((entry) => {
        const absolutePath = path.join(directory, entry.name);
        const entryStats = fs.lstatSync(absolutePath);
        return {
          name: entry.name,
          path: relativeWorkspacePath(absolutePath),
          type: entry.isDirectory() ? 'directory' : entry.isSymbolicLink() ? 'symlink' : 'file',
          size: entryStats.isFile() ? entryStats.size : null,
          modifiedAt: entryStats.mtime.toISOString(),
        };
      })
      .sort((left, right) => {
        if (left.type !== right.type) return left.type === 'directory' ? -1 : 1;
        return left.name.localeCompare(right.name);
      });
    return { path: relativeWorkspacePath(directory), entries };
  });
});

app.get('/workspace/files/content', async (req, res) => {
  await handle(res, async () => {
    const filePath = resolveWorkspacePath(req.query?.path || '');
    const stats = fs.statSync(filePath);
    if (!stats.isFile()) throw new Error('Workspace path is not a file.');
    if (stats.size > MAX_WORKSPACE_FILE_BYTES) throw new Error('Workspace file is too large to edit.');
    return {
      path: relativeWorkspacePath(filePath),
      content: fs.readFileSync(filePath, 'utf8'),
      size: stats.size,
      modifiedAt: stats.mtime.toISOString(),
    };
  });
});

app.put('/workspace/files/content', async (req, res) => {
  await handle(res, async () => {
    const content = String(req.body?.content ?? '');
    const contentBytes = Buffer.byteLength(content, 'utf8');
    if (contentBytes > MAX_WORKSPACE_FILE_BYTES) {
      throw new Error('Workspace file is too large to edit.');
    }
    assertDiskSafety(contentBytes);
    const filePath = resolveWorkspacePath(req.body?.path || '', { mustExist: false });
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    const temporary = path.join(
      path.dirname(filePath),
      `.${path.basename(filePath)}.${process.pid}.${Date.now()}.tmp`,
    );
    fs.writeFileSync(temporary, content, { encoding: 'utf8', mode: 0o600 });
    fs.renameSync(temporary, filePath);
    return { success: true, path: relativeWorkspacePath(filePath) };
  });
});

app.get('/workspace/files/download', async (req, res) => {
  try {
    const filePath = resolveWorkspacePath(req.query?.path || '');
    const stats = fs.statSync(filePath);
    if (!stats.isFile()) throw new Error('Workspace path is not a file.');
    if (stats.size > MAX_WORKSPACE_FILE_BYTES) throw new Error('Workspace file exceeds the download limit.');
    res.json({
      path: relativeWorkspacePath(filePath),
      filename: path.basename(filePath),
      contentType: 'application/octet-stream',
      encoding: 'base64',
      content: fs.readFileSync(filePath).toString('base64'),
      size: stats.size,
    });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

app.post('/workspace/search', async (req, res) => {
  await handle(res, async () => {
    const start = resolveWorkspacePath(req.body?.path || '.');
    const filenameQuery = String(req.body?.glob || req.body?.filename || '').trim().toLowerCase();
    const contentQuery = String(req.body?.query || '').trim();
    const maximumResults = Math.min(500, Math.max(1, Number(req.body?.maxResults || 100)));
    const results = [];
    const pending = [start];
    while (pending.length > 0 && results.length < maximumResults) {
      const current = pending.shift();
      for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
        if (entry.isSymbolicLink()) continue;
        const absolutePath = path.join(current, entry.name);
        if (entry.isDirectory()) {
          if (!['.git', 'node_modules', '.cache'].includes(entry.name)) pending.push(absolutePath);
          continue;
        }
        if (!entry.isFile()) continue;
        if (filenameQuery && !entry.name.toLowerCase().includes(filenameQuery.replaceAll('*', ''))) continue;
        const stats = fs.statSync(absolutePath);
        if (!contentQuery) {
          results.push({ path: relativeWorkspacePath(absolutePath), size: stats.size });
          if (results.length >= maximumResults) break;
          continue;
        }
        if (stats.size > 2 * 1024 * 1024) continue;
        const content = fs.readFileSync(absolutePath, 'utf8');
        const lines = content.split('\n');
        for (let index = 0; index < lines.length && results.length < maximumResults; index += 1) {
          if (lines[index].includes(contentQuery)) {
            results.push({
              path: relativeWorkspacePath(absolutePath),
              line: index + 1,
              text: lines[index].slice(0, 500),
            });
          }
        }
      }
    }
    return { results, truncated: results.length >= maximumResults };
  });
});

app.get('/desktop/status', async (_req, res) => {
  await handle(res, async () => {
    let activeWindow = null;
    let resolution = null;
    try {
      activeWindow = runDesktopCommand('xdotool', ['getactivewindow', 'getwindowname']);
    } catch {}
    try {
      resolution = runDesktopCommand('xdpyinfo', []).match(/dimensions:\s+(\d+x\d+)/)?.[1] || null;
    } catch {}
    return {
      available: displayServerAlive(),
      display: ':0',
      activeWindow,
      resolution,
    };
  });
});

app.post('/desktop/ensure', async (_req, res) => {
  await handle(res, async () => {
    runSudo(['rm', '-f', '/etc/X11/xorg.conf.d/10-neoagent-display.conf']);
    writePrivilegedFile(
      '/etc/lightdm/lightdm.conf.d/50-neoagent.conf',
      [
        '[LightDM]',
        'start-default-seat=true',
        'logind-check-graphical=false',
        '',
        '[Seat:*]',
        'autologin-user=neo',
        'autologin-user-timeout=0',
        'autologin-session=openbox',
        'user-session=openbox',
        'xserver-command=X -nolisten tcp vt7',
        'display-setup-script=/usr/local/bin/neoagent-display-setup',
        '',
      ].join('\n'),
    );
    const framebufferOnly = fs.existsSync('/dev/fb0') && !fs.existsSync('/dev/dri/card0');
    if (framebufferOnly) {
      writePrivilegedFile(
        '/etc/X11/xorg.conf.d/10-neoagent-display.conf',
        [
          'Section "Device"',
          '    Identifier "NeoAgentGPU"',
          '    Driver "fbdev"',
          '    Option "fbdev" "/dev/fb0"',
          'EndSection',
          'Section "Screen"',
          '    Identifier "NeoAgentScreen"',
          '    Device "NeoAgentGPU"',
          '    DefaultDepth 16',
          '    SubSection "Display"',
          '        Depth 16',
          '    EndSubSection',
          'EndSection',
          '',
        ].join('\n'),
      );
    }
    runSudo(['systemctl', 'set-default', 'graphical.target']);
    runSudo(['systemctl', 'enable', 'lightdm.service', 'neoagent-desktop-seat.service']);
    const restart = runSudo(['systemctl', 'restart', 'lightdm.service'], { timeoutMs: 45000 });
    if (restart.status !== 0 && !displayServerAlive()) {
      throw new Error(String(restart.stderr || restart.stdout || 'LightDM failed to restart').trim());
    }
    if (await waitForDisplay(12000)) {
      runSudo(['chvt', '7']);
      return { available: true, display: ':0', fallback: framebufferOnly ? 'fbdev' : null };
    }

    writePrivilegedFile(
      '/etc/X11/xorg.conf.d/10-neoagent-display.conf',
      [
        'Section "Device"',
        '    Identifier "NeoAgentGPU"',
        '    Driver "fbdev"',
        '    Option "fbdev" "/dev/fb0"',
        'EndSection',
        'Section "Screen"',
        '    Identifier "NeoAgentScreen"',
        '    Device "NeoAgentGPU"',
        '    DefaultDepth 16',
        '    SubSection "Display"',
        '        Depth 16',
        '    EndSubSection',
        'EndSection',
        '',
      ].join('\n'),
    );
    runSudo(['systemctl', 'restart', 'lightdm.service'], { timeoutMs: 45000 });
    if (await waitForDisplay(12000)) {
      runSudo(['chvt', '7']);
      return { available: true, display: ':0', fallback: 'fbdev' };
    }

    let xorgLog = '';
    try {
      xorgLog = fs.readFileSync('/var/log/Xorg.0.log', 'utf8').slice(-4000);
    } catch {}
    const error = new Error('The Linux desktop did not start.');
    error.code = 'COMPUTER_DESKTOP_UNAVAILABLE';
    if (xorgLog) error.message += ` ${xorgLog.split('\n').slice(-8).join(' ')}`;
    throw error;
  });
});

app.post('/desktop/screenshot', async (_req, res) => {
  await handle(res, async () => {
    const outputPath = path.join(FILE_ROOT, `desktop-${Date.now()}-${crypto.randomBytes(4).toString('hex')}.png`);
    runDesktopCommand('scrot', ['--silent', outputPath], { timeoutMs: 30000 });
    return { success: true, path: outputPath };
  });
});

app.post('/desktop/click', async (req, res) => {
  await handle(res, async () => {
    const point = desktopPoint(req.body);
    runDesktopCommand('xdotool', ['mousemove', '--sync', String(point.x), String(point.y), 'click', String(Number(req.body?.button || 1))]);
    return { success: true, ...point };
  });
});

app.post('/desktop/mouse-move', async (req, res) => {
  await handle(res, async () => {
    const point = desktopPoint(req.body);
    runDesktopCommand('xdotool', ['mousemove', '--sync', String(point.x), String(point.y)]);
    return { success: true, ...point };
  });
});

app.post('/desktop/drag', async (req, res) => {
  await handle(res, async () => {
    const startX = Number(req.body?.startX);
    const startY = Number(req.body?.startY);
    const endX = Number(req.body?.endX);
    const endY = Number(req.body?.endY);
    if (![startX, startY, endX, endY].every(Number.isFinite)) throw new Error('Drag coordinates are required.');
    runDesktopCommand('xdotool', [
      'mousemove', '--sync', String(Math.round(startX)), String(Math.round(startY)),
      'mousedown', '1',
      'mousemove', '--sync', String(Math.round(endX)), String(Math.round(endY)),
      'mouseup', '1',
    ]);
    return { success: true };
  });
});

app.post('/desktop/scroll', async (req, res) => {
  await handle(res, async () => {
    const deltaY = Number(req.body?.deltaY || 0);
    const button = deltaY < 0 ? '4' : '5';
    const count = Math.min(20, Math.max(1, Math.ceil(Math.abs(deltaY) / 120)));
    runDesktopCommand('xdotool', ['click', '--repeat', String(count), button]);
    return { success: true, deltaY };
  });
});

app.post('/desktop/type-text', async (req, res) => {
  await handle(res, async () => {
    const text = String(req.body?.text || '');
    if (text.length > 10000) throw new Error('Desktop text exceeds the input limit.');
    runDesktopCommand('xdotool', ['type', '--clearmodifiers', '--delay', '1', '--', text], { timeoutMs: 30000 });
    return { success: true, length: text.length };
  });
});

app.post('/desktop/press-key', async (req, res) => {
  await handle(res, async () => {
    const key = String(req.body?.key || '').trim();
    if (!/^[A-Za-z0-9_+\-]{1,64}$/.test(key)) throw new Error('Desktop key is invalid.');
    runDesktopCommand('xdotool', ['key', '--clearmodifiers', key]);
    return { success: true, key };
  });
});

app.post('/desktop/launch-app', async (req, res) => {
  await handle(res, async () => {
    const application = String(req.body?.application || req.body?.app || '').trim().toLowerCase();
    const commands = {
      browser: ['chromium', [
        `--user-data-dir=${path.join(DATA_DIR, 'browser-profiles', 'default')}`,
        '--no-first-run',
        '--no-default-browser-check',
      ]],
      files: ['pcmanfm', [WORKSPACE_ROOT]],
      terminal: ['lxterminal', [`--working-directory=${WORKSPACE_ROOT}`]],
      editor: ['mousepad', []],
    };
    const command = commands[application];
    if (!command) throw new Error('Application must be browser, files, terminal, or editor.');
    const child = require('child_process').spawn(command[0], command[1], {
      detached: true,
      stdio: 'ignore',
      env: { ...process.env, DISPLAY: process.env.DISPLAY || ':0' },
    });
    child.unref();
    return { success: true, application };
  });
});

app.get('/teach/context', async (_req, res) => {
  await handle(res, async () => {
    let activeWindow = null;
    try {
      activeWindow = runDesktopCommand('sh', [
        '-lc',
        'window=$(xdotool getactivewindow 2>/dev/null) && xdotool getwindowname "$window"',
      ]).slice(0, 300) || null;
    } catch {}

    let accessibility = [];
    let sensitiveInputActive = false;
    try {
      const script = [
        'import json, pyatspi',
        'desktop = pyatspi.Registry.getDesktop(0)',
        'result = []',
        'sensitive = [False]',
        'def walk(node, depth=0):',
        '    if depth > 4 or len(result) >= 300: return',
        '    try:',
        '        role = node.getRoleName()',
        '        name = str(node.name or "")[:200]',
        '        if role == "password text": name = "[sensitive]"',
        '        if role or name: result.append({"role": role, "name": name})',
        '        if role == "password text" and node.getState().contains(pyatspi.STATE_FOCUSED): sensitive[0] = True',
        '        for child in node: walk(child, depth + 1)',
        '    except Exception: pass',
        'walk(desktop)',
        'print(json.dumps({"nodes": result, "sensitiveInputActive": sensitive[0]}, separators=(",", ":")))',
      ].join('\n');
      const output = runDesktopCommand('python3', ['-c', script], { timeoutMs: 10000 });
      const parsed = JSON.parse(output);
      accessibility = Array.isArray(parsed?.nodes) ? parsed.nodes : [];
      sensitiveInputActive = parsed?.sensitiveInputActive === true;
    } catch {}

    if (sensitiveInputActive) {
      return { activeWindow, accessibility, sensitiveInputActive, shellEvents: [], files: [] };
    }

    const shellEventPath = path.join(os.homedir(), '.neoagent', 'teach-shell-events.jsonl');
    let shellEvents = [];
    try {
      shellEvents = fs.readFileSync(shellEventPath, 'utf8')
        .split(/\r?\n/)
        .filter(Boolean)
        .slice(-50)
        .map((line) => JSON.parse(line));
    } catch {}

    const files = [];
    const pending = [WORKSPACE_ROOT];
    while (pending.length > 0 && files.length < 500) {
      const current = pending.shift();
      let entries = [];
      try { entries = fs.readdirSync(current, { withFileTypes: true }); } catch { continue; }
      for (const entry of entries) {
        if (files.length >= 500) break;
        const absolute = path.join(current, entry.name);
        if (entry.isDirectory()) {
          pending.push(absolute);
        } else if (entry.isFile()) {
          const stats = fs.statSync(absolute);
          files.push({
            path: relativeWorkspacePath(absolute),
            size: stats.size,
            modifiedAt: stats.mtime.toISOString(),
          });
        }
      }
    }
    return { activeWindow, accessibility, sensitiveInputActive, shellEvents, files };
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

app.use('/browser', (req, res, next) => {
  if (!browserController?.hasProtectedCredentialFill?.()) return next();
  const allowed = new Set([
    '/status',
    '/credential-submit',
    '/credential-cancel',
    '/close',
  ]);
  if (allowed.has(req.path)) return next();
  return res.status(423).json({
    error: 'Browser control is paused while a protected credential fill is active. Submit or cancel it first.',
    code: 'PROTECTED_CREDENTIAL_FILL_ACTIVE',
  });
});

function requireCapability(controller, name) {
  if (!controller) {
    throw new Error(`${name} runtime is unavailable in this guest profile.`);
  }
  return controller;
}

app.post('/browser/launch', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').launch({ ...(req.body || {}), signal })));
app.post('/browser/navigate', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').navigate(req.body?.url, { ...(req.body || {}), signal })));
app.post('/browser/screenshot', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').screenshot({ ...(req.body || {}), signal })));
app.post('/browser/screenshot-jpeg', async (req, res) => handleRequest(req, res, async (signal) => {
  const jpeg = await requireCapability(browserController, 'browser').screenshotJpeg(req.body?.quality, { ...(req.body || {}), signal });
  return {
    contentType: 'image/jpeg',
    contentBase64: Buffer.from(jpeg).toString('base64'),
  };
}));
app.post('/browser/click', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').click(req.body?.selector, req.body?.text, req.body?.screenshot !== false, { signal })));
app.post('/browser/click-point', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').clickPoint(req.body?.x, req.body?.y, req.body?.screenshot !== false, { signal })));
app.post('/browser/fill', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').type(req.body?.selector, String(req.body?.value ?? req.body?.text ?? ''), { ...(req.body || {}), signal })));
app.post('/browser/credential-fill', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').fillCredential(req.body || {}, { signal })));
app.post('/browser/credential-submit', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').submitProtectedCredential(req.body?.protectedFillId, { signal })));
app.post('/browser/credential-cancel', async (req, res) => handleRequest(req, res, () => requireCapability(browserController, 'browser').cancelProtectedCredential(req.body?.protectedFillId)));
app.post('/browser/type-text', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').typeText(String(req.body?.text || ''), { ...(req.body || {}), signal })));
app.post('/browser/press-key', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').pressKey(req.body?.key, req.body?.screenshot !== false, { signal })));
app.post('/browser/scroll', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').scroll(req.body?.deltaX ?? 0, req.body?.deltaY ?? 0, req.body?.screenshot !== false, { signal })));
app.post('/browser/extract', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').extractContent({ ...(req.body || {}), signal })));
app.post('/browser/execute', async (req, res) => handleRequest(req, res, (signal) => requireCapability(browserController, 'browser').executeJS(req.body?.code, { signal })));
app.post('/browser/close', async (_req, res) => handle(res, () => requireCapability(browserController, 'browser').closeBrowser().then(() => ({ success: true }))));

app.get('/android/status', async (_req, res) => handle(res, () => requireCapability(androidController, 'android').getStatus()));
app.post('/android/start', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').requestStartEmulator({ ...(req.body || {}), signal })));
app.post('/android/stop', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').stopEmulator({ signal })));
app.get('/android/devices', async (req, res) => handleRequest(req, res, async (signal) => ({ devices: await requireCapability(androidController, 'android').listDevices({ signal }) })));
app.post('/android/screenshot', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').screenshot({ ...(req.body || {}), signal })));
app.post('/android/observe', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').observe({ ...(req.body || {}), signal })));
app.post('/android/ui-dump', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').dumpUi({ ...(req.body || {}), signal })));
app.get('/android/apps', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').listApps({ includeSystem: req.query.includeSystem === 'true', signal })));
app.post('/android/open-app', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').openApp({ ...(req.body || {}), signal })));
app.post('/android/open-intent', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').openIntent({ ...(req.body || {}), signal })));
app.post('/android/tap', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').tap({ ...(req.body || {}), signal })));
app.post('/android/long-press', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').longPress({ ...(req.body || {}), signal })));
app.post('/android/type', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').type({ ...(req.body || {}), signal })));
app.post('/android/swipe', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').swipe({ ...(req.body || {}), signal })));
app.post('/android/press-key', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').pressKey({ ...(req.body || {}), signal })));
app.post('/android/wait-for', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').waitFor({ ...(req.body || {}), signal })));
app.post('/android/shell', async (req, res) => handleRequest(req, res, (signal) => requireCapability(androidController, 'android').shell({ ...(req.body || {}), signal })));
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
  cliExecutor?.killAll?.('shutdown');
  server.close(() => process.exit(0));
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
