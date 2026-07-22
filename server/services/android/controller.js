'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const net = require('net');
const os = require('os');
const path = require('path');
const { DATA_DIR, RUNTIME_HOME } = require('../../../runtime/paths');
const { validateAndroidIntentUrl } = require('../../utils/cloud-security');
const { validateImageBuffer } = require('../../utils/image_payload');
const { downloadFile, resolveCommandLineToolsRelease } = require('./sdk_download');
const { findBestNode, parseUiDump, summarizeNode } = require('./uia');
const { clampNumber, runProcess } = require('./process');

// ─── Constants ───────────────────────────────────────────────────────────────

const DEFAULT_SDK_DIR = path.join(RUNTIME_HOME, 'android-sdk');
const DEFAULT_AVD_DIR = path.join(RUNTIME_HOME, 'android', 'avd');
const STATE_DIR = path.join(DATA_DIR, 'android', 'state');
const LOGO_PATH = path.join(__dirname, '..', '..', '..', 'flutter_app', 'assets', 'branding', 'app_icon_512.png');

// Even console ports in the documented emulator range. Each emulator also owns
// the adjacent ADB port, so 64 pairs fit without crossing the supported range.
const ADB_PORT_BASE = 5554;
const ADB_PORT_SLOTS = 64;
const RESERVED_ADB_PORTS = new Set();
const SDK_PROVISIONING = new Map();

const MAX_ANDROID_TEXT_CHARS = 8000;
const MAX_ANDROID_INTENT_EXTRAS = 100;
const MAX_ANDROID_PACKAGE_BYTES = 1024 * 1024 * 1024;

fs.mkdirSync(STATE_DIR, { recursive: true });

// ─── State persistence ───────────────────────────────────────────────────────

function stateFile(userId) { return path.join(STATE_DIR, `${userId}.json`); }

function readState(userId) {
  try { return JSON.parse(fs.readFileSync(stateFile(userId), 'utf8')); }
  catch { return { userId, bootstrapped: false, starting: false, startupPhase: null, lastStartError: null, pid: null, adbSerial: null }; }
}

function writeState(userId, patch) {
  const current = readState(userId);
  const destination = stateFile(userId);
  const temporary = `${destination}.${process.pid}.${Math.random().toString(16).slice(2)}.tmp`;
  try {
    fs.writeFileSync(temporary, JSON.stringify({ ...current, ...patch }, null, 2), { mode: 0o600 });
    fs.renameSync(temporary, destination);
  } finally {
    try { fs.unlinkSync(temporary); } catch {}
  }
}

// ─── SDK resolution ──────────────────────────────────────────────────────────

function findExistingSdk() {
  const candidates = [
    process.env.ANDROID_HOME,
    process.env.ANDROID_SDK_ROOT,
    path.join(os.homedir(), 'Library', 'Android', 'sdk'),
    path.join(os.homedir(), 'Android', 'Sdk'),
    path.join(os.homedir(), '.android', 'sdk'),
    DEFAULT_SDK_DIR,
  ].filter(Boolean);
  for (const dir of candidates) {
    if (fs.existsSync(path.join(dir, 'emulator', process.platform === 'win32' ? 'emulator.exe' : 'emulator'))) return dir;
  }
  return null;
}

function sdkManagerBin(sdkDir) {
  return path.join(sdkDir, 'cmdline-tools', 'latest', 'bin', process.platform === 'win32' ? 'sdkmanager.bat' : 'sdkmanager');
}
function avdManagerBin(sdkDir) {
  return path.join(sdkDir, 'cmdline-tools', 'latest', 'bin', process.platform === 'win32' ? 'avdmanager.bat' : 'avdmanager');
}
function emulatorBin(sdkDir) {
  return path.join(sdkDir, 'emulator', process.platform === 'win32' ? 'emulator.exe' : 'emulator');
}
function adbBin(sdkDir) {
  return path.join(sdkDir, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb');
}

// ─── System image selection ──────────────────────────────────────────────────

function pickSystemImage(sdkDir) {
  const siRoot = path.join(sdkDir, 'system-images');
  if (!fs.existsSync(siRoot)) return null;

  const hostArm = os.arch() === 'arm64' || os.arch() === 'arm';
  const preferred = hostArm ? 'arm64-v8a' : 'x86_64';
  const fallback  = hostArm ? 'x86_64' : 'arm64-v8a';

  const images = [];
  for (const api of fs.readdirSync(siRoot)) {
    const apiPath = path.join(siRoot, api);
    if (!fs.statSync(apiPath).isDirectory()) continue;
    for (const tag of fs.readdirSync(apiPath)) {
      const tagPath = path.join(apiPath, tag);
      if (!fs.statSync(tagPath).isDirectory()) continue;
      for (const abi of fs.readdirSync(tagPath)) {
        images.push({ api, tag, abi, key: `system-images;${api};${tag};${abi}` });
      }
    }
  }

  images.sort((a, b) => {
    const score = img => {
      let s = 0;
      if (img.abi === preferred) s += 100;
      else if (img.abi === fallback) s += 10;
      if (img.tag === 'google_apis') s += 5;
      else if (img.tag === 'google_apis_playstore') s += 3;
      s += parseInt(img.api.replace('android-', '') || '0', 10);
      return s;
    };
    return score(b) - score(a);
  });
  return images[0]?.key || null;
}

function defaultSystemImage() {
  const abi = (os.arch() === 'arm64' || os.arch() === 'arm') ? 'arm64-v8a' : 'x86_64';
  return `system-images;android-36;google_apis;${abi}`;
}

// ─── SDK setup ───────────────────────────────────────────────────────────────

function abortError(signal, message = 'Android operation was aborted.') {
  if (signal?.reason instanceof Error) return signal.reason;
  const error = new Error(String(signal?.reason || message));
  error.name = 'AbortError';
  error.code = 'ABORT_ERR';
  return error;
}

function delay(ms, signal = null) {
  if (signal?.aborted) return Promise.reject(abortError(signal));
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      clearTimeout(timer);
      reject(abortError(signal));
    };
    signal?.addEventListener('abort', onAbort, { once: true });
    if (signal?.aborted) onAbort();
  });
}

