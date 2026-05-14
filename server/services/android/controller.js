const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const { spawn, spawnSync } = require('child_process');
const lockfile = require('proper-lockfile');
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
const EMULATOR_HOME = path.join(ANDROID_ROOT, 'home');
const EMULATOR_ADVANCED_FEATURES_FILE = path.join(EMULATOR_HOME, 'advancedFeatures.ini');
const AVD_HOME = path.join(ANDROID_ROOT, 'avd');
const STATE_DIR = path.join(ARTIFACTS_DIR, 'state');
const STATE_FILE = path.join(ARTIFACTS_DIR, 'state.json');
const OWNERSHIP_FILE = path.join(ARTIFACTS_DIR, 'device-ownership.json');
const ANDROID_BOOTSTRAP_WORKER = path.join(__dirname, 'android_bootstrap_worker.js');
const ANDROID_JAVA_TOOL_TIMEOUT_MS = 20 * 60 * 1000;
const DEFAULT_AVD_NAME = 'neoagent-default';
const DEFAULT_DATA_PARTITION_BYTES = 1024 * 1024 * 1024;
const DEFAULT_PARTITION_SIZE_MB = 1024;
const DEFAULT_SDCARD_SIZE_BYTES = 32 * 1024 * 1024;
const DEFAULT_RAM_SIZE_MB = 768;
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

for (const dir of [ANDROID_ROOT, SDK_ROOT, EMULATOR_HOME, ARTIFACTS_DIR, SCREENSHOTS_DIR, UI_DUMPS_DIR, LOGS_DIR, TMP_DIR, AVD_HOME, STATE_DIR]) {
  fs.mkdirSync(dir, { recursive: true });
}

function ensureEmulatorAdvancedFeaturesFile() {
  try {
    if (fs.existsSync(EMULATOR_ADVANCED_FEATURES_FILE)) {
      fs.rmSync(EMULATOR_ADVANCED_FEATURES_FILE, { force: true });
    }
  } catch {}
}

function sanitizeScopeKey(value) {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-');
  return normalized.replace(/^-+|-+$/g, '').slice(0, 48) || 'default';
}

function resolveStateFile(scopeKey) {
  const key = sanitizeScopeKey(scopeKey);
  if (key === 'default') {
    return STATE_FILE;
  }
  return path.join(STATE_DIR, `${key}.json`);
}

function readOwnership() {
  return withOwnershipLock(() => {
    return readOwnershipUnlocked();
  });
}

function writeOwnership(nextOwners) {
  withOwnershipLock(() => {
    writeOwnershipUnlocked(nextOwners);
  });
}

function readOwnershipUnlocked() {
  try {
    const parsed = JSON.parse(fs.readFileSync(OWNERSHIP_FILE, 'utf8'));
    if (!parsed || typeof parsed !== 'object') {
      return {};
    }
  return parsed;
  } catch {
    return {};
  }
}

function ensureSparseFile(filePath, sizeBytes) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const fd = fs.openSync(filePath, 'a');
  try {
    const currentSize = fs.statSync(filePath).size;
    if (currentSize !== sizeBytes) {
      fs.ftruncateSync(fd, sizeBytes);
    }
  } finally {
    fs.closeSync(fd);
  }
}

function writeOwnershipUnlocked(nextOwners) {
  const tempPath = `${OWNERSHIP_FILE}.tmp`;
  fs.writeFileSync(tempPath, JSON.stringify(nextOwners, null, 2));
  fs.renameSync(tempPath, OWNERSHIP_FILE);
}

function withOwnershipLock(work) {
  fs.mkdirSync(path.dirname(OWNERSHIP_FILE), { recursive: true });
  if (!fs.existsSync(OWNERSHIP_FILE)) {
    fs.writeFileSync(OWNERSHIP_FILE, '{}');
  }
  let lastError = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const release = lockfile.lockSync(OWNERSHIP_FILE, {
        realpath: false,
      });
      try {
        return work();
      } finally {
        release();
      }
    } catch (err) {
      lastError = err;
      if (attempt === 2) {
        break;
      }
    }
  }
  throw lastError;
}

function normalizeOwnerKey(userId) {
  if (userId == null || String(userId).trim() === '') {
    return 'system';
  }
  return `user-${sanitizeScopeKey(userId)}`;
}

function pruneOwnershipByDevices(owners, devices = []) {
  const presentSerials = new Set(
    devices
      .map((device) => String(device?.serial || '').trim())
      .filter(Boolean)
  );
  const next = {};
  let changed = false;

  for (const [serial, owner] of Object.entries(owners || {})) {
    if (!presentSerials.has(serial)) {
      changed = true;
      continue;
    }
    next[serial] = owner;
  }

  return { next, changed };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function tailFile(filePath, maxLines = 40) {
  try {
    const lines = fs.readFileSync(filePath, 'utf8')
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean);
    return lines.slice(-maxLines);
  } catch {
    return [];
  }
}

function commandExists(command) {
  const probe = spawnSync('bash', ['-lc', `command -v "${command}"`], { encoding: 'utf8' });
  return probe.status === 0;
}

