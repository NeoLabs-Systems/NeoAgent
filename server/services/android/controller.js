const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const { spawn, spawnSync } = require('child_process');
const { CLIExecutor } = require('../cli/executor');
const { DATA_DIR, RUNTIME_HOME } = require('../../../runtime/paths');
const { findBestNode, parseUiDump, summarizeNode } = require('./uia');

const ANDROID_ROOT = path.join(RUNTIME_HOME, 'android');
const SDK_ROOT = path.join(ANDROID_ROOT, 'sdk');
const CMDLINE_ROOT = path.join(SDK_ROOT, 'cmdline-tools');
const CMDLINE_LATEST = path.join(CMDLINE_ROOT, 'latest');
const ARTIFACTS_DIR = path.join(DATA_DIR, 'android');
const SCREENSHOTS_DIR = path.join(DATA_DIR, 'screenshots');
const UI_DUMPS_DIR = path.join(ARTIFACTS_DIR, 'ui-dumps');
const LOGS_DIR = path.join(ARTIFACTS_DIR, 'logs');
const TMP_DIR = path.join(ARTIFACTS_DIR, 'tmp');
const AVD_HOME = path.join(ANDROID_ROOT, 'avd');
const STATE_FILE = path.join(ARTIFACTS_DIR, 'state.json');
const DEFAULT_AVD_NAME = 'neoagent-default';
const DEFAULT_DATA_PARTITION = '1024M';
const DEFAULT_SDCARD_SIZE = '128M';
const DEFAULT_RAM_SIZE = '1024';
const DEFAULT_KEYEVENTS = Object.freeze({
  home: 3,
  back: 4,
  up: 19,
  down: 20,
  left: 21,
  right: 22,
  enter: 66,
  menu: 82,
  search: 84,
  app_switch: 187,
  delete: 67,
  escape: 111,
  space: 62,
  tab: 61,
});

for (const dir of [ANDROID_ROOT, SDK_ROOT, ARTIFACTS_DIR, SCREENSHOTS_DIR, UI_DUMPS_DIR, LOGS_DIR, TMP_DIR, AVD_HOME]) {
  fs.mkdirSync(dir, { recursive: true });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function commandExists(command) {
  const probe = spawnSync('bash', ['-lc', `command -v "${command}"`], { encoding: 'utf8' });
  return probe.status === 0;
}

function appendState(patch) {
  const current = readState();
  const next = {
    ...current,
    ...patch,
    updatedAt: new Date().toISOString(),
  };
  fs.writeFileSync(STATE_FILE, JSON.stringify(next, null, 2));
  return next;
}

function readState() {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  } catch {
    return {
      avdName: DEFAULT_AVD_NAME,
      serial: null,
      emulatorPid: null,
      bootstrapped: false,
      updatedAt: null,
    };
  }
}

function platformTag() {
  if (process.platform === 'darwin') return 'mac';
  if (process.platform === 'linux') return 'linux';
  throw new Error(`Android runtime bootstrap is only supported on macOS and Linux, not ${process.platform}`);
}

function systemImageArch() {
  if (process.arch === 'arm64') return 'arm64-v8a';
  return 'x86_64';
}

function parseCsvEnv(value) {
  return String(value || '')
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function configuredSystemImagePackage() {
  return String(process.env.ANDROID_SYSTEM_IMAGE_PACKAGE || '').trim() || null;
}

function configuredSystemImagePlatform() {
  return String(process.env.ANDROID_SYSTEM_IMAGE_PLATFORM || '').trim() || null;
}

function shouldForceSdkRefresh() {
  return String(process.env.ANDROID_FORCE_SDK_REFRESH || '').trim().toLowerCase() === 'true';
}

function systemImageArchCandidates() {
  const configured = parseCsvEnv(process.env.ANDROID_SYSTEM_IMAGE_ARCH);
  if (configured.length > 0) {
    return configured.filter((arch, index, list) => list.indexOf(arch) === index);
  }
  const preferred = systemImageArch();
  const fallbacks = ['x86_64', 'arm64-v8a'];
  return [preferred, ...fallbacks].filter((arch, index, list) => list.indexOf(arch) === index);
}

function parseSystemImagePlatform(platformId) {
  const stable = String(platformId || '').match(/^android-(\d+)$/);
  if (stable) {
    return {
      platformId,
      apiLevel: Number(stable[1] || 0),
      stable: true,
    };
  }

  const preview = String(platformId || '').match(/^android-([A-Za-z][A-Za-z0-9_-]*)$/);
  if (preview) {
    return {
      platformId,
      apiLevel: 0,
      stable: false,
    };
  }

  return {
    platformId,
    apiLevel: 0,
    stable: false,
  };
}

function sdkEnv() {
  const base = {
    ...process.env,
    ANDROID_HOME: SDK_ROOT,
    ANDROID_SDK_ROOT: SDK_ROOT,
    ANDROID_AVD_HOME: AVD_HOME,
    AVD_HOME,
  };
  const pathParts = [
    path.join(SDK_ROOT, 'platform-tools'),
    path.join(SDK_ROOT, 'emulator'),
    path.join(CMDLINE_LATEST, 'bin'),
    process.env.PATH || '',
  ].filter(Boolean);
  base.PATH = pathParts.join(path.delimiter);
  return base;
}

function adbBinary() {
  return process.env.ANDROID_ADB_PATH || path.join(SDK_ROOT, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb');
}

function sdkManagerBinary() {
  return path.join(CMDLINE_LATEST, 'bin', process.platform === 'win32' ? 'sdkmanager.bat' : 'sdkmanager');
}

function avdManagerBinary() {
  return path.join(CMDLINE_LATEST, 'bin', process.platform === 'win32' ? 'avdmanager.bat' : 'avdmanager');
}

function emulatorBinary() {
  return path.join(SDK_ROOT, 'emulator', process.platform === 'win32' ? 'emulator.exe' : 'emulator');
}

function isExecutable(filePath) {
  try {
    fs.accessSync(filePath, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return resolve(fetchText(res.headers.location));
      }
      if (res.statusCode !== 200) {
        reject(new Error(`GET ${url} failed with status ${res.statusCode}`));
        return;
      }
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => resolve(body));
    }).on('error', reject);
  });
}