function waitForAbortable(promise, signal = null) {
  if (signal?.aborted) return Promise.reject(abortError(signal));
  if (!signal) return promise;
  return new Promise((resolve, reject) => {
    let settled = false;
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      signal.removeEventListener('abort', onAbort);
      callback(value);
    };
    const onAbort = () => finish(reject, abortError(signal));
    signal.addEventListener('abort', onAbort, { once: true });
    if (signal.aborted) onAbort();
    Promise.resolve(promise).then(
      (value) => finish(resolve, value),
      (error) => finish(reject, error),
    );
  });
}

async function ensureSdk(sdkDir, onProgress, options = {}) {
  if (fs.existsSync(sdkManagerBin(sdkDir))) return;
  const release = resolveCommandLineToolsRelease();

  fs.mkdirSync(sdkDir, { recursive: true });
  onProgress('Downloading Android SDK command-line tools (~182 MB)…');
  const downloadDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-android-sdk-'));
  const zip = path.join(downloadDir, 'cmdline-tools.zip');
  try {
    await downloadFile(release.url, zip, {
      expectedSha256: release.sha256,
      signal: options.signal,
    });
    await runProcess('unzip', ['-tq', zip], {
      timeoutMs: 120_000,
      maxOutputBytes: 1024 * 1024,
      signal: options.signal,
    });

    onProgress('Extracting…');
    const toolsDir = path.join(sdkDir, 'cmdline-tools');
    fs.mkdirSync(toolsDir, { recursive: true });
    await runProcess('unzip', ['-qo', zip, '-d', toolsDir], {
      timeoutMs: 120_000,
      maxOutputBytes: 1024 * 1024,
      signal: options.signal,
    });
  } finally {
    fs.rmSync(downloadDir, { recursive: true, force: true });
  }

  const toolsDir = path.join(sdkDir, 'cmdline-tools');
  const extracted = path.join(toolsDir, 'cmdline-tools');
  const latest = path.join(toolsDir, 'latest');
  if (fs.existsSync(extracted) && !fs.existsSync(latest)) fs.renameSync(extracted, latest);
  if (!fs.existsSync(sdkManagerBin(sdkDir))) throw new Error('sdkmanager not found after extraction');
}

async function ensurePackages(sdkDir, onProgress, options = {}) {
  const env = { ...process.env, ANDROID_SDK_ROOT: sdkDir, ANDROID_HOME: sdkDir };
  const sdkman = sdkManagerBin(sdkDir);

  onProgress('Accepting Android SDK licenses…');
  await runProcess(sdkman, ['--licenses', `--sdk_root=${sdkDir}`], {
    input: 'y\n'.repeat(20),
    env,
    timeoutMs: 5 * 60 * 1000,
    maxOutputBytes: 8 * 1024 * 1024,
    signal: options.signal,
  });

  const existingImage = pickSystemImage(sdkDir);
  const packages = ['platform-tools', 'emulator'];
  if (!existingImage) packages.push(defaultSystemImage());
  onProgress(`Installing ${packages.join(', ')} (first run only)…`);
  await runProcess(sdkman, [...packages, `--sdk_root=${sdkDir}`], {
    env,
    timeoutMs: 20 * 60 * 1000,
    maxOutputBytes: 32 * 1024 * 1024,
    signal: options.signal,
  });
}

async function ensureSdkProvisioned(sdkDir, onProgress, options = {}) {
  const key = path.resolve(sdkDir);
  let entry = SDK_PROVISIONING.get(key);
  if (entry?.controller.signal.aborted && !entry.settled) {
    await entry.promise.catch(() => {});
    entry = null;
  }
  if (!entry) {
    const controller = new AbortController();
    entry = {
      controller,
      promise: null,
      settled: false,
      waiters: 0,
    };
    entry.promise = (async () => {
      await ensureSdk(sdkDir, onProgress, { signal: controller.signal });
      const hasAdb = fs.existsSync(adbBin(sdkDir));
      const hasEmulator = fs.existsSync(emulatorBin(sdkDir));
      const hasImage = Boolean(pickSystemImage(sdkDir));
      if (!hasAdb || !hasEmulator || !hasImage) {
        await ensurePackages(sdkDir, onProgress, { signal: controller.signal });
      }
    })();
    SDK_PROVISIONING.set(key, entry);
    const settle = () => {
      entry.settled = true;
      if (SDK_PROVISIONING.get(key) === entry) SDK_PROVISIONING.delete(key);
    };
    entry.promise.then(settle, settle);
  }

  entry.waiters += 1;
  try {
    await waitForAbortable(entry.promise, options.signal);
  } finally {
    entry.waiters -= 1;
    if (entry.waiters === 0 && !entry.settled && !entry.controller.signal.aborted) {
      entry.controller.abort(new Error('Android SDK provisioning no longer has an active startup request.'));
    }
  }
}

async function ensureEmulatorRegistered(sdkDir, options = {}) {
  const packageXml = path.join(sdkDir, 'emulator', 'package.xml');
  if (fs.existsSync(packageXml) || !fs.existsSync(emulatorBin(sdkDir))) return;
  const env = { ...process.env, ANDROID_SDK_ROOT: sdkDir, ANDROID_HOME: sdkDir };
  await runProcess(sdkManagerBin(sdkDir), ['emulator', `--sdk_root=${sdkDir}`], {
    env,
    input: 'y\n'.repeat(5),
    timeoutMs: 5 * 60 * 1000,
    maxOutputBytes: 16 * 1024 * 1024,
    signal: options.signal,
  });
}

