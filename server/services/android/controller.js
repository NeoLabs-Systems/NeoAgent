'use strict';

const { spawn, spawnSync } = require('child_process');
const fs = require('fs');
const https = require('https');
const net = require('net');
const os = require('os');
const path = require('path');
const { DATA_DIR } = require('../../../runtime/paths');

// ─── Constants ───────────────────────────────────────────────────────────────

const DEFAULT_SDK_DIR = path.join(os.homedir(), '.neoagent', 'android-sdk');
const STATE_DIR = path.join(DATA_DIR, 'android', 'state');
const LOGO_PATH = path.join(__dirname, '..', '..', '..', 'flutter_app', 'assets', 'branding', 'app_icon_512.png');

// Even ports in 5554–5682 (documented ADB range). 65 slots for 65 concurrent users.
const ADB_PORT_BASE = 5554;
const ADB_PORT_SLOTS = 65;

const CMDLINE_TOOLS_VERSION = '14742923';
const CMDLINE_TOOLS_URLS = {
  darwin: `https://dl.google.com/android/repository/commandlinetools-mac-${CMDLINE_TOOLS_VERSION}_latest.zip`,
  linux:  `https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip`,
  win32:  `https://dl.google.com/android/repository/commandlinetools-win-${CMDLINE_TOOLS_VERSION}_latest.zip`,
};

fs.mkdirSync(STATE_DIR, { recursive: true });

// ─── State persistence ───────────────────────────────────────────────────────

function stateFile(userId) { return path.join(STATE_DIR, `${userId}.json`); }

function readState(userId) {
  try { return JSON.parse(fs.readFileSync(stateFile(userId), 'utf8')); }
  catch { return { userId, bootstrapped: false, starting: false, startupPhase: null, lastStartError: null, pid: null, adbSerial: null }; }
}

function writeState(userId, patch) {
  const current = readState(userId);
  fs.writeFileSync(stateFile(userId), JSON.stringify({ ...current, ...patch }, null, 2));
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
  return `system-images;android-33;google_apis;${abi}`;
}

// ─── SDK setup ───────────────────────────────────────────────────────────────

function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    const follow = u => https.get(u, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        file.close(); return follow(res.headers.location);
      }
      if (res.statusCode !== 200) { file.close(); return reject(new Error(`HTTP ${res.statusCode}`)); }
      res.pipe(file);
      file.on('finish', () => file.close(resolve));
    }).on('error', err => { file.close(); fs.unlink(dest, () => {}); reject(err); });
    follow(url);
  });
}

async function ensureSdk(sdkDir, onProgress) {
  if (fs.existsSync(sdkManagerBin(sdkDir))) return;
  const url = CMDLINE_TOOLS_URLS[process.platform];
  if (!url) throw new Error(`No cmdline-tools download for platform: ${process.platform}`);

  fs.mkdirSync(sdkDir, { recursive: true });
  onProgress('Downloading Android SDK command-line tools (~150 MB)…');
  const zip = path.join(os.tmpdir(), 'cmdline-tools.zip');
  await downloadFile(url, zip);

  onProgress('Extracting…');
  const toolsDir = path.join(sdkDir, 'cmdline-tools');
  fs.mkdirSync(toolsDir, { recursive: true });
  const unzip = spawnSync('unzip', ['-qo', zip, '-d', toolsDir]);
  fs.unlinkSync(zip);
  if (unzip.status !== 0) throw new Error('unzip failed');

  const extracted = path.join(toolsDir, 'cmdline-tools');
  const latest = path.join(toolsDir, 'latest');
  if (fs.existsSync(extracted) && !fs.existsSync(latest)) fs.renameSync(extracted, latest);
  if (!fs.existsSync(sdkManagerBin(sdkDir))) throw new Error('sdkmanager not found after extraction');
}

async function ensurePackages(sdkDir, onProgress) {
  const env = { ...process.env, ANDROID_SDK_ROOT: sdkDir, ANDROID_HOME: sdkDir };
  const sdkman = sdkManagerBin(sdkDir);

  onProgress('Accepting Android SDK licenses…');
  spawnSync(sdkman, ['--licenses', `--sdk_root=${sdkDir}`], { input: 'y\n'.repeat(20), encoding: 'utf8', env, stdio: ['pipe', 'pipe', 'pipe'] });

  const img = defaultSystemImage();
  onProgress(`Installing platform-tools, emulator, ${img} (~1–2 GB, first run only)…`);
  const r = spawnSync(sdkman, ['platform-tools', 'emulator', img, `--sdk_root=${sdkDir}`], {
    encoding: 'utf8', env, stdio: ['pipe', 'pipe', 'pipe'], timeout: 20 * 60 * 1000,
  });
  if (r.status !== 0) throw new Error(`sdkmanager failed: ${(r.stderr || r.stdout || '').slice(0, 500)}`);
}