function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    const out = fs.createWriteStream(dest);
    https.get(url, (res) => {
      if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        out.close();
        fs.rmSync(dest, { force: true });
        return resolve(downloadFile(res.headers.location, dest));
      }
      if (res.statusCode !== 200) {
        out.close();
        fs.rmSync(dest, { force: true });
        reject(new Error(`Download failed with status ${res.statusCode}`));
        return;
      }
      res.pipe(out);
      out.on('finish', () => out.close(resolve));
    }).on('error', (err) => {
      out.close();
      fs.rmSync(dest, { force: true });
      reject(err);
    });
  });
}

function extractZip(zipPath, destDir) {
  if (commandExists('unzip')) {
    const res = spawnSync('unzip', ['-qo', zipPath, '-d', destDir], { encoding: 'utf8' });
    if (res.status === 0) return;
    throw new Error(res.stderr || `unzip failed for ${zipPath}`);
  }

  if (process.platform === 'darwin' && commandExists('ditto')) {
    const res = spawnSync('ditto', ['-x', '-k', zipPath, destDir], { encoding: 'utf8' });
    if (res.status === 0) return;
    throw new Error(res.stderr || `ditto failed for ${zipPath}`);
  }

  throw new Error('Neither unzip nor ditto is available to extract Android SDK archives');
}

function parseLatestCmdlineToolsUrl(xml) {
  const tag = platformTag() === 'mac' ? 'macosx' : 'linux';
  const packageMatch = xml.match(new RegExp(`<remotePackage\\s+path="cmdline-tools;latest">([\\s\\S]*?)<\\/remotePackage>`));
  if (!packageMatch) throw new Error('Could not locate cmdline-tools;latest in Android repository metadata');

  const archiveBlocks = packageMatch[1].match(/<archive>[\s\S]*?<\/archive>/g) || [];
  for (const block of archiveBlocks) {
    if (!new RegExp(`<host-os>${tag}<\\/host-os>`).test(block)) continue;
    const urlMatch = block.match(/<url>\s*([^<]*commandlinetools-[^<]+_latest\.zip)\s*<\/url>/);
    if (urlMatch) return `https://dl.google.com/android/repository/${urlMatch[1]}`;
  }

  throw new Error(`Could not find a command line tools archive for ${tag}`);
}

function systemImageTagScore(tag) {
  const value = String(tag || '').toLowerCase();
  if (value.startsWith('google_apis_playstore')) return 50;
  if (value.startsWith('google_apis')) return 40;
  if (value === 'google_atd') return 30;
  if (value === 'aosp_atd') return 20;
  if (value === 'default') return 10;
  return 0;
}

function parseSystemImages(listOutput) {
  const matches = [];
  const regex = /system-images;(android-[^;\s]+);([^;\s]+);([^;\s]+)/g;
  let match = regex.exec(listOutput);
  while (match) {
    const platform = parseSystemImagePlatform(match[1]);
    matches.push({
      packageName: match[0],
      platformId: match[1],
      tag: match[2],
      arch: match[3],
      apiLevel: platform.apiLevel,
      stable: platform.stable,
      tagScore: systemImageTagScore(match[2]),
    });
    match = regex.exec(listOutput);
  }

  return matches;
}

function rankSystemImagePool(pool) {
  const preferredMatches = pool.filter((candidate) => candidate.tagScore > 0);
  const rankedPool = preferredMatches.length > 0 ? preferredMatches : pool;

  rankedPool.sort((a, b) =>
    Number(b.stable) - Number(a.stable) ||
    b.apiLevel - a.apiLevel ||
    b.tagScore - a.tagScore ||
    a.packageName.localeCompare(b.packageName)
  );

  return rankedPool;
}