async function ensureAvd(sdkDir, avdName, avdHome, onProgress, options = {}) {
  const avdDir = path.join(avdHome, `${avdName}.avd`);
  if (fs.existsSync(avdDir)) return;

  await ensureEmulatorRegistered(sdkDir, options);
  const img = pickSystemImage(sdkDir) || defaultSystemImage();
  onProgress(`Creating AVD "${avdName}" using ${img}…`);

  fs.mkdirSync(avdHome, { recursive: true });
  const env = {
    ...process.env,
    ANDROID_AVD_HOME: avdHome,
    ANDROID_SDK_ROOT: sdkDir,
    ANDROID_HOME: sdkDir,
  };
  await runProcess(avdManagerBin(sdkDir), ['create', 'avd', '-n', avdName, '-k', img, '--device', 'pixel', '--force'], {
    env,
    input: '\n',
    timeoutMs: 120_000,
    maxOutputBytes: 4 * 1024 * 1024,
    signal: options.signal,
  });

  // Patch config: sparse QCOW2 (no pre-allocation), smaller cache partition.
  const cfgPath = path.join(avdDir, 'config.ini');
  if (fs.existsSync(cfgPath)) {
    let cfg = fs.readFileSync(cfgPath, 'utf8');
    cfg = cfg.replace(/disk\.dataPartition\.size\s*=\s*\S+/, `disk.dataPartition.size = ${2 * 1024 * 1024 * 1024}`);
    cfg = cfg.replace(/disk\.cachePartition\.size\s*=\s*\S+/, `disk.cachePartition.size = ${32 * 1024 * 1024}`);
    cfg = cfg.replace(/userdata\.useQcow2\s*=\s*\S+/, 'userdata.useQcow2 = yes');
    if (!/userdata\.useQcow2/.test(cfg)) cfg += '\nuserdata.useQcow2 = yes\n';
    fs.writeFileSync(cfgPath, cfg);
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function hashCode(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) h = (Math.imul(31, h) + str.charCodeAt(i)) | 0;
  return h;
}

// Escape a string for safe use inside single-quoted Android shell (`mksh`) commands.
function shellEscape(str) {
  return String(str).replace(/'/g, "'\\''");
}

// Validate an Android package name or intent action (alphanumeric + dots + underscores).
function isSafeIdentifier(str) {
  return /^[\w.]+$/.test(String(str || ''));
}

function isSafeActivity(str) {
  return /^[\w.$]+$/.test(String(str || ''));
}

function isSafeComponent(str) {
  return /^[\w.$]+\/[\w.$]+$/.test(String(str || ''));
}

function isSafeMimeType(str) {
  return /^[\w.+-]+\/[\w.+*-]+$/.test(String(str || ''));
}

function normalizeUserId(value) {
  const userId = String(value || 'default').trim();
  if (!/^[a-zA-Z0-9_-]{1,64}$/.test(userId)) {
    throw new Error('Android user ID contains unsupported characters.');
  }
  return userId;
}

function hasUiSelector(value = {}) {
  return ['text', 'resourceId', 'description', 'className', 'packageName']
    .some((key) => String(value[key] || '').trim())
    || value.clickable === true;
}

function requireCoordinate(value, label) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) {
    throw new Error(`${label} must be a non-negative number.`);
  }
  return Math.round(number);
}

// ─── AndroidController ───────────────────────────────────────────────────────

class AndroidController {
  constructor(options = {}) {
    this.userId   = normalizeUserId(options.userId);
    this.avdName  = `neoagent_${this.userId}`;
    // Deterministic ADB console port per user, within documented range 5554–5682 (even only).
    this.adbPort  = ADB_PORT_BASE + ((hashCode(this.userId) >>> 0) % ADB_PORT_SLOTS) * 2;
    this.adbSerial = `emulator-${this.adbPort}`;
    this.sdkDir   = options.sdkDir || findExistingSdk() || DEFAULT_SDK_DIR;
    this.avdHome  = options.avdHome || DEFAULT_AVD_DIR;
    this.artifactStore = options.artifactStore || null;
    this.startPromise  = null;
    this.startAbortController = null;
    this.emulatorProcess = null;
  }

  // ── Status ────────────────────────────────────────────────────────────────

  getStatusSync() { return readState(this.userId); }