function parseResolvedLaunchComponent(output, packageName) {
  const lines = String(output || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
  const normalizedPackage = String(packageName || '').trim();
  const componentPattern = /^[A-Za-z0-9._$]+\/[A-Za-z0-9._$]+$/;
  const relativePattern = /^[A-Za-z0-9._$]+\/\.[A-Za-z0-9._$]+$/;

  const exact = lines.find((line) =>
    normalizedPackage
      ? line.startsWith(`${normalizedPackage}/`)
      : componentPattern.test(line) || relativePattern.test(line)
  );
  if (exact) return exact;

  return lines.find((line) => componentPattern.test(line) || relativePattern.test(line)) || null;
}

function appendState(patch, stateFile = STATE_FILE) {
  const current = readState(stateFile);
  const next = {
    ...current,
    ...patch,
    updatedAt: new Date().toISOString(),
  };
  fs.writeFileSync(stateFile, JSON.stringify(next, null, 2));
  return next;
}

function readState(stateFile = STATE_FILE) {
  try {
    return JSON.parse(fs.readFileSync(stateFile, 'utf8'));
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
  if (process.platform === 'darwin') return 'arm64-v8a';
  if (process.arch === 'arm64') return 'arm64-v8a';
  return 'x86_64';
}

function emulatorHostArch() {
  if (process.platform === 'darwin') return process.arch === 'arm64' ? 'aarch64' : 'x64';
  if (process.arch === 'arm64') return 'aarch64';
  return 'x64';
}

function emulatorGpuMode() {
  return 'auto';
}

function emulatorLaunchArgs(avdName) {
  return ['-no-snapshot-load'];
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

function installedEmulatorMatchesHost() {
  const binary = emulatorBinary();
  if (!isExecutable(binary)) {
    return false;
  }

  const probe = spawnSync('file', [binary], { encoding: 'utf8' });
  if (probe.status !== 0) {
    return false;
  }

  const output = `${probe.stdout || ''}${probe.stderr || ''}`.toLowerCase();
  const hostArch = emulatorHostArch();
  if (hostArch === 'aarch64') {
    return output.includes('arm64') || output.includes('aarch64');
  }
  if (hostArch === 'x64') {
    return output.includes('x86_64');
  }
  return true;
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

  const released = String(platformId || '').match(/^android-(\d+(?:\.\d+)?)$/);
  if (released) {
    return {
      platformId,
      apiLevel: Math.floor(Number(released[1]) || 0),
      stable: false,
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
  ensureEmulatorAdvancedFeaturesFile();
  const sdkRoot = activeAndroidSdkRoot();
  const base = {
    ...process.env,
    ANDROID_HOME: sdkRoot,
    ANDROID_SDK_ROOT: sdkRoot,
    ANDROID_EMULATOR_HOME: EMULATOR_HOME,
    ANDROID_USER_HOME: EMULATOR_HOME,
    ANDROID_AVD_HOME: AVD_HOME,
    AVD_HOME,
    JAVA_TOOL_OPTIONS: process.env.JAVA_TOOL_OPTIONS || '-Xint',
  };
  const pathParts = [
    path.join(sdkRoot, 'platform-tools'),
    path.join(sdkRoot, 'emulator'),
    path.join(sdkRoot, 'cmdline-tools', 'latest', 'bin'),
    process.env.PATH || '',
  ].filter(Boolean);
  base.PATH = pathParts.join(path.delimiter);
  return base;
}

function systemAdbBinary() {
  if (process.platform === 'win32') return null;
  return '/usr/bin/adb';
}

function hostAdbBinary() {
  const probe = spawnSync('bash', ['-lc', 'command -v adb'], { encoding: 'utf8' });
  if (probe.status !== 0) {
    return null;
  }
  const binary = String(probe.stdout || '').trim();
  return binary && isExecutable(binary) ? binary : null;
}

function hostAndroidSdkRoot() {
  const adb = hostAdbBinary();
  if (!adb) {
    return null;
  }

  const root = path.dirname(path.dirname(adb));
  const sdkmanager = path.join(root, 'cmdline-tools', 'latest', 'bin', process.platform === 'win32' ? 'sdkmanager.bat' : 'sdkmanager');
  const avdmanager = path.join(root, 'cmdline-tools', 'latest', 'bin', process.platform === 'win32' ? 'avdmanager.bat' : 'avdmanager');
  const emulator = path.join(root, 'emulator', process.platform === 'win32' ? 'emulator.exe' : 'emulator');
  if (isExecutable(sdkmanager) && isExecutable(avdmanager) && isExecutable(emulator)) {
    return root;
  }

  return null;
}

const SHARED_ANDROID_SDK_ROOT = hostAndroidSdkRoot();

function activeAndroidSdkRoot() {
  return SHARED_ANDROID_SDK_ROOT || SDK_ROOT;
}

function sharedAndroidSdkReady() {
  if (!SHARED_ANDROID_SDK_ROOT) {
    return false;
  }
  const adb = path.join(SHARED_ANDROID_SDK_ROOT, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb');
  const sdkmanager = path.join(SHARED_ANDROID_SDK_ROOT, 'cmdline-tools', 'latest', 'bin', process.platform === 'win32' ? 'sdkmanager.bat' : 'sdkmanager');
  const avdmanager = path.join(SHARED_ANDROID_SDK_ROOT, 'cmdline-tools', 'latest', 'bin', process.platform === 'win32' ? 'avdmanager.bat' : 'avdmanager');
  const emulator = path.join(SHARED_ANDROID_SDK_ROOT, 'emulator', process.platform === 'win32' ? 'emulator.exe' : 'emulator');
  return [adb, sdkmanager, avdmanager, emulator].every(isExecutable);
}

function adbBinary() {
  if (process.env.ANDROID_ADB_PATH) {
    return process.env.ANDROID_ADB_PATH;
  }
  if (SHARED_ANDROID_SDK_ROOT) {
    const sharedAdb = path.join(SHARED_ANDROID_SDK_ROOT, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb');
    if (isExecutable(sharedAdb)) {
      return sharedAdb;
    }
  }
  const hostAdb = hostAdbBinary();
  if (hostAdb) {
    return hostAdb;
  }
  const distroAdb = systemAdbBinary();
  if (process.platform === 'linux' && process.arch === 'arm64' && distroAdb && isExecutable(distroAdb)) {
    return distroAdb;
  }
  return path.join(SDK_ROOT, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb');
}

function sdkManagerBinary() {
  return path.join(activeAndroidSdkRoot(), 'cmdline-tools', 'latest', 'bin', process.platform === 'win32' ? 'sdkmanager.bat' : 'sdkmanager');
}

function avdManagerBinary() {
  return path.join(activeAndroidSdkRoot(), 'cmdline-tools', 'latest', 'bin', process.platform === 'win32' ? 'avdmanager.bat' : 'avdmanager');
}

function emulatorBinary() {
  return path.join(activeAndroidSdkRoot(), 'emulator', process.platform === 'win32' ? 'emulator.exe' : 'emulator');
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
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  const curlBin = process.platform === 'win32' ? 'curl.exe' : 'curl';
  if (commandExists(curlBin)) {
    const curlResult = spawnSync(curlBin, [
      '--fail',
      '--location',
      '--silent',
      '--show-error',
      '--retry', '3',
      '--retry-delay', '2',
      '--output', dest,
      url,
    ], {
      encoding: 'utf8',
      stdio: ['ignore', 'ignore', 'inherit'],
    });
    if (curlResult.status === 0) {
      return waitForReadyFile(dest);
    }
    const detail = String(curlResult.stderr || curlResult.stdout || curlResult.error?.message || `curl exited with code ${curlResult.status ?? 'unknown'}`).trim();
    console.warn(`[Android] curl download failed for ${url}; falling back to Node HTTPS (${detail || 'no detail'})`);
  }

  return downloadFileViaHttps(url, dest);
}

async function waitForReadyFile(filePath, timeoutMs = 600000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const stats = fs.statSync(filePath);
      if (stats.isFile() && stats.size > 0) {
        return;
      }
    } catch {}
    await sleep(250);
  }
  throw new Error(`Downloaded file was not ready at ${filePath}`);
}

function downloadFileViaHttps(url, dest) {
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
        reject(new Error(`Download failed for ${url} with status ${res.statusCode}`));
        return;
      }
      res.pipe(out);
      out.on('finish', () => out.close((closeErr) => {
        if (closeErr) {
          reject(closeErr);
          return;
        }
        resolve(waitForReadyFile(dest));
      }));
    }).on('error', (err) => {
      out.close();
      fs.rmSync(dest, { force: true });
      reject(new Error(`Download failed for ${url}: ${err.message}`));
    });
  });
}

function extractZip(zipPath, destDir) {
  if (process.platform === 'darwin' && commandExists('ditto')) {
    const res = spawnSync('ditto', ['-x', '-k', zipPath, destDir], { encoding: 'utf8' });
    if (res.status === 0) return;
    console.warn(`[Android] ditto failed for ${zipPath}; falling back to unzip`);
  }

  if (commandExists('unzip')) {
    const res = spawnSync('unzip', ['-qo', zipPath, '-d', destDir], { encoding: 'utf8' });
    if (res.status === 0) return;
    throw new Error(res.stderr || `unzip failed for ${zipPath}`);
  }

  throw new Error('Neither unzip nor ditto is available to extract Android SDK archives');
}

function clearQuarantineAttribute(targetPath) {
  if (process.platform !== 'darwin' || !commandExists('xattr')) {
    return;
  }
  spawnSync('xattr', ['-dr', 'com.apple.quarantine', targetPath], { encoding: 'utf8' });
}

function codesignAdHoc(targetPath) {
  if (process.platform !== 'darwin' || !commandExists('codesign')) {
    return;
  }
  spawnSync('codesign', ['--force', '--deep', '--sign', '-', targetPath], { encoding: 'utf8' });
}

function listFilesRecursive(rootDir, predicate, bucket = []) {
  for (const entry of fs.readdirSync(rootDir, { withFileTypes: true })) {
    const fullPath = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      listFilesRecursive(fullPath, predicate, bucket);
      continue;
    }
    if (!predicate || predicate(fullPath, entry)) {
      bucket.push(fullPath);
    }
  }
  return bucket;
}

function resolveBundleInstallTargets(bundleDir) {
  const apkFiles = listFilesRecursive(bundleDir, (filePath) => path.extname(filePath).toLowerCase() === '.apk')
    .sort((a, b) => a.localeCompare(b));
  if (apkFiles.length === 0) {
    throw new Error('APK bundle did not contain any installable .apk files.');
  }

  const universalApk = apkFiles.find((filePath) => path.basename(filePath).toLowerCase() === 'universal.apk');
  if (universalApk) {
    return {
      mode: 'single',
      installPaths: [universalApk],
      layout: 'universal',
    };
  }

  if (apkFiles.length === 1) {
    return {
      mode: 'single',
      installPaths: apkFiles,
      layout: 'single-apk',
    };
  }

  throw new Error(
    'APK bundles must include a universal APK. Export a universal .apks bundle or upload a single .apk instead.'
  );
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

function parseLatestEmulatorUrl(xml) {
  const tag = platformTag() === 'mac' ? 'macosx' : 'linux';
  const hostArch = emulatorHostArch();
  const packageMatch = xml.match(new RegExp(`<remotePackage\\s+path="emulator">([\\s\\S]*?)<\\/remotePackage>`));
  if (!packageMatch) throw new Error('Could not locate emulator in Android repository metadata');

  const archiveBlocks = packageMatch[1].match(/<archive>[\s\S]*?<\/archive>/g) || [];
  for (const block of archiveBlocks) {
    if (!new RegExp(`<host-os>${tag}<\\/host-os>`).test(block)) continue;
    if (!new RegExp(`<host-arch>${hostArch}<\\/host-arch>`).test(block)) continue;
    const urlMatch = block.match(/<url>\s*([^<]*emulator-[^<]+\.zip)\s*<\/url>/);
    if (urlMatch) return `https://dl.google.com/android/repository/${urlMatch[1]}`;
  }

  throw new Error(`Could not find an Android emulator archive for ${tag}`);
}

function findDirectoryContainingFiles(rootDir, requiredFiles) {
  const stack = [rootDir];
  while (stack.length > 0) {
    const dir = stack.pop();
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      continue;
    }
    const names = new Set(entries.map((entry) => entry.name));
    if (requiredFiles.every((name) => names.has(name))) {
      return dir;
    }
    for (const entry of entries) {
      if (entry.isDirectory()) {
        stack.push(path.join(dir, entry.name));
      }
    }
  }
  return null;
}