function chooseConfiguredSystemImage(listOutput) {
  const matches = parseSystemImages(listOutput);
  const packageName = configuredSystemImagePackage();
  if (packageName) {
    return matches.find((candidate) => candidate.packageName === packageName) || null;
  }

  const platformId = configuredSystemImagePlatform();
  if (!platformId) return null;

  const pool = matches.filter((candidate) => candidate.platformId === platformId);
  if (pool.length === 0) return null;

  let archPool = [];
  for (const arch of systemImageArchCandidates()) {
    archPool = pool.filter((candidate) => candidate.arch === arch);
    if (archPool.length > 0) break;
  }

  return rankSystemImagePool(archPool.length > 0 ? archPool : pool)[0] || null;
}

function chooseLatestSystemImage(listOutput, preferredArchs = systemImageArchCandidates()) {
  const matches = parseSystemImages(listOutput);
  const archPool = Array.isArray(preferredArchs) && preferredArchs.length > 0
    ? preferredArchs
    : systemImageArchCandidates();

  let pool = [];
  for (const arch of archPool) {
    pool = matches.filter((candidate) => candidate.arch === arch);
    if (pool.length > 0) break;
  }

  if (pool.length === 0) {
    pool = matches;
  }

  return rankSystemImagePool(pool)[0] || null;
}

function formatSystemImageError(listOutput) {
  const availableArchs = [...new Set(parseSystemImages(listOutput).map((candidate) => candidate.arch))].sort();
  const wantedArchs = systemImageArchCandidates().join(', ');
  const packageName = configuredSystemImagePackage();
  const platformId = configuredSystemImagePlatform();
  const available = availableArchs.length > 0 ? availableArchs.join(', ') : 'none';
  const overrideDetails = [
    packageName ? `package=${packageName}` : null,
    platformId ? `platform=${platformId}` : null,
  ].filter(Boolean);
  const overrideText = overrideDetails.length > 0 ? ` Configured override: ${overrideDetails.join(', ')}.` : '';
  return `No compatible Android system image found. Preferred architectures: ${wantedArchs}. Available architectures: ${available}.${overrideText}`;
}

function parseApiLevelFromSystemImage(packageName) {
  const match = String(packageName || '').match(/system-images;android-(\d+);/);
  return match ? Number(match[1] || 0) : 0;
}