  async getStatus(options = {}) {
    const state = readState(this.userId);
    const base = {
      bootstrapped:  state.bootstrapped  || false,
      starting:      state.starting      || false,
      startupPhase:  state.startupPhase  || null,
      lastStartError: state.lastStartError || null,
      adbSerial:     state.adbSerial     || null,
      devices:       [],
    };

    if (!state.adbSerial) return base;
    if (!this.#isPidAlive(state.pid)) return { ...base, bootstrapped: false };

    try {
      const result = await runProcess(
        adbBin(this.sdkDir),
        ['-s', state.adbSerial, 'shell', 'getprop', 'sys.boot_completed'],
        { timeoutMs: 5000, maxOutputBytes: 64 * 1024, signal: options.signal },
      );
      const booted = result.stdout.trim() === '1';
      return {
        ...base,
        bootstrapped: booted,
        devices: booted ? [{ serial: state.adbSerial, status: 'device', emulator: true }] : [],
      };
    } catch (error) {
      if (options.signal?.aborted) throw error;
      return base;
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  async requestStartEmulator(options = {}) {
    console.log(`[Android] requestStartEmulator for user ${this.userId}`);
    const state = readState(this.userId);
    if (state.adbSerial && this.#isPidAlive(state.pid)) {
      console.log(`[Android] Emulator already running (pid=${state.pid})`);
      const status = await this.getStatus(options);
      return {
        success: true,
        pending: !status.bootstrapped,
        bootstrapped: status.bootstrapped,
        adbSerial: state.adbSerial,
      };
    }
    if (!this.startPromise) {
      writeState(this.userId, { starting: true, startupPhase: 'Initializing', lastStartError: null });
      const startAbortController = new AbortController();
      this.startAbortController = startAbortController;
      const externalSignal = options.signal || null;
      const forwardAbort = () => startAbortController.abort(externalSignal.reason);
      if (externalSignal?.aborted) forwardAbort();
      else externalSignal?.addEventListener('abort', forwardAbort, { once: true });
      let trackedStart;
      trackedStart = this.#setup({
        ...options,
        signal: startAbortController.signal,
      }).finally(() => {
        externalSignal?.removeEventListener('abort', forwardAbort);
        if (this.startAbortController === startAbortController) {
          this.startAbortController = null;
        }
        if (this.startPromise === trackedStart) this.startPromise = null;
      });
      this.startPromise = trackedStart;
      trackedStart.catch(() => {});
    }
    const s = readState(this.userId);
    return { success: true, pending: true, bootstrapped: false, starting: true, startupPhase: s.startupPhase };
  }

  async startEmulator(options = {}) {
    const start = await this.requestStartEmulator(options);
    if (start.bootstrapped) return start;
    const timeoutMs = clampNumber(options.timeoutMs, 240_000, 1000, 10 * 60 * 1000);
    const adbSerial = await this.waitForDevice({ timeoutMs, signal: options.signal });
    return { success: true, pending: false, bootstrapped: true, adbSerial };
  }

  async stopEmulator(options = {}) {
    this.startAbortController?.abort(new Error('Android emulator startup was stopped.'));
    const starting = this.startPromise;
    if (starting) await starting.catch(() => {});
    const state = readState(this.userId);
    let adbStopError = null;
    if (state.adbSerial) {
      try {
        await runProcess(
          adbBin(this.sdkDir),
          ['-s', state.adbSerial, 'emu', 'kill'],
          { timeoutMs: 5000, maxOutputBytes: 64 * 1024, signal: options.signal },
        );
      } catch (error) {
        adbStopError = error;
      }
    }
    await this.#terminateOwnedEmulatorProcess();
    if (state.pid) await this.#waitForPidExit(state.pid, 5000);
    if (state.pid && this.#isPidAlive(state.pid)) {
      if (options.signal?.aborted) throw abortError(options.signal);
      if (adbStopError) throw adbStopError;
      throw new Error('Android emulator did not exit after the stop request.');
    }
    RESERVED_ADB_PORTS.delete(Number(String(state.adbSerial || '').replace(/^emulator-/, '')));
    RESERVED_ADB_PORTS.delete(this.adbPort);
    writeState(this.userId, {
      bootstrapped: false,
      starting: false,
      pid: null,
      adbSerial: null,
      startupPhase: null,
      lastStartError: null,
    });
    if (options.signal?.aborted) throw abortError(options.signal);
    console.log('[Android] Emulator stopped');
    return { success: true };
  }

  async close() { await this.stopEmulator().catch(() => {}); }

  async waitForDevice(options = {}) {
    const timeoutMs = clampNumber(options.timeoutMs, 600_000, 1000, 10 * 60 * 1000);
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      if (options.signal?.aborted) {
        const error = new Error('Waiting for the Android emulator was aborted.');
        error.name = 'AbortError';
        error.code = 'ABORT_ERR';
        throw error;
      }
      const s = await this.getStatus(options);
      if (s.bootstrapped) return this.adbSerial;
      if (!s.starting && s.lastStartError) throw new Error(s.lastStartError);
      await delay(2000, options.signal);
    }
    throw new Error('Android emulator did not become ready in time');
  }

  async listDevices(options = {}) {
    const s = await this.getStatus(options);
    return s.bootstrapped ? [{ serial: this.adbSerial, status: 'device', emulator: true }] : [];
  }

  async ensureBootstrapped(options = {}) {
    const status = await this.getStatus(options);
    if (!status.bootstrapped) await this.startEmulator(options);
    return this.adbSerial;
  }

  // ── Shell / ADB ───────────────────────────────────────────────────────────

  async shell(commandOrObj) {
    const command = typeof commandOrObj === 'string' ? commandOrObj : String(commandOrObj?.command || '');
    if (!command.trim()) throw new Error('Android shell command is required.');
    const serial = this.#requireSerial();
    const adb = adbBin(this.sdkDir);
    const options = typeof commandOrObj === 'object' && commandOrObj ? commandOrObj : {};
    const result = await runProcess(adb, ['-s', serial, 'shell', command], {
      timeoutMs: options.timeoutMs,
      maxOutputBytes: 4 * 1024 * 1024,
      signal: options.signal,
    });
    if (options.screenshot === true) {
      return { output: result.stdout, ...await this.screenshot({ signal: options.signal }) };
    }
    return result.stdout;
  }