function parseLatestPlatformToolsUrl(xml) {
  const tag = platformTag() === 'mac' ? 'macosx' : 'linux';
  const packageMatch = xml.match(new RegExp(`<remotePackage\\s+path="platform-tools">([\\s\\S]*?)<\\/remotePackage>`));
  if (!packageMatch) throw new Error('Could not locate platform-tools in Android repository metadata');

  const archiveBlocks = packageMatch[1].match(/<archive>[\s\S]*?<\/archive>/g) || [];
  for (const block of archiveBlocks) {
    if (!new RegExp(`<host-os>${tag}<\\/host-os>`).test(block)) continue;
    const urlMatch = block.match(/<url>\s*([^<]*platform-tools[^<]+\.zip)\s*<\/url>/);
    if (urlMatch) return `https://dl.google.com/android/repository/${urlMatch[1]}`;
  }

  throw new Error(`Could not find a platform-tools archive for ${tag}`);
}

function parseRepositorySystemImages(xml) {
  const matches = [];
  const regex = /<remotePackage\s+path="(system-images;[^"]+)">/g;
  let match = regex.exec(xml);
  while (match) {
    matches.push({
      packageName: match[1],
      platformId: match[1].split(';')[1] || '',
      tag: match[1].split(';')[2] || '',
      arch: match[1].split(';')[3] || '',
    });
    match = regex.exec(xml);
  }
  return parseSystemImageCandidates(matches);
}

function parseLatestSystemImageUrl(xml, packageName) {
  const packageMatch = xml.match(new RegExp(`<remotePackage\\s+path="${packageName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}">([\\s\\S]*?)<\\/remotePackage>`));
  if (!packageMatch) throw new Error(`Could not locate ${packageName} in Android repository metadata`);

  const archiveBlocks = packageMatch[1].match(/<archive>[\s\S]*?<\/archive>/g) || [];
  for (const block of archiveBlocks) {
    const urlMatch = block.match(/<url>\s*([^<]*\.zip)\s*<\/url>/);
    if (urlMatch) {
      const urlPart = urlMatch[1];
      if (urlPart.startsWith('http')) return urlPart;
      return `https://dl.google.com/android/repository/sys-img/android/${urlPart}`;
    }
  }

  throw new Error(`Could not find a system image archive for ${packageName}`);
}