function ensureEmulatorRegistered(sdkDir) {
  const packageXml = path.join(sdkDir, 'emulator', 'package.xml');
  if (fs.existsSync(packageXml) || !fs.existsSync(emulatorBin(sdkDir))) return;
  const env = { ...process.env, ANDROID_SDK_ROOT: sdkDir, ANDROID_HOME: sdkDir };
  spawnSync(sdkManagerBin(sdkDir), ['emulator', `--sdk_root=${sdkDir}`], {
    encoding: 'utf8', env, input: 'y\n'.repeat(5), stdio: ['pipe', 'pipe', 'pipe'], timeout: 5 * 60 * 1000,
  });
}

function ensureAvd(sdkDir, avdName, onProgress) {
  const avdDir = path.join(os.homedir(), '.android', 'avd', `${avdName}.avd`);
  if (fs.existsSync(avdDir)) return;

  ensureEmulatorRegistered(sdkDir);
  const img = pickSystemImage(sdkDir) || defaultSystemImage();
  onProgress(`Creating AVD "${avdName}" using ${img}…`);

  const env = { ...process.env, ANDROID_SDK_ROOT: sdkDir, ANDROID_HOME: sdkDir };
  const r = spawnSync(avdManagerBin(sdkDir), ['create', 'avd', '-n', avdName, '-k', img, '--device', 'pixel', '--force'], {
    encoding: 'utf8', env, stdio: ['pipe', 'pipe', 'pipe'], input: '\n',
  });
  if (r.status !== 0) throw new Error(`avdmanager failed: ${(r.stderr || r.stdout || '').slice(0, 500)}`);

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

// ─── AndroidController ───────────────────────────────────────────────────────

class AndroidController {
  constructor(options = {}) {
    this.userId   = String(options.userId || 'default').trim();
    this.avdName  = `neoagent_${this.userId}`;
    // Deterministic ADB console port per user, within documented range 5554–5682 (even only).
    this.adbPort  = ADB_PORT_BASE + ((hashCode(this.userId) >>> 0) % ADB_PORT_SLOTS) * 2;
    this.adbSerial = `emulator-${this.adbPort}`;
    this.sdkDir   = options.sdkDir || findExistingSdk() || DEFAULT_SDK_DIR;
    this.artifactStore = options.artifactStore || null;
    this.startPromise  = null;
  }

  // ── Status ────────────────────────────────────────────────────────────────

  getStatusSync() { return readState(this.userId); }

  async getStatus() {
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
      const r = spawnSync(adbBin(this.sdkDir), ['-s', state.adbSerial, 'shell', 'getprop', 'sys.boot_completed'],
        { encoding: 'utf8', timeout: 5000 });
      const booted = r.stdout?.trim() === '1';
      return {
        ...base,
        bootstrapped: booted,
        devices: booted ? [{ serial: state.adbSerial, status: 'device', emulator: true }] : [],
      };
    } catch {
      return base;
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  async requestStartEmulator() {
    console.log(`[Android] requestStartEmulator for user ${this.userId}`);
    const state = readState(this.userId);
    if (state.adbSerial && this.#isPidAlive(state.pid)) {
      console.log(`[Android] Emulator already running (pid=${state.pid})`);
      return { success: true, pending: false, adbSerial: state.adbSerial };
    }
    if (!this.startPromise) {
      writeState(this.userId, { starting: true, startupPhase: 'Initializing', lastStartError: null });
      this.startPromise = this.#setup().finally(() => { this.startPromise = null; });
      this.startPromise.catch(() => {});
    }
    const s = readState(this.userId);
    return { success: true, pending: true, bootstrapped: false, starting: true, startupPhase: s.startupPhase };
  }

  async stopEmulator() {
    const state = readState(this.userId);
    if (state.pid) { try { process.kill(Number(state.pid), 'SIGTERM'); } catch {} }
    writeState(this.userId, { bootstrapped: false, starting: false, pid: null, adbSerial: null, startupPhase: null });
    console.log('[Android] Emulator stopped');
  }

  async close() { await this.stopEmulator().catch(() => {}); }

  async waitForDevice(options = {}) {
    const deadline = Date.now() + (options.timeoutMs || 600000);
    while (Date.now() < deadline) {
      const s = await this.getStatus();
      if (s.bootstrapped) return this.adbSerial;
      await new Promise(r => setTimeout(r, 2000));
    }
    throw new Error('Android emulator did not become ready in time');
  }

  async listDevices() {
    const s = await this.getStatus();
    return s.bootstrapped ? [{ serial: this.adbSerial, status: 'device', emulator: true }] : [];
  }

  async ensureBootstrapped() {
    const s = readState(this.userId);
    if (!s.bootstrapped) await this.requestStartEmulator();
  }

  // ── Shell / ADB ───────────────────────────────────────────────────────────

  async shell(commandOrObj) {
    const command = typeof commandOrObj === 'string' ? commandOrObj : String(commandOrObj?.command || '');
    const serial = this.#requireSerial();
    const adb = adbBin(this.sdkDir);
    return new Promise((resolve, reject) => {
      const proc = spawn(adb, ['-s', serial, 'shell', command], { encoding: 'utf8' });
      let out = '', err = '';
      proc.stdout?.on('data', d => { out += d; });
      proc.stderr?.on('data', d => { err += d; });
      proc.on('close', code => code === 0 ? resolve(out) : reject(new Error(err || out || `exit ${code}`)));
      proc.on('error', reject);
    });
  }

  async adb(...args) {
    const state = readState(this.userId);
    const adb = adbBin(this.sdkDir);
    return new Promise((resolve, reject) => {
      const proc = spawn(adb, ['-s', state.adbSerial || this.adbSerial, ...args], { encoding: 'utf8' });
      let out = '', err = '';
      proc.stdout?.on('data', d => { out += d; });
      proc.stderr?.on('data', d => { err += d; });
      proc.on('close', code => code === 0 ? resolve(out) : reject(new Error(err || `adb ${args[0]} exit ${code}`)));
      proc.on('error', reject);
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  async screenshot(_opts = {}) {
    const serial = this.#requireSerial();
    const r = this.#adbCapture(serial, ['exec-out', 'screencap', '-p']);
    if (!r?.length) throw new Error('screencap returned no data');
    return { screenshotPath: this.#saveArtifact(r) };
  }

  async observe(_opts = {}) { return this.screenshot(); }

  async tap({ x, y } = {}) {
    await this.shell(`input tap ${Math.round(x)} ${Math.round(y)}`);
    return { success: true, screenshotPath: this.#saveArtifact(this.#adbCapture(this.#requireSerial(), ['exec-out', 'screencap', '-p'])) };
  }

  async longPress({ x, y, durationMs = 1000 } = {}) {
    await this.shell(`input swipe ${Math.round(x)} ${Math.round(y)} ${Math.round(x)} ${Math.round(y)} ${durationMs}`);
    return { success: true };
  }

  async swipe({ x1, y1, x2, y2, durationMs = 300 } = {}) {
    await this.shell(`input swipe ${Math.round(x1)} ${Math.round(y1)} ${Math.round(x2)} ${Math.round(y2)} ${durationMs}`);
    return { success: true, screenshotPath: this.#saveArtifact(this.#adbCapture(this.#requireSerial(), ['exec-out', 'screencap', '-p'])) };
  }

  async type({ text, pressEnter } = {}) {
    if (!text) return { success: true };
    // ADB input text encoding: %% = literal %, %s = space.
    const encoded = String(text).replace(/%/g, '%%').replace(/ /g, '%s');
    await this.shell(`input text '${shellEscape(encoded)}'`);
    if (pressEnter) await this.shell('input keyevent KEYCODE_ENTER');
    return { success: true };
  }

  async pressKey(keyOrObj) {
    const raw = typeof keyOrObj === 'string' ? keyOrObj : (keyOrObj?.key || '');
    const KEY_MAP = {
      back: 'KEYCODE_BACK', home: 'KEYCODE_HOME', app_switch: 'KEYCODE_APP_SWITCH',
      enter: 'KEYCODE_ENTER', del: 'KEYCODE_DEL', escape: 'KEYCODE_ESCAPE',
      menu: 'KEYCODE_MENU', power: 'KEYCODE_POWER',
      volume_up: 'KEYCODE_VOLUME_UP', volume_down: 'KEYCODE_VOLUME_DOWN',
    };
    const keycode = KEY_MAP[raw.toLowerCase()] || raw.toUpperCase();
    await this.shell(`input keyevent ${keycode}`);
    return { success: true };
  }

  async dumpUi(_opts = {}) {
    const serial = this.#requireSerial();
    await this.shell('uiautomator dump /sdcard/window_dump.xml');
    const r = spawnSync(adbBin(this.sdkDir), ['-s', serial, 'shell', 'cat', '/sdcard/window_dump.xml'], { encoding: 'utf8', timeout: 10000 });
    return { xml: r.stdout || '' };
  }

  async listApps({ includeSystem = false } = {}) {
    const out = await this.shell(includeSystem ? 'pm list packages' : 'pm list packages -3');
    const packages = out.trim().split('\n').filter(Boolean).map(l => l.replace('package:', '').trim());
    return { packages };
  }

  async openApp({ packageName } = {}) {
    if (!isSafeIdentifier(packageName)) throw new Error('Invalid package name');
    await this.shell(`monkey -p '${shellEscape(packageName)}' -c android.intent.category.LAUNCHER 1`);
    await new Promise(r => setTimeout(r, 1500));
    return this.screenshot();
  }

  async openIntent({ action, dataUri, extras = {} } = {}) {
    const safeAction = isSafeIdentifier(action) ? action : 'android.intent.action.VIEW';
    let cmd = `am start -a '${shellEscape(safeAction)}'`;
    if (dataUri) cmd += ` -d '${shellEscape(dataUri)}'`;
    for (const [k, v] of Object.entries(extras || {})) {
      if (isSafeIdentifier(k)) cmd += ` --es '${shellEscape(k)}' '${shellEscape(v)}'`;
    }
    await this.shell(cmd);
    await new Promise(r => setTimeout(r, 2000));
    return this.screenshot();
  }

  async waitFor({ timeout = 10000 } = {}) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      const s = await this.getStatus();
      if (s.bootstrapped) return { ready: true };
      await new Promise(r => setTimeout(r, 1000));
    }
    return { ready: false };
  }

  async installApk({ apkPath } = {}) {
    if (!apkPath) throw new Error('apkPath required');
    const serial = this.#requireSerial();
    const adb = adbBin(this.sdkDir);
    return new Promise((resolve, reject) => {
      const proc = spawn(adb, ['-s', serial, 'install', '-r', apkPath]);
      let out = '', err = '';
      proc.stdout?.on('data', d => { out += d; });
      proc.stderr?.on('data', d => { err += d; });
      proc.on('close', code => {
        if (code === 0 && out.includes('Success')) resolve({ success: true, output: out });
        else reject(new Error(err || out || `adb install exit ${code}`));
      });
      proc.on('error', reject);
    });
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

  #adbCapture(serial, args) {
    const r = spawnSync(adbBin(this.sdkDir), ['-s', serial, ...args], { maxBuffer: 20 * 1024 * 1024, timeout: 15000 });
    return (r.status === 0 && r.stdout?.length) ? r.stdout : null;
  }

  #saveArtifact(data) {
    if (!data || !this.artifactStore) return null;
    const alloc = this.artifactStore.allocateFile(this.userId, { kind: 'screenshot', extension: 'png', contentType: 'image/png' });
    fs.writeFileSync(alloc.storagePath, data);
    const fin = this.artifactStore.finalizeFile(alloc.artifactId, alloc.storagePath);
    return fin.url;
  }

  // ── Setup pipeline ────────────────────────────────────────────────────────

  async #resolveAdbPort() {
    const base = (hashCode(this.userId) >>> 0) % ADB_PORT_SLOTS;
    for (let i = 0; i < ADB_PORT_SLOTS; i++) {
      const slot = (base + i) % ADB_PORT_SLOTS;
      const port = ADB_PORT_BASE + slot * 2;
      const free = await new Promise(resolve => {
        const srv = net.createServer();
        srv.listen(port, '127.0.0.1', () => srv.close(() => resolve(true)));
        srv.on('error', () => resolve(false));
      });
      if (free) {
        this.adbPort   = port;
        this.adbSerial = `emulator-${port}`;
        return;
      }
    }
    throw new Error(`No free ADB port in range ${ADB_PORT_BASE}–${ADB_PORT_BASE + ADB_PORT_SLOTS * 2}`);
  }

  async #setup() {
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
        progress('Downloading Android SDK…');
        await ensureSdk(this.sdkDir, progress);
        await ensurePackages(this.sdkDir, progress);
      }
      ensureAvd(this.sdkDir, this.avdName, progress);
      await this.#startEmulatorProcess(progress);
    } catch (err) {
      console.error(`[Android] Setup failed: ${err.message}`);
      writeState(this.userId, { starting: false, startupPhase: 'Failed', lastStartError: err.message });
    }
  }

  async #startEmulatorProcess(progress) {
    progress('Starting Android emulator…');
    const env = { ...process.env, ANDROID_SDK_ROOT: this.sdkDir, ANDROID_HOME: this.sdkDir };
    const proc = spawn(emulatorBin(this.sdkDir), [
      '-avd', this.avdName,
      '-no-window', '-no-audio', '-no-boot-anim',
      '-port', String(this.adbPort),
      '-gpu', 'swiftshader_indirect',
      '-partition-size', '800',
    ], { env, detached: false, stdio: ['ignore', 'pipe', 'pipe'] });

    proc.stdout.on('data', d => console.log(`[Android/emu] ${d.toString().trimEnd()}`));
    proc.stderr.on('data', d => console.log(`[Android/emu] ${d.toString().trimEnd()}`));
    writeState(this.userId, { pid: proc.pid, adbSerial: this.adbSerial });

    proc.on('exit', code => {
      console.log(`[Android] Emulator exited with code ${code}`);
      writeState(this.userId, { bootstrapped: false, starting: false, pid: null });
    });

    progress('Waiting for Android to boot (can take 2–5 min on first run)…');
    await this.#waitForBoot();

    writeState(this.userId, { bootstrapped: true, starting: false, startupPhase: null, lastStartError: null });
    console.log(`[Android] Emulator ready on ${this.adbSerial}`);

    // Set wallpaper — best-effort, never fails the boot sequence.
    this.#setWallpaper(this.adbSerial).catch(err => {
      console.warn(`[Android] Wallpaper not set: ${err.message}`);
    });
  }

  async #waitForBoot(timeoutMs = 10 * 60 * 1000) {
    const adb = adbBin(this.sdkDir);
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      try {
        const r = spawnSync(adb, ['-s', this.adbSerial, 'shell', 'getprop', 'sys.boot_completed'], { encoding: 'utf8', timeout: 5000 });
        if (r.stdout?.trim() === '1') return;
      } catch {}
      await new Promise(r => setTimeout(r, 3000));
    }
    throw new Error('Emulator did not boot within timeout');
  }

  async #setWallpaper(serial) {
    if (!fs.existsSync(LOGO_PATH)) return;
    const adb = adbBin(this.sdkDir);

    // Try to gain root access (works on AOSP default images).
    spawnSync(adb, ['-s', serial, 'root'], { timeout: 5000 });
    await new Promise(r => setTimeout(r, 1500));

    // Push PNG to device sdcard.
    const push = spawnSync(adb, ['-s', serial, 'push', LOGO_PATH, '/sdcard/neoagent-wallpaper.png'], { timeout: 15000 });
    if (push.status !== 0) throw new Error('adb push logo failed');

    // cmd wallpaper set-stream reads PNG from stdin (Android 7.1+).
    const logoData = fs.readFileSync(LOGO_PATH);
    const r = spawnSync(adb, ['-s', serial, 'shell', 'cmd', 'wallpaper', 'set-stream'], {
      input: logoData, timeout: 15000,
    });
    if (r.status === 0) {
      console.log('[Android] Wallpaper set');
      return;
    }

    // Fallback: direct file copy for rooted images (Android 11 AOSP).
    spawnSync(adb, ['-s', serial, 'shell', 'cp /sdcard/neoagent-wallpaper.png /data/system/users/0/wallpaper'], { timeout: 5000 });
    spawnSync(adb, ['-s', serial, 'shell', 'chmod 600 /data/system/users/0/wallpaper'], { timeout: 5000 });
    spawnSync(adb, ['-s', serial, 'shell', 'chown system:system /data/system/users/0/wallpaper'], { timeout: 5000 });
    spawnSync(adb, ['-s', serial, 'shell', 'am broadcast -a android.intent.action.WALLPAPER_CHANGED'], { timeout: 5000 });
    console.log('[Android] Wallpaper set via direct copy');
  }
}

module.exports = { AndroidController };