  async adb(...args) {
    const state = readState(this.userId);
    const adb = adbBin(this.sdkDir);
    const result = await runProcess(
      adb,
      ['-s', state.adbSerial || this.adbSerial, ...args],
      { timeoutMs: 60_000, maxOutputBytes: 16 * 1024 * 1024 },
    );
    return result.stdout;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  async screenshot(options = {}) {
    const r = await this.capturePng(options);
    if (!r?.length) throw new Error('screencap returned no data');
    return { screenshotPath: await this.#saveArtifact(r, options) };
  }

  async capturePng(options = {}) {
    const serial = this.#requireSerial();
    return this.#adbCaptureAsync(serial, ['exec-out', 'screencap', '-p'], options);
  }

  async observe({ includeNodes = true, signal } = {}) {
    const screenshot = await this.screenshot({ signal });
    const dump = await this.dumpUi({ includeNodes, signal });
    return {
      ...screenshot,
      uiDumpPath: dump.devicePath,
      nodeCount: dump.nodeCount,
      ...(includeNodes === false ? {} : { nodes: dump.nodes }),
    };
  }

  async findUiNode(selector = {}) {
    if (!hasUiSelector(selector)) {
      throw new Error('Provide x and y coordinates or a UI selector.');
    }
    const dump = await this.dumpUi({ includeNodes: true, signal: selector.signal });
    const node = findBestNode(dump.nodes, selector);
    if (!node) {
      throw new Error(`No Android UI element matched ${JSON.stringify(selector)}.`);
    }
    return node;
  }

  async resolvePoint(options = {}) {
    const hasX = Number.isFinite(Number(options.x));
    const hasY = Number.isFinite(Number(options.y));
    if (hasX || hasY) {
      if (!hasX || !hasY) throw new Error('Both x and y coordinates are required.');
      return {
        x: requireCoordinate(options.x, 'x'),
        y: requireCoordinate(options.y, 'y'),
        node: null,
      };
    }
    const node = await this.findUiNode(options);
    if (node.bounds.width <= 0 || node.bounds.height <= 0) {
      throw new Error('The matched Android UI element has no tappable bounds.');
    }
    return { x: node.bounds.centerX, y: node.bounds.centerY, node };
  }

  async tap(options = {}) {
    const target = await this.resolvePoint(options);
    await this.shell({ command: `input tap ${target.x} ${target.y}`, signal: options.signal });
    return {
      success: true,
      target: target.node ? summarizeNode(target.node) : { x: target.x, y: target.y },
      ...await this.screenshot({ signal: options.signal }),
    };
  }

  async longPress(options = {}) {
    const target = await this.resolvePoint(options);
    const durationMs = clampNumber(options.durationMs, 650, 100, 30_000);
    await this.shell({
      command: `input swipe ${target.x} ${target.y} ${target.x} ${target.y} ${durationMs}`,
      signal: options.signal,
    });
    return {
      success: true,
      target: target.node ? summarizeNode(target.node) : { x: target.x, y: target.y },
    };
  }

  async swipe({ x1, y1, x2, y2, durationMs = 300, signal } = {}) {
    const points = {
      x1: requireCoordinate(x1, 'x1'),
      y1: requireCoordinate(y1, 'y1'),
      x2: requireCoordinate(x2, 'x2'),
      y2: requireCoordinate(y2, 'y2'),
    };
    const duration = clampNumber(durationMs, 300, 50, 30_000);
    await this.shell({
      command: `input swipe ${points.x1} ${points.y1} ${points.x2} ${points.y2} ${duration}`,
      signal,
    });
    return { success: true, ...await this.screenshot({ signal }) };
  }

  async type({ text, textSelector, resourceId, description, className, clear = false, pressEnter, signal } = {}) {
    if (text == null) throw new Error('Text is required.');
    if (String(text).length > MAX_ANDROID_TEXT_CHARS) {
      throw new Error(`Text exceeds the ${MAX_ANDROID_TEXT_CHARS}-character limit.`);
    }
    const selector = {
      text: textSelector,
      resourceId,
      description,
      className,
      signal,
    };
    let target = null;
    if (hasUiSelector(selector)) {
      target = await this.resolvePoint(selector);
      await this.shell({ command: `input tap ${target.x} ${target.y}`, signal });
    }
    if (clear === true) {
      await this.shell({
        command: 'input keyevent KEYCODE_MOVE_END; for i in $(seq 1 200); do input keyevent KEYCODE_DEL; done',
        signal,
      });
    }
    // ADB input text encoding: %% = literal %, %s = space.
    const encoded = String(text).replace(/%/g, '%%').replace(/ /g, '%s');
    if (encoded) await this.shell({ command: `input text '${shellEscape(encoded)}'`, signal });
    if (pressEnter) await this.shell({ command: 'input keyevent KEYCODE_ENTER', signal });
    return {
      success: true,
      ...(target?.node ? { target: summarizeNode(target.node) } : {}),
    };
  }

  async pressKey(keyOrObj) {
    const raw = typeof keyOrObj === 'string' ? keyOrObj : (keyOrObj?.key || '');
    const signal = typeof keyOrObj === 'object' ? keyOrObj?.signal : null;
    const KEY_MAP = {
      back: 'KEYCODE_BACK', home: 'KEYCODE_HOME', app_switch: 'KEYCODE_APP_SWITCH',
      enter: 'KEYCODE_ENTER', del: 'KEYCODE_DEL', escape: 'KEYCODE_ESCAPE',
      menu: 'KEYCODE_MENU', power: 'KEYCODE_POWER',
      volume_up: 'KEYCODE_VOLUME_UP', volume_down: 'KEYCODE_VOLUME_DOWN',
    };
    const normalized = String(raw || '').trim();
    const keycode = KEY_MAP[normalized.toLowerCase()]
      || (/^\d+$/.test(normalized) ? normalized : normalized.toUpperCase());
    if (!/^\d+$/.test(keycode) && !/^KEYCODE_[A-Z0-9_]+$/.test(keycode)) {
      throw new Error(`Unsupported Android key: ${normalized || '(empty)'}`);
    }
    await this.shell({ command: `input keyevent ${keycode}`, signal });
    return { success: true };
  }

  async dumpUi({ includeNodes = true, signal } = {}) {
    this.#requireSerial();
    const devicePath = '/sdcard/window_dump.xml';
    await this.shell({ command: 'uiautomator dump /sdcard/window_dump.xml', signal });
    const xml = await this.shell({ command: `cat '${devicePath}'`, timeoutMs: 10_000, signal });
    const nodes = parseUiDump(xml);
    return {
      xml,
      devicePath,
      nodeCount: nodes.length,
      ...(includeNodes === false ? {} : { nodes: nodes.slice(0, 200).map(summarizeNode) }),
    };
  }

  async listApps({ includeSystem = false, signal } = {}) {
    const out = await this.shell({
      command: includeSystem ? 'pm list packages' : 'pm list packages -3',
      signal,
    });
    const packages = out.trim().split('\n').filter(Boolean).map(l => l.replace('package:', '').trim());
    return { packages };
  }

  async openApp({ packageName, activity, signal } = {}) {
    if (!isSafeIdentifier(packageName)) throw new Error('Invalid package name');
    if (activity) {
      if (!isSafeActivity(activity)) throw new Error('Invalid Android activity name');
      await this.shell({ command: `am start -n '${shellEscape(`${packageName}/${activity}`)}'`, signal });
    } else {
      await this.shell({
        command: `monkey -p '${shellEscape(packageName)}' -c android.intent.category.LAUNCHER 1`,
        signal,
      });
    }
    await delay(1500, signal);
    return this.screenshot({ signal });
  }

  async openIntent({ action, dataUri, data, url, uri, packageName, component, mimeType, extras = {}, signal } = {}) {
    const safeAction = isSafeIdentifier(action) ? action : 'android.intent.action.VIEW';
    let cmd = `am start -a '${shellEscape(safeAction)}'`;
    const resolvedDataUri = dataUri || data || url || uri;
    if (resolvedDataUri) {
      if (String(resolvedDataUri).length > MAX_ANDROID_TEXT_CHARS) {
        throw new Error('Android intent URI is too long.');
      }
      const validation = await validateAndroidIntentUrl(String(resolvedDataUri), { signal });
      if (!validation.allowed) throw new Error('This Android intent URI is not permitted.');
      cmd += ` -d '${shellEscape(resolvedDataUri)}'`;
    }
    if (packageName) {
      if (!isSafeIdentifier(packageName)) throw new Error('Invalid Android package name');
      cmd += ` -p '${shellEscape(packageName)}'`;
    }
    if (component) {
      if (!isSafeComponent(component)) throw new Error('Invalid Android component name');
      cmd += ` -n '${shellEscape(component)}'`;
    }
    if (mimeType) {
      if (!isSafeMimeType(mimeType)) throw new Error('Invalid Android MIME type');
      cmd += ` -t '${shellEscape(mimeType)}'`;
    }
    const extraEntries = Object.entries(extras || {});
    if (extraEntries.length > MAX_ANDROID_INTENT_EXTRAS) {
      throw new Error(`Android intent extras exceed the ${MAX_ANDROID_INTENT_EXTRAS}-item limit.`);
    }
    for (const [k, v] of extraEntries) {
      if (!isSafeIdentifier(k)) throw new Error(`Invalid Android intent extra name: ${k}`);
      if (String(v).length > MAX_ANDROID_TEXT_CHARS) {
        throw new Error(`Android intent extra is too long: ${k}`);
      }
      cmd += ` --es '${shellEscape(k)}' '${shellEscape(v)}'`;
    }
    await this.shell({ command: cmd, signal });
    await delay(2000, signal);
    return this.screenshot({ signal });
  }

  async waitFor(options = {}) {
    if (!hasUiSelector(options)) {
      throw new Error('android_wait_for requires at least one UI selector.');
    }
    const timeoutMs = clampNumber(options.timeoutMs ?? options.timeout, 20_000, 100, 120_000);
    const intervalMs = clampNumber(options.intervalMs, 1500, 100, 5000);
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      if (options.signal?.aborted) {
        throw abortError(options.signal, 'Waiting for the Android UI was aborted.');
      }
      const dump = await this.dumpUi({ includeNodes: true, signal: options.signal });
      const node = findBestNode(dump.nodes, options);
      if (node) {
        return {
          found: true,
          ready: true,
          node: summarizeNode(node),
          ...(options.screenshot === false ? {} : await this.screenshot({ signal: options.signal })),
        };
      }
      await delay(intervalMs, options.signal);
    }
    return { found: false, ready: false, timeoutMs };
  }

  async installApk({ apkPath, signal } = {}) {
    if (!apkPath) throw new Error('apkPath required');
    const resolvedPath = fs.realpathSync(apkPath);
    const packageStat = fs.statSync(resolvedPath);
    if (!packageStat.isFile()) throw new Error('Android package path must be a file.');
    if (packageStat.size > MAX_ANDROID_PACKAGE_BYTES) {
      throw new Error('Android package exceeds the 1GB installation limit.');
    }
    const extension = path.extname(resolvedPath).toLowerCase();
    if (extension !== '.apk' && extension !== '.apks') {
      throw new Error('Android package must be an .apk or universal .apks bundle.');
    }
    const serial = this.#requireSerial();
    const adb = adbBin(this.sdkDir);
    let installPath = resolvedPath;
    let extractionDir = null;
    try {
      if (extension === '.apks') {
        extractionDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-apks-'));
        const listing = await runProcess('unzip', ['-l', resolvedPath, 'universal.apk'], {
          timeoutMs: 30_000,
          maxOutputBytes: 1024 * 1024,
          signal,
        });
        const universalSize = String(listing.stdout)
          .split(/\r?\n/)
          .map((line) => line.trim().match(/^(\d+)\s+.*\suniversal\.apk$/i))
          .find(Boolean);
        if (!universalSize) {
          throw new Error('The .apks bundle does not contain universal.apk. Export it with bundletool --mode=universal.');
        }
        if (Number(universalSize[1]) > MAX_ANDROID_PACKAGE_BYTES) {
          throw new Error('The universal APK exceeds the 1GB installation limit.');
        }
        await runProcess('unzip', ['-jo', resolvedPath, 'universal.apk', '-d', extractionDir], {
          timeoutMs: 120_000,
          maxOutputBytes: 1024 * 1024,
          signal,
        });
        installPath = path.join(extractionDir, 'universal.apk');
        if (!fs.existsSync(installPath)) {
          throw new Error('The .apks bundle does not contain universal.apk. Export it with bundletool --mode=universal.');
        }
      }
      const result = await runProcess(adb, ['-s', serial, 'install', '-r', installPath], {
        timeoutMs: 5 * 60 * 1000,
        maxOutputBytes: 4 * 1024 * 1024,
        signal,
      });
      if (!String(result.stdout).includes('Success')) {
        throw new Error(String(result.stderr || result.stdout || 'adb install did not report success'));
      }
      return { success: true, output: result.stdout };
    } finally {
      if (extractionDir) fs.rmSync(extractionDir, { recursive: true, force: true });
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  #requireSerial() {
    const state = readState(this.userId);
    if (!state.adbSerial) throw new Error('No emulator running');
    return state.adbSerial;
  }

  #isPidAlive(pid) {
    if (!pid || !Number.isInteger(Number(pid))) return false;
    try { process.kill(Number(pid), 0); return true; } catch { return false; }
  }

  async #adbCaptureAsync(serial, args, options = {}) {
    const result = await runProcess(adbBin(this.sdkDir), ['-s', serial, ...args], {
      timeoutMs: 15_000,
      maxOutputBytes: 20 * 1024 * 1024,
      encoding: null,
      signal: options.signal,
    });
    if (!result.stdout.length) throw new Error('ADB capture returned no data.');
    return result.stdout;
  }