async function fetchEmulatorMetadata() {
  const urls = [
    'https://dl.google.com/android/repository/repository2-3.xml',
    'https://dl.google.com/android/repository/repository2-1.xml',
  ];
  let lastError = null;
  for (const url of urls) {
    try {
      return await fetchText(url);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError || new Error('Could not fetch Android emulator repository metadata');
}

async function installEmulatorArchive(metadata) {
  const url = parseLatestEmulatorUrl(metadata);
  const zipPath = path.join(TMP_DIR, path.basename(url));
  const installDir = path.join(activeAndroidSdkRoot(), 'emulator');

  await downloadFile(url, zipPath);
  fs.rmSync(installDir, { recursive: true, force: true });
  extractZip(zipPath, activeAndroidSdkRoot());

  const extractedRoot = findDirectoryContainingFiles(installDir, [
    process.platform === 'win32' ? 'emulator.exe' : 'emulator',
  ]);
  if (!extractedRoot) {
    throw new Error('Downloaded Android emulator archive did not contain an emulator binary');
  }
  clearQuarantineAttribute(installDir);
  codesignAdHoc(installDir);

  fs.rmSync(zipPath, { force: true });
}

async function installPlatformToolsArchive(metadata) {
  const url = parseLatestPlatformToolsUrl(metadata);
  const zipPath = path.join(TMP_DIR, path.basename(url));
  const installDir = path.join(activeAndroidSdkRoot(), 'platform-tools');

  await downloadFile(url, zipPath);
  fs.rmSync(installDir, { recursive: true, force: true });
  extractZip(zipPath, activeAndroidSdkRoot());

  const extractedRoot = findDirectoryContainingFiles(installDir, [
    process.platform === 'win32' ? 'adb.exe' : 'adb',
  ]);
  if (!extractedRoot) {
    throw new Error('Downloaded platform-tools archive did not contain adb');
  }

  fs.rmSync(zipPath, { force: true });
}

function shouldInstallPlatformToolsArchive() {
  if (SHARED_ANDROID_SDK_ROOT) {
    return false;
  }
  if (hostAdbBinary()) {
    return false;
  }
  const distroAdb = systemAdbBinary();
  if (process.platform === 'linux' && process.arch === 'arm64' && distroAdb && isExecutable(distroAdb)) {
    return false;
  }
  return true;
}

async function installSystemImageArchive(metadata, packageName) {
  const url = parseLatestSystemImageUrl(metadata, packageName);
  const zipPath = path.join(TMP_DIR, path.basename(url));
  const targetRoot = path.join(activeAndroidSdkRoot(), ...String(packageName).split(';').filter(Boolean));
  const extractDir = fs.mkdtempSync(path.join(TMP_DIR, 'system-image-'));

  try {
    fs.rmSync(targetRoot, { recursive: true, force: true });
    fs.mkdirSync(path.dirname(targetRoot), { recursive: true });
    await downloadFile(url, zipPath);
    extractZip(zipPath, extractDir);

    const extractedRoot = findDirectoryContainingFiles(extractDir, ['userdata.img']) ||
      findDirectoryContainingFiles(extractDir, ['system.img']) ||
      findDirectoryContainingFiles(extractDir, ['package.xml']);
    if (!extractedRoot) {
      throw new Error(`Downloaded Android system image archive for ${packageName} did not contain the expected files`);
    }

    fs.rmSync(zipPath, { force: true });
    try {
      fs.renameSync(extractedRoot, targetRoot);
    } catch (renameErr) {
      fs.cpSync(extractedRoot, targetRoot, { recursive: true, force: true });
      if (renameErr) {
        console.warn(`[Android] Falling back to copy for ${packageName}: ${renameErr.message}`);
      }
    }
  } finally {
    fs.rmSync(zipPath, { force: true });
    fs.rmSync(extractDir, { recursive: true, force: true });
  }
}

function systemImageTagScore(tag) {
  const value = String(tag || '').toLowerCase();
  if (value.startsWith('google_apis_playstore')) return 80;
  if (value.startsWith('google_apis')) return 60;
  if (value === 'default') return 40;
  if (value === 'google_atd') return 20;
  if (value === 'aosp_atd') return 10;
  return 0;
}

function parseSystemImageCandidates(entries = []) {
  return entries.map((entry) => {
    const platform = parseSystemImagePlatform(entry.platformId);
    return {
      packageName: entry.packageName,
      platformId: entry.platformId,
      tag: entry.tag,
      arch: entry.arch,
      apiLevel: platform.apiLevel,
      stable: platform.stable,
      tagScore: systemImageTagScore(entry.tag),
    };
  });
}

function parseSystemImages(listOutput) {
  const matches = [];
  const regex = /system-images;(android-[^;\s]+);([^;\s]+);([^;\s]+)/g;
  let match = regex.exec(listOutput);
  while (match) {
    matches.push({
      packageName: match[0],
      platformId: match[1],
      tag: match[2],
      arch: match[3],
    });
    match = regex.exec(listOutput);
  }

  return parseSystemImageCandidates(matches);
}

function parseInstalledSystemImages() {
  const root = path.join(activeAndroidSdkRoot(), 'system-images');
  if (!fs.existsSync(root)) {
    return [];
  }

  const matches = [];
  const platforms = fs.readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name);

  for (const platformId of platforms) {
    const platformDir = path.join(root, platformId);
    const tags = fs.readdirSync(platformDir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
    for (const tag of tags) {
      const tagDir = path.join(platformDir, tag);
      const archs = fs.readdirSync(tagDir, { withFileTypes: true })
        .filter((entry) => entry.isDirectory())
        .map((entry) => entry.name);
      for (const arch of archs) {
        const packageXml = path.join(tagDir, arch, 'package.xml');
        if (!fs.existsSync(packageXml)) {
          continue;
        }
        matches.push({
          packageName: `system-images;${platformId};${tag};${arch}`,
          platformId,
          tag,
          arch,
        });
      }
    }
  }

  return parseSystemImageCandidates(matches);
}

function rankSystemImagePool(pool) {
  const preferredMatches = pool.filter((candidate) => candidate.tagScore > 0);
  const rankedPool = preferredMatches.length > 0 ? preferredMatches : pool;
  const preferLowerApiOnAppleSilicon = process.platform === 'darwin' && process.arch === 'arm64';

  rankedPool.sort((a, b) =>
    Number(b.stable) - Number(a.stable) ||
    b.tagScore - a.tagScore ||
    (preferLowerApiOnAppleSilicon ? (a.apiLevel - b.apiLevel) : (b.apiLevel - a.apiLevel)) ||
    a.packageName.localeCompare(b.packageName)
  );

  return rankedPool;
}

function chooseConfiguredSystemImage(listOutput) {
  const matches = Array.isArray(listOutput)
    ? parseSystemImageCandidates(listOutput)
    : parseSystemImages(listOutput);
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
  const matches = Array.isArray(listOutput)
    ? parseSystemImageCandidates(listOutput)
    : parseSystemImages(listOutput);
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
  const candidates = Array.isArray(listOutput)
    ? parseSystemImageCandidates(listOutput)
    : parseSystemImages(listOutput);
  const availableArchs = [...new Set(candidates.map((candidate) => candidate.arch))].sort();
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

function readIniValue(content, key) {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = content.match(new RegExp(`^${escapedKey}=(.*)$`, 'm'));
  return match ? String(match[1] || '').trim() : null;
}

function systemImagePackageToRelativeDir(packageName) {
  const parts = String(packageName || '').split(';').filter(Boolean);
  if (parts.length !== 4 || parts[0] !== 'system-images') {
    return null;
  }
  return `${parts.join('/')}/`;
}

function systemImagePackageToAbi(packageName) {
  const parts = String(packageName || '').split(';').filter(Boolean);
  if (parts.length !== 4 || parts[0] !== 'system-images') {
    return null;
  }
  return parts[3] || null;
}

function abiToCpuArch(abi) {
  const value = String(abi || '').trim().toLowerCase();
  if (value === 'arm64-v8a') return 'arm64';
  if (value === 'armeabi-v7a' || value === 'armeabi') return 'arm';
  if (value === 'x86_64') return 'x86_64';
  if (value === 'x86') return 'x86';
  return null;
}

function systemImagePackageToCpuArch(packageName) {
  return abiToCpuArch(systemImagePackageToAbi(packageName));
}

function describeAutoFixChanges(current, next, fields = []) {
  return fields
    .map((field) => {
      const before = current?.[field] ?? null;
      const after = next?.[field] ?? null;
      if (before === after) return null;
      return `${field}: ${before ?? 'null'} -> ${after ?? 'null'}`;
    })
    .filter(Boolean)
    .join(', ');
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
  constructor(options = {}) {
    this.io = options?.io;
    this.userId = options?.userId != null ? String(options.userId) : null;
    this.artifactStore = options?.artifactStore || null;
    this.runtimeBackend = options?.runtimeBackend || 'host';
    this.scopeKey = sanitizeScopeKey(this.userId ? `user-${this.userId}` : 'default');
    this.ownerKey = normalizeOwnerKey(this.userId);
    this.stateFile = resolveStateFile(this.scopeKey);
    this.cli = new CLIExecutor();
    const state = this.#readState();
    const desiredArchTag = sanitizeScopeKey(systemImageArch());
    const stateMatchesArch = state?.systemImageArch === systemImageArch() && String(state?.avdName || '').includes(desiredArchTag);
    this.previousAvdName = String(state?.avdName || '').trim() || null;
    this.avdName = stateMatchesArch
      ? state.avdName
      : `neoagent-${this.scopeKey}-${desiredArchTag}`;
    if (this.previousAvdName !== this.avdName) {
      this.#appendState({
        avdName: this.avdName,
        serial: null,
        emulatorPid: null,
        starting: false,
        startupPhase: null,
        lastStartError: null,
        lastLogLine: null,
      });
    }
    if (String(state?.systemImageArch || '').trim() && state.systemImageArch !== systemImageArch()) {
      this.#appendState({
        serial: null,
        emulatorPid: null,
        bootstrapped: false,
        systemImage: null,
        apiLevel: null,
        systemImageArch: null,
        avdSystemImage: null,
        starting: false,
        startupPhase: null,
        lastStartError: null,
        lastLogLine: null,
      });
    }
    this.bootstrapPromise = null;
    this.startPromise = null;
    this.#registerProcessCleanup();
  }

  static cleanupRegistered = false;
  static cleanupControllers = new Set();

  #readState() {
    return readState(this.stateFile);
  }

  #appendState(patch) {
    return appendState(patch, this.stateFile);
  }

  #readOwnership() {
    return readOwnership();
  }

  #writeOwnership(nextOwners) {
    writeOwnership(nextOwners);
  }

  #releaseSerialOwnership(serial) {
    const normalizedSerial = String(serial || '').trim();
    if (!normalizedSerial) return;
    withOwnershipLock(() => {
      const owners = readOwnershipUnlocked();
      const current = owners[normalizedSerial];
      if (!current || current.ownerKey !== this.ownerKey) {
        return;
      }

      delete owners[normalizedSerial];
      writeOwnershipUnlocked(owners);
    });
  }

  #claimSerial(serial) {
    const normalizedSerial = String(serial || '').trim();
    if (!normalizedSerial) {
      throw new Error('Cannot claim an empty Android serial.');
    }

    withOwnershipLock(() => {
      const owners = readOwnershipUnlocked();
      const existing = owners[normalizedSerial];
      if (existing && existing.ownerKey && existing.ownerKey !== this.ownerKey) {
        throw new Error(`Android device ${normalizedSerial} is currently reserved by another user.`);
      }

      owners[normalizedSerial] = {
        ownerKey: this.ownerKey,
        ownerUserId: this.userId,
        updatedAt: new Date().toISOString(),
      };
      writeOwnershipUnlocked(owners);
    });
  }

  #isSerialOwnedByAnother(serial, owners = null) {
    const normalizedSerial = String(serial || '').trim();
    if (!normalizedSerial) return false;
    const effectiveOwners = owners || this.#readOwnership();
    const existing = effectiveOwners[normalizedSerial];
    return Boolean(existing?.ownerKey && existing.ownerKey !== this.ownerKey);
  }

  #assertSerialAccess(serial, options = {}) {
    const normalizedSerial = String(serial || '').trim();
    if (!normalizedSerial) {
      throw new Error('Android serial is required.');
    }

    const claimIfUnowned = options.claimIfUnowned !== false;
    withOwnershipLock(() => {
      const owners = readOwnershipUnlocked();
      const existing = owners[normalizedSerial];

      if (existing?.ownerKey && existing.ownerKey !== this.ownerKey) {
        throw new Error(`Android device ${normalizedSerial} is currently reserved by another user.`);
      }

      if (claimIfUnowned) {
        owners[normalizedSerial] = {
          ownerKey: this.ownerKey,
          ownerUserId: this.userId,
          updatedAt: new Date().toISOString(),
        };
        writeOwnershipUnlocked(owners);
      }
    });
  }

  #pruneOwnership(devices = []) {
    withOwnershipLock(() => {
      const owners = readOwnershipUnlocked();
      const { next, changed } = pruneOwnershipByDevices(owners, devices);
      if (changed) {
        writeOwnershipUnlocked(next);
      }
    });
  }

  #registerProcessCleanup() {
    AndroidController.cleanupControllers.add(this);
    if (AndroidController.cleanupRegistered) {
      return;
    }
    AndroidController.cleanupRegistered = true;

    const cleanup = () => {
      for (const controller of AndroidController.cleanupControllers) {
        try {
          controller.#stopTrackedEmulatorSync();
        } catch {}
      }
    };

    process.once('exit', cleanup);
    process.once('uncaughtException', cleanup);
    process.once('unhandledRejection', cleanup);
  }

  async #terminateStaleEmulatorProcesses(names = [this.avdName]) {
    const avdNames = [...new Set((Array.isArray(names) ? names : [names]).map((name) => String(name || '').trim()).filter(Boolean))];
    const pids = [];
    for (const avdName of avdNames) {
      const probe = spawnSync('pgrep', ['-f', `@${avdName}`], { encoding: 'utf8' });
      if (probe.status !== 0) {
        continue;
      }
      const found = String(probe.stdout || '')
        .split(/\s+/)
        .map((pid) => Number(pid))
        .filter((pid) => Number.isInteger(pid) && pid > 0);
      pids.push(...found);
    }
    const uniquePids = [...new Set(pids)];
    if (uniquePids.length === 0) {
      return;
    }

    for (const pid of uniquePids) {
      try { process.kill(pid, 'SIGTERM'); } catch {}
    }

    await sleep(1500);

    for (const pid of uniquePids) {
      try {
        process.kill(pid, 0);
        process.kill(pid, 'SIGKILL');
      } catch {}
    }
  }

  #stopTrackedEmulatorSync() {
    const state = this.#readState();
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

    this.#releaseSerialOwnership(serial);
    this.#appendState({ serial: null, emulatorPid: null });
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
    const desiredArch = systemImageArch();
    const state = this.#readState();
    const installedImages = parseInstalledSystemImages();
    const preferredInstalled =
      chooseConfiguredSystemImage(installedImages) ||
      chooseLatestSystemImage(installedImages, [desiredArch]) ||
      chooseLatestSystemImage(installedImages);
    const systemImageMetadata = await fetchText('https://dl.google.com/android/repository/sys-img/android/sys-img2-1.xml');
    const available = parseRepositorySystemImages(systemImageMetadata);
    const preferredAvailable =
      chooseConfiguredSystemImage(available) ||
      chooseLatestSystemImage(available, [desiredArch]) ||
      chooseLatestSystemImage(available);
    const selectedImage = rankSystemImagePool([preferredInstalled, preferredAvailable].filter(Boolean))[0] || preferredInstalled || preferredAvailable;
    const stateApiLevel = Number(state.apiLevel || 0) || 0;

    if (!shouldForceSdkRefresh() && sharedAndroidSdkReady() && selectedImage) {
      const stateAligned =
        selectedImage.packageName === state.systemImage &&
        selectedImage.apiLevel === stateApiLevel &&
        selectedImage.arch === state.systemImageArch &&
        state.avdName === this.avdName;

      if (stateAligned) {
        return;
      }

      if (selectedImage === preferredInstalled && selectedImage.packageName) {
        const changeSummary = describeAutoFixChanges(
          {
            avdName: state.avdName || null,
            systemImage: state.systemImage || null,
            apiLevel: stateApiLevel || null,
            systemImageArch: state.systemImageArch || null,
          },
          {
            avdName: this.avdName,
            systemImage: selectedImage.packageName,
            apiLevel: selectedImage.apiLevel,
            systemImageArch: selectedImage.arch,
          },
          ['avdName', 'systemImage', 'apiLevel', 'systemImageArch']
        );
        if (changeSummary) {
          console.log(`[Android] Auto-fixed host SDK state (${changeSummary})`);
        }
        this.#appendState({
          bootstrapped: true,
          avdName: this.avdName,
          serial: null,
          emulatorPid: null,
          systemImage: selectedImage.packageName,
          apiLevel: selectedImage.apiLevel,
          systemImageArch: selectedImage.arch,
        });
        return;
      }
    }

    const binariesReady =
      isExecutable(adbBinary()) &&
      isExecutable(emulatorBinary()) &&
      installedEmulatorMatchesHost();
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

    const runtimeNeedsRefresh =
      state.systemImageArch !== desiredArch ||
      !installedEmulatorMatchesHost();
    if (!shouldForceSdkRefresh()) {
      if (!runtimeNeedsRefresh && selectedImage && selectedImage === preferredInstalled) {
        const stateNeedsRefresh =
          selectedImage.packageName !== state.systemImage ||
          selectedImage.apiLevel !== stateApiLevel ||
          selectedImage.arch !== state.systemImageArch ||
          state.avdName !== this.avdName;
        if (stateNeedsRefresh) {
          const changeSummary = describeAutoFixChanges(
            {
              avdName: state.avdName || null,
              systemImage: state.systemImage || null,
              apiLevel: stateApiLevel || null,
              systemImageArch: state.systemImageArch || null,
            },
            {
              avdName: this.avdName,
              systemImage: selectedImage.packageName,
              apiLevel: selectedImage.apiLevel,
              systemImageArch: selectedImage.arch,
            },
            ['avdName', 'systemImage', 'apiLevel', 'systemImageArch']
          );
          if (changeSummary) {
            console.log(`[Android] Auto-fixed preferred system image (${changeSummary})`);
          }
          this.#appendState({
            bootstrapped: true,
            avdName: this.avdName,
            serial: null,
            emulatorPid: null,
            systemImage: selectedImage.packageName,
            apiLevel: selectedImage.apiLevel,
            systemImageArch: selectedImage.arch,
          });
        }
        return;
      }
      if (
        !runtimeNeedsRefresh &&
        state.bootstrapped === true &&
        state.systemImage &&
        selectedImage &&
        selectedImage.packageName === state.systemImage
      ) {
        return;
      }
    }

    this.#appendState({ bootstrapped: true });
    const metadata = await fetchEmulatorMetadata();
    if (shouldInstallPlatformToolsArchive()) {
      await installPlatformToolsArchive(metadata);
    }
    await installEmulatorArchive(metadata);
    if (!selectedImage) {
      throw new Error(formatSystemImageError(available));
    }
    if (selectedImage?.packageName) {
      await installSystemImageArchive(systemImageMetadata, selectedImage.packageName);
    }
    this.#appendState({
      bootstrapped: true,
      avdName: this.avdName,
      systemImage: selectedImage.packageName,
      apiLevel: selectedImage.apiLevel,
      systemImageArch: selectedImage.arch,
    });
  }

  async #bootstrapRuntime() {
    const metadata = await fetchEmulatorMetadata();
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
    if (shouldInstallPlatformToolsArchive()) {
      await installPlatformToolsArchive(metadata);
    }
    await installEmulatorArchive(metadata);

    const systemImageMetadata = await fetchText('https://dl.google.com/android/repository/sys-img/android/sys-img2-1.xml');
    const available = parseRepositorySystemImages(systemImageMetadata);
    const systemImage = chooseConfiguredSystemImage(available) || chooseLatestSystemImage(available);
    if (!systemImage) throw new Error(formatSystemImageError(available));

    await installSystemImageArchive(systemImageMetadata, systemImage.packageName);
    this.#appendState({
      bootstrapped: true,
      systemImage: systemImage.packageName,
      apiLevel: systemImage.apiLevel,
      systemImageArch: systemImage.arch,
    });
  }

  async bootstrapEmulator(options = {}) {
    return this.#startEmulatorBlocking(options);
  }

  markBootstrapFailure(error) {
    const state = this.#readState();
    const recentLogLines = state.logPath ? tailFile(state.logPath, 12) : [];
    const detailedMessage = recentLogLines[recentLogLines.length - 1] || error?.message || String(error || 'Android bootstrap failed.');
    this.#appendState({
      starting: false,
      startupPhase: 'Start failed',
      lastStartError: detailedMessage,
      lastLogLine: detailedMessage,
    });
    return detailedMessage;
  }

  async ensureAvd() {
    await this.ensureBootstrapped();

    const state = this.#readState();
    const pkg = state.systemImage;
    if (!pkg) throw new Error('Android system image not installed');
    const avdDir = path.join(AVD_HOME, `${this.avdName}.avd`);
    const configPath = path.join(avdDir, 'config.ini');
    const avdExists = fs.existsSync(configPath);
    let avdNeedsRecreate = avdExists && (!state.avdSystemImage || state.avdSystemImage !== pkg);
    const avdRecreateReasons = [];
    if (avdNeedsRecreate && state.avdSystemImage !== pkg) {
      avdRecreateReasons.push(`systemImage: ${state.avdSystemImage || 'null'} -> ${pkg}`);
    }
    if (avdExists && fs.existsSync(configPath)) {
      try {
        const config = fs.readFileSync(configPath, 'utf8');
        const currentImageDir = readIniValue(config, 'image.sysdir.1');
        const expectedImageDir = systemImagePackageToRelativeDir(pkg);
        const currentAbi = readIniValue(config, 'abi.type');
        const expectedAbi = systemImagePackageToAbi(pkg);
        const currentCpuArch = readIniValue(config, 'hw.cpu.arch');
        const expectedCpuArch = systemImagePackageToCpuArch(pkg);
        const currentDataPartitionSize = readIniValue(config, 'disk.dataPartition.size');
        const expectedDataPartitionSize = String(DEFAULT_DATA_PARTITION_BYTES);
        const currentSdcardSize = readIniValue(config, 'sdcard.size');
        const expectedSdcardSize = String(DEFAULT_SDCARD_SIZE_BYTES);
        const currentRamSize = readIniValue(config, 'hw.ramSize');
        const expectedRamSize = String(DEFAULT_RAM_SIZE_MB);
        const currentGpuMode = readIniValue(config, 'hw.gpu.mode');
        const expectedGpuMode = emulatorGpuMode();
        const currentPlayStoreEnabled = readIniValue(config, 'PlayStore.enabled');
        const expectedPlayStoreEnabled = String(String(pkg || '').includes('playstore'));
        if (expectedImageDir && currentImageDir && currentImageDir !== expectedImageDir) {
          avdNeedsRecreate = true;
          avdRecreateReasons.push(`image.sysdir.1: ${currentImageDir} -> ${expectedImageDir}`);
        }
        if (expectedAbi && currentAbi && currentAbi !== expectedAbi) {
          avdNeedsRecreate = true;
          avdRecreateReasons.push(`abi.type: ${currentAbi} -> ${expectedAbi}`);
        }
        if (expectedCpuArch && currentCpuArch && currentCpuArch !== expectedCpuArch) {
          avdNeedsRecreate = true;
          avdRecreateReasons.push(`hw.cpu.arch: ${currentCpuArch} -> ${expectedCpuArch}`);
        }
        if (currentDataPartitionSize && currentDataPartitionSize !== expectedDataPartitionSize) {
          avdNeedsRecreate = true;
          avdRecreateReasons.push(`disk.dataPartition.size: ${currentDataPartitionSize} -> ${expectedDataPartitionSize}`);
        }
        if (currentSdcardSize && currentSdcardSize !== expectedSdcardSize) {
          avdNeedsRecreate = true;
          avdRecreateReasons.push(`sdcard.size: ${currentSdcardSize} -> ${expectedSdcardSize}`);
        }
        if (currentRamSize && currentRamSize !== expectedRamSize) {
          avdNeedsRecreate = true;
          avdRecreateReasons.push(`hw.ramSize: ${currentRamSize} -> ${expectedRamSize}`);
        }
        if (currentGpuMode && currentGpuMode !== expectedGpuMode) {
          avdNeedsRecreate = true;
          avdRecreateReasons.push(`hw.gpu.mode: ${currentGpuMode} -> ${expectedGpuMode}`);
        }
        if (currentPlayStoreEnabled && currentPlayStoreEnabled !== expectedPlayStoreEnabled) {
          avdNeedsRecreate = true;
          avdRecreateReasons.push(`PlayStore.enabled: ${currentPlayStoreEnabled} -> ${expectedPlayStoreEnabled}`);
        }
      } catch {}
    }

    if (avdNeedsRecreate) {
      if (avdRecreateReasons.length > 0) {
        console.log(`[Android] Recreating AVD to repair config mismatch (${avdRecreateReasons.join(', ')})`);
      }
      await this.stopEmulator().catch(() => {});
      fs.rmSync(avdDir, { recursive: true, force: true });
      fs.rmSync(path.join(AVD_HOME, `${this.avdName}.ini`), { force: true });
      fs.rmSync(path.join(avdDir, 'userdata-qemu.img'), { force: true });
    } else if (avdExists) {
      ensureSparseFile(path.join(avdDir, 'userdata-qemu.img'), DEFAULT_DATA_PARTITION_BYTES);
      return;
    }

    this.#writeAvdFiles(pkg);
    this.#normalizeAvdConfig();
    this.#appendState({ avdSystemImage: pkg });
  }

  #writeAvdFiles(packageName) {
    const parts = String(packageName || '').split(';').filter(Boolean);
    if (parts.length !== 4 || parts[0] !== 'system-images') {
      throw new Error(`Invalid Android system image package: ${packageName}`);
    }
    const apiLevel = parts[1].replace(/^android-/, '');
    const tagId = parts[2];
    const tagDisplay = tagId === 'google_apis' ? 'Google APIs' : tagId.replace(/_/g, ' ');
    const abi = parts[3];
    const playStoreEnabled = tagId.includes('playstore');
    const avdDir = path.join(AVD_HOME, `${this.avdName}.avd`);
    const imageSysDir = systemImagePackageToRelativeDir(packageName);
    if (!imageSysDir) {
      throw new Error(`Invalid Android system image directory for package: ${packageName}`);
    }

    fs.mkdirSync(avdDir, { recursive: true });
    ensureSparseFile(path.join(avdDir, 'userdata-qemu.img'), DEFAULT_DATA_PARTITION_BYTES);
    fs.writeFileSync(
      path.join(AVD_HOME, `${this.avdName}.ini`),
      [
        'avd.ini.encoding=UTF-8',
        `path=${avdDir}`,
        `path.rel=avd/${this.avdName}.avd`,
        `target=android-${apiLevel}`,
        '',
      ].join('\n')
    );

    const configLines = [
      'avd.ini.encoding=UTF-8',
      `AvdId=${this.avdName}`,
      `avd.ini.displayname=${this.avdName}`,
      `PlayStore.enabled=${playStoreEnabled}`,
      `image.sysdir.1=${imageSysDir}`,
      `abi.type=${abi}`,
      `hw.cpu.arch=${systemImagePackageToCpuArch(packageName) || abi}`,
      'hw.cpu.ncore=2',
      'hw.dPad=no',
      'hw.gps=yes',
      'hw.gpu.enabled=yes',
      `hw.gpu.mode=${emulatorGpuMode()}`,
      'hw.initialOrientation=Portrait',
      'hw.keyboard=yes',
      'hw.lcd.density=440',
      'hw.lcd.height=1920',
      'hw.lcd.width=1080',
      'hw.mainKeys=no',
      `hw.ramSize=${DEFAULT_RAM_SIZE_MB}`,
      'hw.sensors.orientation=yes',
      'hw.sensors.proximity=yes',
      'hw.trackBall=no',
      `disk.dataPartition.size=${DEFAULT_DATA_PARTITION_BYTES}`,
      `sdcard.size=${DEFAULT_SDCARD_SIZE_BYTES}`,
      'runtime.network.latency=none',
      'runtime.network.speed=full',
      'vm.heapSize=256',
      `tag.display=${tagDisplay}`,
      `tag.id=${tagId}`,
      '',
    ];
    fs.writeFileSync(path.join(avdDir, 'config.ini'), configLines.join('\n'));

    const systemImageRoot = path.join(activeAndroidSdkRoot(), ...String(packageName).split(';').filter(Boolean));
    const userdataImage = path.join(systemImageRoot, 'userdata.img');
    if (fs.existsSync(userdataImage)) {
      fs.copyFileSync(userdataImage, path.join(avdDir, 'userdata.img'));
    }
  }

  #normalizeAvdConfig() {
    const configPath = path.join(AVD_HOME, `${this.avdName}.avd`, 'config.ini');
    if (!fs.existsSync(configPath)) return;

    let content = fs.readFileSync(configPath, 'utf8');
    content = updateIniValue(content, 'disk.dataPartition.size', DEFAULT_DATA_PARTITION_BYTES);
    content = updateIniValue(content, 'sdcard.size', DEFAULT_SDCARD_SIZE_BYTES);
    content = updateIniValue(content, 'hw.ramSize', DEFAULT_RAM_SIZE_MB);
    content = updateIniValue(content, 'hw.gpu.mode', emulatorGpuMode());
    content = updateIniValue(content, 'PlayStore.enabled', String(this.#readState()?.systemImage || '').includes('playstore'));
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
    const devices = lines
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
    this.#pruneOwnership(devices);
    return devices;
  }

  async getPrimarySerial(options = {}) {
    const state = this.#readState();
    const devices = await this.listDevices(options);
    const owners = this.#readOwnership();
    const canUse = (device) => device.status === 'device' && !this.#isSerialOwnedByAnother(device.serial, owners);

    const preferred = state.serial ? devices.find((device) => device.serial === state.serial && canUse(device)) : null;
    if (preferred) {
      this.#claimSerial(preferred.serial);
      return preferred.serial;
    }

    const emulator = devices.find((device) => device.emulator && canUse(device));
    if (emulator) {
      this.#claimSerial(emulator.serial);
      this.#appendState({ serial: emulator.serial });
      return emulator.serial;
    }

    const online = devices.find((device) => canUse(device));
    if (online) {
      this.#claimSerial(online.serial);
      this.#appendState({ serial: online.serial });
      return online.serial;
    }

    return null;
  }

  async #startEmulatorBlocking(options = {}) {
    this.#appendState({
      starting: true,
      startupPhase: 'Preparing Android runtime',
      lastStartError: null,
      startRequestedAt: this.#readState().startRequestedAt || new Date().toISOString(),
    });
    console.log('[Android] Preparing emulator start');
    await this.#terminateStaleEmulatorProcesses([this.avdName, this.previousAvdName]).catch(() => {});
    await this.ensureAvd();
    this.#appendState({
      starting: true,
      startupPhase: 'Checking for an existing Android device',
      lastStartError: null,
    });
    this.#normalizeAvdConfig();
    const serial = await this.getPrimarySerial();
    if (serial) {
      this.#appendState({
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
        bootstrapped: this.#readState().bootstrapped === true,
      };
    }

    const logPath = path.join(LOGS_DIR, `emulator-${Date.now()}.log`);
    const out = fs.openSync(logPath, 'a');
    const args = [
      `@${this.avdName}`,
      '-no-boot-anim',
      ...emulatorLaunchArgs(this.avdName),
      '-data',
      path.join(AVD_HOME, `${this.avdName}.avd`, 'userdata-qemu.img'),
      '-gpu',
      emulatorGpuMode(),
      '-accel',
      'auto',
      '-partition-size',
      String(DEFAULT_PARTITION_SIZE_MB),
      '-netdelay',
      'none',
      '-netspeed',
      'full',
    ];

    const child = spawn(emulatorBinary(), args, {
      detached: true,
      stdio: ['ignore', out, out],
      env: sdkEnv(),
    });

    console.log(`[Android] Emulator process started (pid ${child.pid})`);
    this.#appendState({
      emulatorPid: child.pid,
      avdName: this.avdName,
      logPath,
      starting: true,
      startupPhase: 'Waiting for Android emulator to boot',
      lastStartError: null,
      lastLogLine: 'Android emulator process started. Waiting for boot completion...',
    });
    child.unref();
    let onlineSerial;
    try {
      onlineSerial = await this.waitForDevice({ timeoutMs: options.timeoutMs || 600000 });
    } catch (error) {
      const recentLogLines = tailFile(logPath, 12);
      const lastLine =
        recentLogLines[recentLogLines.length - 1] ||
        error?.message ||
        String(error || 'Android emulator did not finish booting.');
      await this.stopEmulator().catch(() => {});
      this.markBootstrapFailure(lastLine);
      throw new Error(lastLine);
    }
    this.#appendState({
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
        throw new Error(this.#readState().lastStartError || 'Android emulator did not finish starting.');
      }
      return {
        success: true,
        serial,
        reused: false,
        bootstrapped: this.#readState().bootstrapped === true,
      };
    }

    return this.#startEmulatorBlocking(options);
  }

  async requestStartEmulator(options = {}) {
    const serial = await this.getPrimarySerial({ ensureBootstrapped: false }).catch(() => null);
    if (serial) {
      this.#appendState({
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
        bootstrapped: this.#readState().bootstrapped === true,
      };
    }

    if (!this.startPromise) {
      const requestedAt = new Date().toISOString();
      this.#appendState({
        starting: true,
        startupPhase: 'Preparing Android runtime',
        lastStartError: null,
        startRequestedAt: requestedAt,
        lastLogLine: 'Android start requested.',
      });
      const workerEnv = {
        ...process.env,
        NEOAGENT_ANDROID_BOOTSTRAP_WORKER: '1',
        NEOAGENT_ANDROID_BOOTSTRAP_USER_ID: this.userId || '',
        NEOAGENT_ANDROID_BOOTSTRAP_SCOPE_KEY: this.scopeKey,
        NEOAGENT_ANDROID_BOOTSTRAP_HEADLESS: String(options.headless === true),
        NEOAGENT_ANDROID_BOOTSTRAP_TIMEOUT_MS: String(options.timeoutMs || 600000),
      };
      const child = spawn(process.execPath, [ANDROID_BOOTSTRAP_WORKER], {
        detached: true,
        stdio: 'ignore',
        env: workerEnv,
      });
      child.unref();
      this.startPromise = new Promise((resolve) => {
        child.once('exit', (code, signal) => {
          this.startPromise = null;
          if (code !== 0) {
            console.error('[Android] Emulator bootstrap worker exited', { code, signal });
          }
          resolve({ code, signal });
        });
        child.once('error', (error) => {
          this.startPromise = null;
          console.error('[Android] Emulator bootstrap worker failed to spawn', error);
          resolve({ code: null, signal: null, error });
        });
      });
    }

    const state = this.#readState();
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
        this.#assertSerialAccess(serial, { claimIfUnowned: true });
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
    if (serial) {
      this.#assertSerialAccess(serial, { claimIfUnowned: true });
      return serial;
    }
    const started = await this.startEmulator();
    this.#assertSerialAccess(started.serial, { claimIfUnowned: true });
    return started.serial;
  }

  async stopEmulator() {
    const state = this.#readState();
    const serial = await this.getPrimarySerial({ ensureBootstrapped: false }).catch(() => null);
    if (serial) {
      this.#assertSerialAccess(serial, { claimIfUnowned: true });
      await this.#runAllowFailure(`${quoteShell(adbBinary())} -s ${quoteShell(serial)} emu kill`, { timeout: 15000 });
    }
    if (state.emulatorPid) {
      try { process.kill(state.emulatorPid, 'SIGTERM'); } catch {}
    }
    this.#releaseSerialOwnership(serial);
    this.#releaseSerialOwnership(state.serial);
    this.#appendState({
      serial: null,
      emulatorPid: null,
      starting: false,
      startupPhase: null,
      lastStartError: null,
      lastLogLine: 'Android emulator stopped.',
    });

    const deadline = Date.now() + 30000;
    while (Date.now() < deadline) {
      const devices = await this.listDevices({ ensureBootstrapped: false }).catch(() => []);
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
    this.#assertSerialAccess(serial, { claimIfUnowned: true });
    return this.#run(`${quoteShell(adbBinary())} -s ${quoteShell(serial)} ${command}`, options);
  }

  async screenshot(options = {}) {
    const serial = options.serial || await this.ensureDevice();
    let artifactRecord = null;
    let filename = `android_${Date.now()}.png`;
    let fullPath = path.join(SCREENSHOTS_DIR, filename);
    if (this.artifactStore && this.userId != null) {
      artifactRecord = this.artifactStore.allocateFile(this.userId, {
        kind: 'android-screenshot',
        backend: this.runtimeBackend,
        extension: 'png',
        contentType: 'image/png',
        filenameBase: 'android-screenshot',
        metadata: {
          serial,
        },
      });
      fullPath = artifactRecord.storagePath;
      filename = path.basename(fullPath);
    }
    await this.#adb(serial, `exec-out screencap -p > ${quoteShell(fullPath)}`, { timeout: 30000 });
    if (artifactRecord) {
      this.artifactStore.finalizeFile(artifactRecord.artifactId, fullPath);
    }
    return {
      success: true,
      serial,
      screenshotPath: artifactRecord ? artifactRecord.url : `/screenshots/${filename}`,
      artifactId: artifactRecord?.artifactId || null,
      fullPath,
    };
  }

  async dumpUi(options = {}) {
    const serial = options.serial || await this.ensureDevice();
    let xml = await this.#adb(serial, 'shell uiautomator dump --compressed /dev/tty', { timeout: 30000 });
    if (!String(xml || '').includes('<hierarchy')) {
      const remote = '/sdcard/neoagent-ui.xml';
      await this.#adb(serial, `shell uiautomator dump --compressed ${quoteShell(remote)}`, { timeout: 30000 });
      xml = await this.#adb(serial, `shell cat ${quoteShell(remote)}`, { timeout: 30000 });
    }
    xml = sanitizeUiXml(xml);
    let artifactRecord = null;
    let filename = `android_ui_${Date.now()}.xml`;
    let fullPath = path.join(UI_DUMPS_DIR, filename);
    if (this.artifactStore && this.userId != null) {
      artifactRecord = this.artifactStore.allocateFile(this.userId, {
        kind: 'android-ui-dump',
        backend: this.runtimeBackend,
        extension: 'xml',
        contentType: 'application/xml',
        filenameBase: 'android-ui',
        metadata: {
          serial,
        },
      });
      fullPath = artifactRecord.storagePath;
      filename = path.basename(fullPath);
    }
    fs.writeFileSync(fullPath, xml);
    if (artifactRecord) {
      this.artifactStore.finalizeFile(artifactRecord.artifactId, fullPath);
    }

    const nodes = parseUiDump(xml);
    return {
      success: true,
      serial,
      nodeCount: nodes.length,
      uiDumpPath: artifactRecord ? artifactRecord.url : fullPath,
      uiDumpArtifactId: artifactRecord?.artifactId || null,
      preview: options.includeNodes === false ? undefined : nodes.slice(0, 25).map((node) => summarizeNode(node)),
      xml,
    };
  }

  async #captureObservation(serial, options = {}) {
    const resolvedSerial = serial || await this.ensureDevice();
    const observation = {
      serial: resolvedSerial,
      screenshotPath: null,
      fullPath: null,
      uiDumpPath: null,
      nodeCount: null,
      preview: undefined,
      observationWarnings: [],
    };

    if (options.screenshot !== false) {
      try {
        const shot = await this.screenshot({ serial: resolvedSerial });
        observation.screenshotPath = shot?.screenshotPath || null;
        observation.fullPath = shot?.fullPath || null;
      } catch (err) {
        observation.observationWarnings.push(`screenshot: ${err.message}`);
      }
    }

    if (options.uiDump !== false) {
      try {
        const dump = await this.dumpUi({
          serial: resolvedSerial,
          includeNodes: options.includeNodes !== false,
        });
        observation.uiDumpPath = dump.uiDumpPath;
        observation.nodeCount = dump.nodeCount;
        observation.preview = dump.preview;
      } catch (err) {
        observation.observationWarnings.push(`ui_dump: ${err.message}`);
      }
    }

    if (observation.observationWarnings.length === 0) {
      delete observation.observationWarnings;
    }

    return observation;
  }

  async observe(options = {}) {
    const serial = options.serial || await this.ensureDevice();
    const observation = await this.#captureObservation(serial, options);
    if (!observation.screenshotPath && !observation.uiDumpPath) {
      throw new Error(
        Array.isArray(observation.observationWarnings) && observation.observationWarnings.length > 0
          ? observation.observationWarnings.join(' | ')
          : 'Unable to capture Android observation',
      );
    }
    return {
      success: true,
      ...observation,
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
    let resolvedFromUiDumpPath = null;

    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      const resolved = await this.#resolveSelector(args);
      serial = resolved.serial;
      node = resolved.node;
      resolvedFromUiDumpPath = resolved.uiDumpPath;
      x = node.bounds.centerX;
      y = node.bounds.centerY;
    }

    await this.#adb(serial, `shell input tap ${Math.round(x)} ${Math.round(y)}`, { timeout: 15000 });
    const observation = await this.#captureObservation(serial, args);
    return {
      success: true,
      serial,
      x: Math.round(x),
      y: Math.round(y),
      target: summarizeNode(node),
      resolvedFromUiDumpPath,
      ...observation,
    };
  }

  async longPress(args = {}) {
    let x = Number(args.x);
    let y = Number(args.y);
    let node = null;
    let serial = await this.ensureDevice();
    let resolvedFromUiDumpPath = null;

    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      const resolved = await this.#resolveSelector(args);
      serial = resolved.serial;
      node = resolved.node;
      resolvedFromUiDumpPath = resolved.uiDumpPath;
      x = node.bounds.centerX;
      y = node.bounds.centerY;
    }

    const durationMs = Math.max(250, Number(args.durationMs) || 650);
    await this.#adb(
      serial,
      `shell input swipe ${Math.round(x)} ${Math.round(y)} ${Math.round(x)} ${Math.round(y)} ${Math.round(durationMs)}`,
      { timeout: Math.max(15000, durationMs + 5000) },
    );
    const observation = await this.#captureObservation(serial, args);
    return {
      success: true,
      serial,
      x: Math.round(x),
      y: Math.round(y),
      durationMs,
      target: summarizeNode(node),
      resolvedFromUiDumpPath,
      ...observation,
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
        screenshot: false,
        uiDump: false,
      }).catch(() => {});
    }

    await this.#adb(serial, `shell input text ${quoteShell(androidTextEscape(args.text || ''))}`, { timeout: 20000 });
    if (args.pressEnter) {
      await this.#adb(serial, 'shell input keyevent 66', { timeout: 10000 });
    }
    const observation = await this.#captureObservation(serial, args);
    return {
      success: true,
      serial,
      typed: args.text || '',
      ...observation,
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
    const observation = await this.#captureObservation(serial, args);
    return {
      success: true,
      serial,
      ...observation,
    };
  }

  async pressKey(args = {}) {
    const serial = await this.ensureDevice();
    const raw = String(args.key || '').trim().toLowerCase();
    const keyCode = Number.isFinite(Number(raw)) ? Number(raw) : (DEFAULT_KEYEVENTS[raw] || null);
    if (!keyCode) throw new Error(`Unsupported Android key: ${args.key}`);
    await this.#adb(serial, `shell input keyevent ${keyCode}`, { timeout: 10000 });
    const observation = await this.#captureObservation(serial, args);
    return {
      success: true,
      serial,
      key: args.key,
      keyCode,
      ...observation,
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
        const observation = await this.#captureObservation(dump.serial, {
          screenshot: args.screenshot !== false,
          uiDump: args.uiDump !== false,
          includeNodes: args.includeNodes,
        });
        return {
          success: true,
          serial: dump.serial,
          matched: summarizeNode(node),
          matchedFromUiDumpPath: dump.uiDumpPath,
          ...observation,
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
      this.#assertSerialAccess(serial, { claimIfUnowned: true });
      const resolved = await this.#runAllowFailure(
        `${quoteShell(adbBinary())} -s ${quoteShell(serial)} shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER ${quoteShell(args.packageName)}`,
        { timeout: 15000 },
      );
      const component = parseResolvedLaunchComponent(
        `${resolved.stdout || ''}\n${resolved.stderr || ''}`,
        args.packageName,
      );

      if (component) {
        await this.#adb(serial, `shell am start -n ${quoteShell(component)}`, { timeout: 20000 });
      } else {
        await this.#adb(serial, `shell monkey -p ${quoteShell(args.packageName)} -c android.intent.category.LAUNCHER 1`, { timeout: 30000 });
      }
    } else {
      throw new Error('packageName is required for android_open_app');
    }
    const observation = await this.#captureObservation(serial, args);
    return {
      success: true,
      serial,
      packageName: args.packageName,
      activity: args.activity || null,
      ...observation,
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
    const observation = await this.#captureObservation(serial, args);
    return {
      success: true,
      serial,
      ...observation,
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
    const extension = path.extname(apkPath).toLowerCase();

    if (extension === '.aab') {
      throw new Error('.aab app bundles are not directly installable. Export a .apks bundle or .apk first.');
    }

    if (extension === '.apks') {
      const extractDir = fs.mkdtempSync(path.join(TMP_DIR, 'apk-bundle-'));
      try {
        extractZip(apkPath, extractDir);
        const bundle = resolveBundleInstallTargets(extractDir);
        await this.#adb(serial, `install -r ${quoteShell(bundle.installPaths[0])}`, { timeout: 300000 });
        return {
          success: true,
          serial,
          apkPath,
          artifactType: 'apks',
          installedPaths: bundle.installPaths,
          bundleLayout: bundle.layout,
        };
      } finally {
        fs.rmSync(extractDir, { recursive: true, force: true });
      }
    }

    await this.#adb(serial, `install -r ${quoteShell(apkPath)}`, { timeout: 300000 });
    return {
      success: true,
      serial,
      apkPath,
      artifactType: 'apk',
      installedPaths: [apkPath],
    };
  }

  async shell(args = {}) {
    const serial = await this.ensureDevice();
    const command = String(args.command || '').trim();
    if (!command) throw new Error('command is required for android_shell');

    const timeout = Math.max(1000, Number(args.timeoutMs) || 20000);
    const stdout = await this.#adb(serial, `shell ${quoteShell(command)}`, { timeout });
    const observation = args.screenshot === true
      ? await this.#captureObservation(serial)
      : null;
    return {
      success: true,
      serial,
      command,
      stdout,
      screenshotPath: observation?.screenshotPath || null,
      fullPath: observation?.fullPath || null,
      uiDumpPath: observation?.uiDumpPath || null,
      nodeCount: observation?.nodeCount,
      preview: observation?.preview,
    };
  }

  async getStatus() {
    const state = this.#readState();
    const shouldSkipDeviceProbe = state.starting === true || this.startPromise != null;
    const devices = !shouldSkipDeviceProbe && isExecutable(adbBinary())
      ? await this.listDevices({ ensureBootstrapped: false }).catch(() => [])
      : [];
    const serialInState = String(state.serial || '').trim();
    const serialOwnedByCurrentUser = serialInState
      ? !this.#isSerialOwnedByAnother(serialInState)
      : null;
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
      sdkRoot: activeAndroidSdkRoot(),
      avdHome: AVD_HOME,
      avdName: this.avdName,
      adbPath: adbBinary(),
      emulatorPath: emulatorBinary(),
      serial: state.serial,
      serialOwnedByCurrentUser,
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
    AndroidController.cleanupControllers.delete(this);
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
  parseResolvedLaunchComponent,
  parseLatestCmdlineToolsUrl,
  parseSystemImages,
  sanitizeUiXml,
  systemImageArchCandidates,
};