function androidTextEscape(text) {
  return String(text || '')
    .replace(/\\/g, '\\\\')
    .replace(/ /g, '%s')
    .replace(/"/g, '\\"')
    .replace(/'/g, "\\'")
    .replace(/[&()<>|;$`]/g, '');
}

function quoteShell(value) {
  return `'${String(value || '').replace(/'/g, `'\\''`)}'`;
}

function updateIniValue(content, key, value) {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const line = `${key}=${value}`;
  if (new RegExp(`^${escapedKey}=.*$`, 'm').test(content)) {
    return content.replace(new RegExp(`^${escapedKey}=.*$`, 'm'), line);
  }
  return `${content.replace(/\s*$/, '')}\n${line}\n`;
}

function sanitizeUiXml(raw) {
  const text = String(raw || '');
  const start = text.indexOf('<?xml');
  const end = text.lastIndexOf('</hierarchy>');
  if (start >= 0 && end >= start) {
    return text.slice(start, end + '</hierarchy>'.length);
  }
  return text.trim();
}

class AndroidController {
  constructor(io) {
    this.io = io;
    this.cli = new CLIExecutor();
    this.avdName = readState().avdName || DEFAULT_AVD_NAME;
    this.bootstrapPromise = null;
    this.startPromise = null;
    this.#registerProcessCleanup();
  }

  static cleanupRegistered = false;

  #registerProcessCleanup() {
    if (AndroidController.cleanupRegistered) {
      return;
    }
    AndroidController.cleanupRegistered = true;

    const cleanup = () => {
      try {
        this.#stopTrackedEmulatorSync();
      } catch {}
    };

    process.once('exit', cleanup);
    process.once('uncaughtException', cleanup);
    process.once('unhandledRejection', cleanup);
  }

  #stopTrackedEmulatorSync() {
    const state = readState();
    const serial = state.serial;

    if (serial && isExecutable(adbBinary())) {
      try {
        spawnSync(adbBinary(), ['-s', serial, 'emu', 'kill'], {
          stdio: 'ignore',
          env: sdkEnv(),
        });
      } catch {}
    }

    if (state.emulatorPid) {
      try {
        process.kill(state.emulatorPid, 0);
        process.kill(state.emulatorPid, 'SIGTERM');
      } catch {}
    }

    appendState({ serial: null, emulatorPid: null });
  }

  async #run(command, options = {}) {
    const result = await this.cli.execute(command, {
      timeout: options.timeout || 120000,
      env: sdkEnv(),
      cwd: options.cwd || ANDROID_ROOT,
    });
    if (result.exitCode !== 0) {
      throw new Error(result.stderr || result.stdout || `Command failed: ${command}`);
    }
    return result.stdout || '';
  }

  async #runAllowFailure(command, options = {}) {
    return this.cli.execute(command, {
      timeout: options.timeout || 120000,
      env: sdkEnv(),
      cwd: options.cwd || ANDROID_ROOT,
    });
  }

  async ensureBootstrapped() {
    const binariesReady =
      isExecutable(adbBinary()) &&
      isExecutable(sdkManagerBinary()) &&
      isExecutable(emulatorBinary());

    if (!binariesReady) {
      if (this.bootstrapPromise) {
        await this.bootstrapPromise;
      } else {
        this.bootstrapPromise = this.#bootstrapRuntime();
        try {
          await this.bootstrapPromise;
        } finally {
          this.bootstrapPromise = null;
        }
      }
    }

    const state = readState();
    if (
      state.bootstrapped === true &&
      state.systemImage &&
      !shouldForceSdkRefresh()
    ) {
      return;
    }

    appendState({ bootstrapped: true });
    const sdkmanager = sdkManagerBinary();
    const available = await this.#run(`${quoteShell(sdkmanager)} --sdk_root=${quoteShell(SDK_ROOT)} --list`, { timeout: 300000 });
    const latestSystemImage = chooseConfiguredSystemImage(available) || chooseLatestSystemImage(available);
    if (!latestSystemImage) throw new Error(formatSystemImageError(available));

    const refreshedState = readState();
    const currentApiLevel = parseApiLevelFromSystemImage(refreshedState.systemImage);
    const shouldUpgrade =
      refreshedState.systemImage !== latestSystemImage.packageName ||
      currentApiLevel < latestSystemImage.apiLevel;

    if (shouldUpgrade) {
      await this.#run(`${quoteShell(sdkmanager)} --sdk_root=${quoteShell(SDK_ROOT)} "${latestSystemImage.packageName}"`, {
        timeout: 300000,
      });
      appendState({
        bootstrapped: true,
        systemImage: latestSystemImage.packageName,
        apiLevel: latestSystemImage.apiLevel,
        systemImageArch: latestSystemImage.arch,
      });
    }
  }

  async #bootstrapRuntime() {
    const metadata = await fetchText('https://dl.google.com/android/repository/repository2-1.xml');
    const url = parseLatestCmdlineToolsUrl(metadata);
    const zipPath = path.join(TMP_DIR, path.basename(url));
    const extractDir = path.join(TMP_DIR, `cmdline-tools-${Date.now()}`);

    fs.mkdirSync(extractDir, { recursive: true });
    await downloadFile(url, zipPath);
    extractZip(zipPath, extractDir);

    const candidates = [
      path.join(extractDir, 'cmdline-tools'),
      path.join(extractDir, 'tools'),
      extractDir,
    ];
    const extractedRoot = candidates.find((candidate) => fs.existsSync(path.join(candidate, 'bin')));
    if (!extractedRoot) throw new Error('Downloaded Android command line tools archive did not contain a bin directory');

    fs.rmSync(CMDLINE_LATEST, { recursive: true, force: true });
    fs.mkdirSync(CMDLINE_ROOT, { recursive: true });
    fs.cpSync(extractedRoot, CMDLINE_LATEST, { recursive: true });
    fs.rmSync(zipPath, { force: true });
    fs.rmSync(extractDir, { recursive: true, force: true });

    const sdkmanager = sdkManagerBinary();
    await this.#run(`yes | ${quoteShell(sdkmanager)} --sdk_root=${quoteShell(SDK_ROOT)} --licenses`, { timeout: 300000 });
    await this.#run(`${quoteShell(sdkmanager)} --sdk_root=${quoteShell(SDK_ROOT)} "platform-tools" "emulator"`, { timeout: 300000 });

    const available = await this.#run(`${quoteShell(sdkmanager)} --sdk_root=${quoteShell(SDK_ROOT)} --list`, { timeout: 300000 });
    const systemImage = chooseConfiguredSystemImage(available) || chooseLatestSystemImage(available);
    if (!systemImage) throw new Error(formatSystemImageError(available));

    await this.#run(`${quoteShell(sdkmanager)} --sdk_root=${quoteShell(SDK_ROOT)} "${systemImage.packageName}"`, { timeout: 300000 });
    appendState({
      bootstrapped: true,
      systemImage: systemImage.packageName,
      apiLevel: systemImage.apiLevel,
      systemImageArch: systemImage.arch,
    });
  }

  async ensureAvd() {
    await this.ensureBootstrapped();

    const state = readState();
    const list = await this.#run(`${quoteShell(avdManagerBinary())} list avd`, { timeout: 120000 }).catch(() => '');
    const pkg = state.systemImage;
    if (!pkg) throw new Error('Android system image not installed');
    const avdExists = list.includes(`Name: ${this.avdName}`);
    const avdNeedsRecreate = avdExists && (!state.avdSystemImage || state.avdSystemImage !== pkg);

    if (avdNeedsRecreate) {
      await this.stopEmulator().catch(() => {});
      await this.#run(`${quoteShell(avdManagerBinary())} delete avd -n ${quoteShell(this.avdName)}`, {
        timeout: 120000,
      }).catch(() => {});
      fs.rmSync(path.join(AVD_HOME, `${this.avdName}.avd`), { recursive: true, force: true });
      fs.rmSync(path.join(AVD_HOME, `${this.avdName}.ini`), { force: true });
    } else if (avdExists) {
      return;
    }

    await this.#run(`printf 'no\\n' | ${quoteShell(avdManagerBinary())} create avd -n ${quoteShell(this.avdName)} -k "${pkg}" --force`, {
      timeout: 120000,
    });
    this.#normalizeAvdConfig();
    appendState({ avdSystemImage: pkg });
  }

  #normalizeAvdConfig() {
    const configPath = path.join(AVD_HOME, `${this.avdName}.avd`, 'config.ini');
    if (!fs.existsSync(configPath)) return;

    let content = fs.readFileSync(configPath, 'utf8');
    content = updateIniValue(content, 'disk.dataPartition.size', DEFAULT_DATA_PARTITION);
    content = updateIniValue(content, 'sdcard.size', DEFAULT_SDCARD_SIZE);
    content = updateIniValue(content, 'hw.ramSize', DEFAULT_RAM_SIZE);
    fs.writeFileSync(configPath, content);
  }

  async listDevices(options = {}) {
    if (options.ensureBootstrapped !== false) {
      await this.ensureBootstrapped();
    }
    if (!isExecutable(adbBinary())) {
      return [];
    }
    const out = await this.#run(`${quoteShell(adbBinary())} devices -l`);
    const lines = out.split('\n').map((line) => line.trim()).filter(Boolean);
    return lines
      .filter((line) => !line.toLowerCase().startsWith('list of devices'))
      .map((line) => {
        const parts = line.split(/\s+/);
        return {
          serial: parts[0] || '',
          status: parts[1] || 'unknown',
          details: parts.slice(2).join(' '),
          emulator: (parts[0] || '').startsWith('emulator-'),
        };
      });
  }

  async getPrimarySerial(options = {}) {
    const state = readState();
    const devices = await this.listDevices(options);
    const preferred = state.serial ? devices.find((device) => device.serial === state.serial && device.status === 'device') : null;
    if (preferred) return preferred.serial;
    const emulator = devices.find((device) => device.emulator && device.status === 'device');
    if (emulator) {
      appendState({ serial: emulator.serial });
      return emulator.serial;
    }
    const online = devices.find((device) => device.status === 'device');
    if (online) return online.serial;
    return null;
  }

  async #startEmulatorBlocking(options = {}) {
    appendState({
      starting: true,
      startupPhase: 'Preparing Android runtime',
      lastStartError: null,
      startRequestedAt: readState().startRequestedAt || new Date().toISOString(),
    });
    console.log('[Android] Preparing emulator start');
    await this.ensureAvd();
    appendState({
      starting: true,
      startupPhase: 'Checking for an existing Android device',
      lastStartError: null,
    });
    this.#normalizeAvdConfig();
    const serial = await this.getPrimarySerial();
    if (serial) {
      appendState({
        starting: false,
        startupPhase: null,
        serial,
        lastStartError: null,
        lastLogLine: 'Android device already running.',
      });
      return {
        success: true,
        serial,
        reused: true,
        bootstrapped: readState().bootstrapped === true,
      };
    }

    const logPath = path.join(LOGS_DIR, `emulator-${Date.now()}.log`);
    const out = fs.openSync(logPath, 'a');
    const args = [
      `@${this.avdName}`,
      '-no-boot-anim',
      '-gpu',
      process.platform === 'darwin' ? 'host' : 'swiftshader_indirect',
      '-netdelay',
      'none',
      '-netspeed',
      'full',
    ];

    if (options.headless !== false) {
      args.push('-no-window', '-no-audio');
    }

    const child = spawn(emulatorBinary(), args, {
      detached: true,
      stdio: ['ignore', out, out],
      env: sdkEnv(),
    });
    child.unref();

    console.log(`[Android] Emulator process started (pid ${child.pid})`);
    appendState({
      emulatorPid: child.pid,
      avdName: this.avdName,
      logPath,
      starting: true,
      startupPhase: 'Waiting for Android emulator to boot',
      lastStartError: null,
      lastLogLine: 'Android emulator process started. Waiting for boot completion...',
    });

    const onlineSerial = await this.waitForDevice({ timeoutMs: options.timeoutMs || 240000 });
    appendState({
      serial: onlineSerial,
      emulatorPid: child.pid,
      starting: false,
      startupPhase: null,
      lastStartError: null,
      lastLogLine: 'Android emulator boot completed.',
    });
    console.log(`[Android] Emulator ready on ${onlineSerial}`);

    return {
      success: true,
      serial: onlineSerial,
      emulatorPid: child.pid,
      logPath,
    };
  }

  async startEmulator(options = {}) {
    if (this.startPromise) {
      await this.startPromise;
      const serial = await this.getPrimarySerial();
      if (!serial) {
        throw new Error(readState().lastStartError || 'Android emulator did not finish starting.');
      }
      return {
        success: true,
        serial,
        reused: false,
        bootstrapped: readState().bootstrapped === true,
      };
    }

    return this.#startEmulatorBlocking(options);
  }

  async requestStartEmulator(options = {}) {
    const serial = await this.getPrimarySerial({ ensureBootstrapped: false }).catch(() => null);
    if (serial) {
      appendState({
        starting: false,
        startupPhase: null,
        serial,
        lastStartError: null,
        lastLogLine: 'Android device already running.',
      });
      return {
        success: true,
        pending: false,
        serial,
        reused: true,
        bootstrapped: readState().bootstrapped === true,
      };
    }

    if (!this.startPromise) {
      const requestedAt = new Date().toISOString();
      appendState({
        starting: true,
        startupPhase: 'Preparing Android runtime',
        lastStartError: null,
        startRequestedAt: requestedAt,
        lastLogLine: 'Android start requested.',
      });
      const startPromise = this.#startEmulatorBlocking(options).catch((err) => {
        appendState({
          starting: false,
          startupPhase: 'Start failed',
          lastStartError: err.message,
          lastLogLine: err.message,
        });
        console.error('[Android] Emulator start failed:', err.message);
        throw err;
      }).finally(() => {
        if (this.startPromise === startPromise) {
          this.startPromise = null;
        }
      });
      this.startPromise = startPromise;
      startPromise.catch(() => {});
    }

    const state = readState();
    return {
      success: true,
      pending: true,
      bootstrapped: state.bootstrapped === true,
      starting: true,
      startupPhase: state.startupPhase || 'Preparing Android runtime',
      startRequestedAt: state.startRequestedAt || null,
      logPath: state.logPath || null,
    };
  }

  async waitForDevice(options = {}) {
    const timeoutMs = Math.max(10000, Number(options.timeoutMs) || 180000);
    const deadline = Date.now() + timeoutMs;

    while (Date.now() < deadline) {
      const serial = await this.getPrimarySerial();
      if (serial) {
        const boot = await this.#runAllowFailure(`${quoteShell(adbBinary())} -s ${quoteShell(serial)} shell getprop sys.boot_completed`, { timeout: 10000 });
        if ((boot.stdout || '').trim() === '1') {
          return serial;
        }
      }
      await sleep(3000);
    }

    throw new Error(`Android emulator did not finish booting within ${timeoutMs} ms`);
  }

  async ensureDevice() {
    const serial = await this.getPrimarySerial();
    if (serial) return serial;
    const started = await this.startEmulator();
    return started.serial;
  }

  async stopEmulator() {
    const state = readState();
    const serial = await this.getPrimarySerial();
    if (serial) {
      await this.#runAllowFailure(`${quoteShell(adbBinary())} -s ${quoteShell(serial)} emu kill`, { timeout: 15000 });
    }
    if (state.emulatorPid) {
      try { process.kill(state.emulatorPid, 'SIGTERM'); } catch {}
    }
    appendState({
      serial: null,
      emulatorPid: null,
      starting: false,
      startupPhase: null,
      lastStartError: null,
      lastLogLine: 'Android emulator stopped.',
    });

    const deadline = Date.now() + 30000;
    while (Date.now() < deadline) {
      const devices = await this.listDevices().catch(() => []);
      const stillPresent = devices.some((device) => device.emulator && device.status === 'device');
      let pidAlive = false;
      if (state.emulatorPid) {
        try {
          process.kill(state.emulatorPid, 0);
          pidAlive = true;
        } catch {
          pidAlive = false;
        }
      }
      if (!stillPresent && !pidAlive) break;
      await sleep(1000);
    }

    return { success: true };
  }

  async #adb(serial, command, options = {}) {
    return this.#run(`${quoteShell(adbBinary())} -s ${quoteShell(serial)} ${command}`, options);
  }

  async screenshot(options = {}) {
    const serial = await this.ensureDevice();
    const filename = `android_${Date.now()}.png`;
    const fullPath = path.join(SCREENSHOTS_DIR, filename);
    await this.#run(`${quoteShell(adbBinary())} -s ${quoteShell(serial)} exec-out screencap -p > ${quoteShell(fullPath)}`, { timeout: 30000 });
    return {
      success: true,
      serial,
      screenshotPath: `/screenshots/${filename}`,
      fullPath,
    };
  }

  async dumpUi(options = {}) {
    const serial = await this.ensureDevice();
    let xml = await this.#adb(serial, 'shell uiautomator dump --compressed /dev/tty', { timeout: 30000 });
    if (!String(xml || '').includes('<hierarchy')) {
      const remote = '/sdcard/neoagent-ui.xml';
      await this.#adb(serial, `shell uiautomator dump --compressed ${quoteShell(remote)}`, { timeout: 30000 });
      xml = await this.#adb(serial, `shell cat ${quoteShell(remote)}`, { timeout: 30000 });
    }
    xml = sanitizeUiXml(xml);
    const filename = `android_ui_${Date.now()}.xml`;
    const fullPath = path.join(UI_DUMPS_DIR, filename);
    fs.writeFileSync(fullPath, xml);

    const nodes = parseUiDump(xml);
    return {
      success: true,
      serial,
      nodeCount: nodes.length,
      uiDumpPath: fullPath,
      preview: options.includeNodes === false ? undefined : nodes.slice(0, 25).map((node) => summarizeNode(node)),
      xml,
    };
  }

  async #resolveSelector(args = {}) {
    const dump = await this.dumpUi({ includeNodes: false });
    const selector = {
      text: args.text,
      resourceId: args.resourceId,
      description: args.description,
      className: args.className,
      packageName: args.packageName,
      clickable: args.clickable,
    };
    const node = findBestNode(dump.xml, selector);
    if (!node) throw new Error('No Android UI element matched the selector');
    return {
      serial: dump.serial,
      uiDumpPath: dump.uiDumpPath,
      node,
    };
  }

  async tap(args = {}) {
    let x = Number(args.x);
    let y = Number(args.y);
    let node = null;
    let serial = await this.ensureDevice();
    let uiDumpPath = null;

    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      const resolved = await this.#resolveSelector(args);
      serial = resolved.serial;
      node = resolved.node;
      uiDumpPath = resolved.uiDumpPath;
      x = node.bounds.centerX;
      y = node.bounds.centerY;
    }

    await this.#adb(serial, `shell input tap ${Math.round(x)} ${Math.round(y)}`, { timeout: 15000 });
    const shot = await this.screenshot();
    return {
      success: true,
      serial,
      x: Math.round(x),
      y: Math.round(y),
      target: summarizeNode(node),
      uiDumpPath,
      screenshotPath: shot.screenshotPath,
    };
  }

  async type(args = {}) {
    const serial = await this.ensureDevice();
    if (args.clear === true) {
      await this.#adb(serial, 'shell input keyevent 123', { timeout: 10000 }).catch(() => {});
      await this.#adb(serial, 'shell input keyevent 67', { timeout: 10000 }).catch(() => {});
    }

    if (args.selector || args.textSelector || args.resourceId || args.description) {
      await this.tap({
        text: args.textSelector,
        resourceId: args.resourceId,
        description: args.description,
        className: args.className,
        clickable: true,
      }).catch(() => {});
    }

    await this.#adb(serial, `shell input text ${quoteShell(androidTextEscape(args.text || ''))}`, { timeout: 20000 });
    if (args.pressEnter) {
      await this.#adb(serial, 'shell input keyevent 66', { timeout: 10000 });
    }
    const shot = await this.screenshot();
    return {
      success: true,
      serial,
      typed: args.text || '',
      screenshotPath: shot.screenshotPath,
    };
  }

  async swipe(args = {}) {
    const serial = await this.ensureDevice();
    const x1 = Number(args.x1);
    const y1 = Number(args.y1);
    const x2 = Number(args.x2);
    const y2 = Number(args.y2);
    const duration = Math.max(50, Number(args.durationMs) || 300);
    if (![x1, y1, x2, y2].every(Number.isFinite)) {
      throw new Error('x1, y1, x2, and y2 are required for android_swipe');
    }
    await this.#adb(serial, `shell input swipe ${Math.round(x1)} ${Math.round(y1)} ${Math.round(x2)} ${Math.round(y2)} ${Math.round(duration)}`, { timeout: 15000 });
    const shot = await this.screenshot();
    return {
      success: true,
      serial,
      screenshotPath: shot.screenshotPath,
    };
  }

  async pressKey(args = {}) {
    const serial = await this.ensureDevice();
    const raw = String(args.key || '').trim().toLowerCase();
    const keyCode = Number.isFinite(Number(raw)) ? Number(raw) : (DEFAULT_KEYEVENTS[raw] || null);
    if (!keyCode) throw new Error(`Unsupported Android key: ${args.key}`);
    await this.#adb(serial, `shell input keyevent ${keyCode}`, { timeout: 10000 });
    const shot = await this.screenshot();
    return {
      success: true,
      serial,
      key: args.key,
      keyCode,
      screenshotPath: shot.screenshotPath,
    };
  }

  async waitFor(args = {}) {
    const timeoutMs = Math.max(1000, Number(args.timeoutMs) || 20000);
    const intervalMs = Math.max(250, Number(args.intervalMs) || 1500);
    const deadline = Date.now() + timeoutMs;

    while (Date.now() < deadline) {
      const dump = await this.dumpUi({ includeNodes: false });
      const node = findBestNode(dump.xml, {
        text: args.text,
        resourceId: args.resourceId,
        description: args.description,
        className: args.className,
        packageName: args.packageName,
        clickable: args.clickable,
      });
      if (node) {
        const shot = args.screenshot === false ? null : await this.screenshot();
        return {
          success: true,
          serial: dump.serial,
          matched: summarizeNode(node),
          uiDumpPath: dump.uiDumpPath,
          screenshotPath: shot?.screenshotPath || null,
        };
      }
      await sleep(intervalMs);
    }

    throw new Error(`Timed out after ${timeoutMs} ms waiting for Android UI element`);
  }

  async openApp(args = {}) {
    const serial = await this.ensureDevice();
    if (args.activity) {
      await this.#adb(serial, `shell am start -n ${quoteShell(`${args.packageName}/${args.activity}`)}`, { timeout: 20000 });
    } else if (args.packageName) {
      await this.#adb(serial, `shell monkey -p ${quoteShell(args.packageName)} -c android.intent.category.LAUNCHER 1`, { timeout: 30000 });
    } else {
      throw new Error('packageName is required for android_open_app');
    }
    const shot = await this.screenshot();
    return {
      success: true,
      serial,
      packageName: args.packageName,
      activity: args.activity || null,
      screenshotPath: shot.screenshotPath,
    };
  }

  async openIntent(args = {}) {
    const serial = await this.ensureDevice();
    const parts = ['shell am start'];
    if (args.action) parts.push('-a', quoteShell(args.action));
    if (args.dataUri) parts.push('-d', quoteShell(args.dataUri));
    if (args.packageName) parts.push('-p', quoteShell(args.packageName));
    if (args.component) parts.push('-n', quoteShell(args.component));
    if (args.mimeType) parts.push('-t', quoteShell(args.mimeType));

    if (args.extras && typeof args.extras === 'object') {
      for (const [key, value] of Object.entries(args.extras)) {
        parts.push('--es', quoteShell(key), quoteShell(String(value)));
      }
    }

    await this.#adb(serial, parts.join(' '), { timeout: 20000 });
    const shot = await this.screenshot();
    return {
      success: true,
      serial,
      screenshotPath: shot.screenshotPath,
    };
  }

  async listApps(args = {}) {
    const serial = await this.ensureDevice();
    const cmd = args.includeSystem === true ? 'shell pm list packages' : 'shell pm list packages -3';
    const out = await this.#adb(serial, cmd, { timeout: 30000 });
    const packages = out
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => line.replace(/^package:/, ''))
      .sort();
    return {
      success: true,
      serial,
      count: packages.length,
      packages,
    };
  }

  async installApk(args = {}) {
    const apkPath = path.resolve(String(args.apkPath || ''));
    if (!apkPath || !fs.existsSync(apkPath)) throw new Error(`APK not found: ${apkPath}`);
    const serial = await this.ensureDevice();
    await this.#adb(serial, `install -r ${quoteShell(apkPath)}`, { timeout: 300000 });
    return {
      success: true,
      serial,
      apkPath,
    };
  }

  async getStatus() {
    const devices = isExecutable(adbBinary())
      ? await this.listDevices({ ensureBootstrapped: false }).catch(() => [])
      : [];
    const state = readState();
    let lastLogLine =
      state.lastStartError ||
      state.lastLogLine ||
      state.startupPhase ||
      null;
    if (state.logPath && fs.existsSync(state.logPath)) {
      try {
        const lines = fs.readFileSync(state.logPath, 'utf8')
          .split('\n')
          .map((line) => line.trim())
          .filter(Boolean);
        const emulatorLogLine = [...lines].reverse().find((line) =>
          /fatal|error|warning|boot completed|disk space|running avd/i.test(line)
        ) || lines[lines.length - 1] || null;
        lastLogLine = emulatorLogLine || lastLogLine;
      } catch {
        lastLogLine =
          state.lastStartError ||
          state.lastLogLine ||
          state.startupPhase ||
          null;
      }
    }
    return {
      bootstrapped: state.bootstrapped === true,
      starting: state.starting === true || this.startPromise != null,
      startupPhase: state.startupPhase || null,
      startRequestedAt: state.startRequestedAt || null,
      lastStartError: state.lastStartError || null,
      sdkRoot: SDK_ROOT,
      avdHome: AVD_HOME,
      avdName: this.avdName,
      adbPath: adbBinary(),
      emulatorPath: emulatorBinary(),
      serial: state.serial,
      emulatorPid: state.emulatorPid,
      systemImage: state.systemImage || null,
      systemImageArch: state.systemImageArch || null,
      preferredSystemImageArchs: systemImageArchCandidates(),
      configuredSystemImagePackage: configuredSystemImagePackage(),
      configuredSystemImagePlatform: configuredSystemImagePlatform(),
      apiLevel: Number(state.apiLevel || 0) || null,
      avdSystemImage: state.avdSystemImage || null,
      logPath: state.logPath || null,
      lastLogLine,
      devices,
      canBootstrap: process.platform === 'darwin' || process.platform === 'linux',
    };
  }

  async close() {
    return this.stopEmulator().catch(() => {});
  }
}

module.exports = {
  AndroidController,
  androidTextEscape,
  chooseConfiguredSystemImage,
  chooseLatestSystemImage,
  configuredSystemImagePackage,
  configuredSystemImagePlatform,
  formatSystemImageError,
  parseLatestCmdlineToolsUrl,
  parseSystemImages,
  sanitizeUiXml,
  systemImageArchCandidates,
};