  async #saveArtifact(data, options = {}) {
    if (!data || !this.artifactStore) return null;
    const image = validateImageBuffer(data, { allowedTypes: ['image/png'] });
    const artifact = await this.artifactStore.createBufferArtifact(this.userId, {
      kind: 'android-screenshot',
      backend: 'android-emulator',
      extension: image.extension,
      contentType: image.contentType,
      filenameBase: 'android-emulator-screenshot',
      content: image.buffer,
      signal: options.signal,
    });
    return artifact.url;
  }

  // ── Setup pipeline ────────────────────────────────────────────────────────

  async #resolveAdbPort() {
    const base = (hashCode(this.userId) >>> 0) % ADB_PORT_SLOTS;
    for (let i = 0; i < ADB_PORT_SLOTS; i++) {
      const slot = (base + i) % ADB_PORT_SLOTS;
      const port = ADB_PORT_BASE + slot * 2;
      if (RESERVED_ADB_PORTS.has(port)) continue;
      const free = await this.#isPortPairFree(port);
      if (free) {
        RESERVED_ADB_PORTS.add(port);
        this.adbPort   = port;
        this.adbSerial = `emulator-${port}`;
        return;
      }
    }
    throw new Error(`No free ADB port pair in range ${ADB_PORT_BASE}–${ADB_PORT_BASE + (ADB_PORT_SLOTS * 2) - 1}`);
  }

  async #isPortPairFree(consolePort) {
    const servers = [];
    const listen = (port) => new Promise((resolve) => {
      const server = net.createServer();
      server.unref();
      server.once('error', () => resolve(false));
      server.listen(port, '127.0.0.1', () => {
        servers.push(server);
        resolve(true);
      });
    });
    try {
      return await listen(consolePort) && await listen(consolePort + 1);
    } finally {
      await Promise.allSettled(servers.map((server) => new Promise((resolve) => server.close(resolve))));
    }
  }

  async #waitForPidExit(pid, timeoutMs) {
    const deadline = Date.now() + Math.max(0, Number(timeoutMs) || 0);
    while (this.#isPidAlive(pid) && Date.now() < deadline) {
      await delay(100);
    }
    return !this.#isPidAlive(pid);
  }

  async #terminateOwnedEmulatorProcess() {
    const proc = this.emulatorProcess;
    if (!proc) return;
    if (proc.exitCode == null && proc.signalCode == null) {
      try { proc.kill('SIGTERM'); } catch {}
      await this.#waitForPidExit(proc.pid, 3000);
    }
    if (proc.pid && this.#isPidAlive(proc.pid)) {
      try { proc.kill('SIGKILL'); } catch {}
      await this.#waitForPidExit(proc.pid, 2000);
    }
    if (this.emulatorProcess === proc) this.emulatorProcess = null;
  }

  async #setup(options = {}) {
    const progress = msg => {
      console.log(`[Android] ${msg}`);
      writeState(this.userId, { startupPhase: msg });
    };
    try {
      await this.#resolveAdbPort();
      const existing = findExistingSdk();
      if (existing) {
        this.sdkDir = existing;
        progress(`Found existing Android SDK at ${existing}`);
      } else {
        progress('Preparing Android SDK…');
      }
      await ensureSdkProvisioned(this.sdkDir, progress, options);
      await ensureAvd(this.sdkDir, this.avdName, this.avdHome, progress, options);
      await this.#startEmulatorProcess(progress, options);
    } catch (err) {
      console.error(`[Android] Setup failed: ${err.message}`);
      await this.#terminateOwnedEmulatorProcess();
      RESERVED_ADB_PORTS.delete(this.adbPort);
      writeState(this.userId, {
        bootstrapped: false,
        starting: false,
        startupPhase: 'Failed',
        lastStartError: err.message,
        pid: null,
        adbSerial: null,
      });
      throw err;
    }
  }

  async #startEmulatorProcess(progress, options = {}) {
    progress('Starting Android emulator…');
    const env = {
      ...process.env,
      ANDROID_AVD_HOME: this.avdHome,
      ANDROID_SDK_ROOT: this.sdkDir,
      ANDROID_HOME: this.sdkDir,
    };
    const emulatorArgs = [
      '-avd', this.avdName,
      '-no-audio', '-no-boot-anim',
      '-port', String(this.adbPort),
      '-partition-size', '800',
    ];
    if (options.headless !== false) emulatorArgs.splice(2, 0, '-no-window');
    const proc = spawn(emulatorBin(this.sdkDir), emulatorArgs, {
      env,
      detached: false,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    this.emulatorProcess = proc;

    let launchOutput = '';
    const collectLaunchOutput = (chunk) => {
      if (launchOutput.length >= 64 * 1024) return;
      launchOutput += chunk.toString().slice(0, (64 * 1024) - launchOutput.length);
    };
    proc.stdout.on('data', collectLaunchOutput);
    proc.stderr.on('data', collectLaunchOutput);
    writeState(this.userId, { pid: proc.pid || null, adbSerial: proc.pid ? this.adbSerial : null });

    let bootReady = false;
    let rejectProcessFailure;
    const processFailure = new Promise((_, reject) => { rejectProcessFailure = reject; });
    proc.once('error', (error) => rejectProcessFailure(error));
    proc.on('exit', (code, exitSignal) => {
      console.log(`[Android] Emulator exited with code ${code}`);
      this.emulatorProcess = null;
      RESERVED_ADB_PORTS.delete(this.adbPort);
      const current = readState(this.userId);
      if (Number(current.pid) === Number(proc.pid)) {
        writeState(this.userId, { bootstrapped: false, starting: false, pid: null, adbSerial: null });
      }
      if (!bootReady) {
        const details = launchOutput.trim().slice(-4000);
        rejectProcessFailure(new Error(
          `Android emulator exited before boot completed (${exitSignal || (code ?? 'unknown')}).${details ? ` ${details}` : ''}`,
        ));
      }
    });

    progress('Waiting for Android to boot (can take 2–5 min on first run)…');
    // Abort early if the emulator process dies, instead of polling until timeout.
    const cancelEmulator = () => {
      try { proc.kill('SIGTERM'); } catch {}
    };
    options.signal?.addEventListener('abort', cancelEmulator, { once: true });
    try {
      await Promise.race([
        this.#waitForBoot({
          isAlive: () => this.#isPidAlive(proc.pid),
          signal: options.signal,
        }),
        processFailure,
      ]);
      bootReady = true;
    } finally {
      options.signal?.removeEventListener('abort', cancelEmulator);
    }

    writeState(this.userId, { bootstrapped: true, starting: false, startupPhase: null, lastStartError: null });
    console.log(`[Android] Emulator ready on ${this.adbSerial}`);

    // Set wallpaper — best-effort, never fails the boot sequence.
    try {
      await this.#setWallpaper(this.adbSerial, { signal: options.signal });
    } catch (error) {
      if (options.signal?.aborted) throw error;
      console.warn(`[Android] Wallpaper not set: ${error.message}`);
    }
    if (!this.#isPidAlive(proc.pid)) {
      throw new Error('Android emulator exited immediately after boot completed.');
    }
  }

  async #waitForBoot({ timeoutMs = 10 * 60 * 1000, isAlive = () => true, signal } = {}) {
    const adb = adbBin(this.sdkDir);
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      if (!isAlive()) {
        throw new Error('Emulator process exited before Android finished booting (check virtualization/KVM support and the system image).');
      }
      try {
        const result = await runProcess(
          adb,
          ['-s', this.adbSerial, 'shell', 'getprop', 'sys.boot_completed'],
          { timeoutMs: 5000, maxOutputBytes: 64 * 1024, signal },
        );
        if (result.stdout.trim() === '1') return;
      } catch (error) {
        if (signal?.aborted) throw error;
      }
      await delay(3000, signal);
    }
    throw new Error('Emulator did not boot within timeout');
  }

  async #setWallpaper(serial, options = {}) {
    if (!fs.existsSync(LOGO_PATH)) return;
    const adb = adbBin(this.sdkDir);

    // Try to gain root access (works on AOSP default images).
    await runProcess(adb, ['-s', serial, 'root'], {
      timeoutMs: 5000,
      maxOutputBytes: 64 * 1024,
      signal: options.signal,
    }).catch(() => {});
    await delay(1500, options.signal);

    // Push PNG to device sdcard.
    await runProcess(adb, ['-s', serial, 'push', LOGO_PATH, '/sdcard/neoagent-wallpaper.png'], {
      timeoutMs: 15_000,
      maxOutputBytes: 1024 * 1024,
      signal: options.signal,
    });

    // cmd wallpaper set-stream reads PNG from stdin (Android 7.1+).
    const logoData = fs.readFileSync(LOGO_PATH);
    try {
      await runProcess(adb, ['-s', serial, 'shell', 'cmd', 'wallpaper', 'set-stream'], {
        input: logoData,
        timeoutMs: 15_000,
        maxOutputBytes: 1024 * 1024,
        signal: options.signal,
      });
      console.log('[Android] Wallpaper set');
      return;
    } catch {}

    // Fallback: direct file copy for rooted images (Android 11 AOSP).
    for (const command of [
      'cp /sdcard/neoagent-wallpaper.png /data/system/users/0/wallpaper',
      'chmod 600 /data/system/users/0/wallpaper',
      'chown system:system /data/system/users/0/wallpaper',
      'am broadcast -a android.intent.action.WALLPAPER_CHANGED',
    ]) {
      await runProcess(adb, ['-s', serial, 'shell', command], {
        timeoutMs: 5000,
        maxOutputBytes: 1024 * 1024,
        signal: options.signal,
      });
    }
    console.log('[Android] Wallpaper set via direct copy');
  }
}

module.exports = { AndroidController };
