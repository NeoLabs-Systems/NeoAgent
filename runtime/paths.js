const fs = require('fs');
const crypto = require('crypto');
const os = require('os');
const path = require('path');
const { parseEnv } = require('./env');

const APP_DIR = path.resolve(__dirname, '..');
const HOME_DIR = os.homedir();
const RUNTIME_HOME = path.resolve(process.env.NEOAGENT_HOME || path.join(HOME_DIR, '.neoagent'));
const DATA_DIR = path.resolve(process.env.NEOAGENT_DATA_DIR || path.join(RUNTIME_HOME, 'data'));
const AGENT_DATA_DIR = path.resolve(process.env.NEOAGENT_AGENT_DATA_DIR || path.join(RUNTIME_HOME, 'agent-data'));
const LOG_DIR = path.join(DATA_DIR, 'logs');
const ENV_FILE = path.resolve(process.env.NEOAGENT_ENV_FILE || path.join(RUNTIME_HOME, '.env'));
const DATABASE_FILE = path.join(DATA_DIR, 'neoagent.db');
const UPDATE_STATUS_FILE = path.join(DATA_DIR, 'update-status.json');
const PID_FILE = path.join(DATA_DIR, 'neoagent.pid');
const SETUP_STATE_FILE = path.join(RUNTIME_HOME, 'setup-state.json');

const LEGACY_ENV_FILE = path.join(APP_DIR, '.env');
const LEGACY_DATA_DIR = path.join(APP_DIR, 'data');
const LEGACY_AGENT_DATA_DIR = path.join(APP_DIR, 'agent-data');
const LEGACY_DESKTOP_RUNTIME_DIR = path.join(HOME_DIR, '.neoagent', 'runtime');
const LEGACY_DESKTOP_ENV_FILE = path.join(LEGACY_DESKTOP_RUNTIME_DIR, '.env');
const PERSISTENT_IDENTITY_ENV_KEYS = new Set([
  'SESSION_SECRET',
  'NEOAGENT_ENCRYPTION_KEY',
  'NEOAGENT_VM_GUEST_TOKEN',
  'ADMIN_USERNAME',
  'ADMIN_PASSWORD',
]);
const DEFAULT_VM_BASE_IMAGE_URLS = Object.freeze({
  arm64: 'https://cloud.debian.org/images/cloud/trixie/20260810-2566/debian-13-generic-arm64-20260810-2566.qcow2',
  x64: 'https://cloud.debian.org/images/cloud/trixie/20260810-2566/debian-13-generic-amd64-20260810-2566.qcow2',
});

function ensureRuntimeDirs() {
  for (const dir of [RUNTIME_HOME, DATA_DIR, LOG_DIR, AGENT_DATA_DIR]) {
    ensurePrivateDirectory(dir);
  }
}

function applySecureUmask() {
  if (process.platform !== 'win32' && typeof process.umask === 'function') {
    process.umask(0o077);
  }
}

function ensurePrivateDirectory(dir) {
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  if (process.platform !== 'win32') {
    fs.chmodSync(dir, 0o700);
  }
}

function ensurePrivateFile(filePath) {
  if (!fs.existsSync(filePath) || process.platform === 'win32') return;
  fs.chmodSync(filePath, 0o600);
}

function copyFileIfMissing(src, dest) {
  if (!fs.existsSync(src) || fs.existsSync(dest)) return false;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
  return true;
}

function copyDirMerge(src, dest) {
  if (!fs.existsSync(src)) return false;
  if (path.resolve(src) === path.resolve(dest)) return false;
  if (fs.existsSync(dest)) {
    const existing = fs.readdirSync(dest);
    if (existing.length > 0) return false;
  }
  fs.mkdirSync(dest, { recursive: true });
  fs.cpSync(src, dest, { recursive: true, force: false, errorOnExist: false });
  return true;
}

function migrationBackupPath(sourcePath) {
  const basePath = `${sourcePath}.migrated`;
  if (!fs.existsSync(basePath)) return basePath;
  return `${basePath}.${Date.now()}`;
}

function migrateLegacyDesktopEnv({
  legacyEnvFile = LEGACY_DESKTOP_ENV_FILE,
  envFile = ENV_FILE,
  logger = () => {},
} = {}) {
  if (path.resolve(legacyEnvFile) === path.resolve(envFile)) return false;
  if (!fs.existsSync(legacyEnvFile)) return false;

  const legacyValues = parseEnv(readEnvFileRaw(legacyEnvFile));
  if (legacyValues.size === 0) return false;

  const currentValues = parseEnv(readEnvFileRaw(envFile));
  for (const [key, value] of legacyValues.entries()) {
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) continue;
    const currentValue = String(currentValues.get(key) || '').trim();
    if (PERSISTENT_IDENTITY_ENV_KEYS.has(key) && currentValue) continue;
    upsertEnvValue(envFile, key, value);
  }

  const backupPath = migrationBackupPath(legacyEnvFile);
  fs.renameSync(legacyEnvFile, backupPath);
  logger(
    `migrated desktop config ${legacyEnvFile} -> ${envFile} (backup: ${backupPath})`,
  );
  return true;
}

function migrateLegacyRuntime(logger = () => {}) {
  ensureRuntimeDirs();
  let changed = false;

  const log = (message) => {
    if (typeof logger === 'function') {
      logger(message);
      return;
    }
    if (logger && typeof logger.info === 'function') {
      logger.info(message);
    }
  };

  const logError = (message) => {
    if (logger && typeof logger.error === 'function') {
      logger.error(message);
      return;
    }
    if (typeof logger === 'function') {
      logger(`error: ${message}`);
      return;
    }
    try { console.error(message); } catch {}
  };

  if (copyFileIfMissing(LEGACY_ENV_FILE, ENV_FILE)) {
    try {
      fs.chmodSync(ENV_FILE, 0o600);
    } catch (error) {
      try {
        fs.rmSync(ENV_FILE, { force: true });
      } catch {}
      logError(
        `failed to migrate ${LEGACY_ENV_FILE} -> ${ENV_FILE}: chmod(0600) failed (${error.message}). ` +
        `Migration was reverted. Note: chmod behavior can differ on Windows filesystems.`
      );
      return changed;
    }
    log(`migrated ${LEGACY_ENV_FILE} -> ${ENV_FILE}`);
    changed = true;
  }
  try {
    if (migrateLegacyDesktopEnv({ logger: log })) {
      changed = true;
    }
  } catch (error) {
    logError(
      `failed to migrate desktop runtime config ${LEGACY_DESKTOP_ENV_FILE} -> ${ENV_FILE}: ${error.message}`,
    );
  }
  if (copyDirMerge(LEGACY_DATA_DIR, DATA_DIR)) {
    log(`migrated ${LEGACY_DATA_DIR} -> ${DATA_DIR}`);
    changed = true;
  }
  if (copyDirMerge(LEGACY_AGENT_DATA_DIR, AGENT_DATA_DIR)) {
    log(`migrated ${LEGACY_AGENT_DATA_DIR} -> ${AGENT_DATA_DIR}`);
    changed = true;
  }

  return changed;
}

function readEnvFileRaw(envFile = ENV_FILE) {
  try {
    return fs.readFileSync(envFile, 'utf8');
  } catch {
    return '';
  }
}

function writeEnvFileAtomic(envFile, content) {
  const resolved = path.resolve(envFile);
  const directory = path.dirname(resolved);
  const temporary = path.join(
    directory,
    `.${path.basename(resolved)}.${process.pid}.${crypto.randomBytes(8).toString('hex')}.tmp`,
  );
  fs.mkdirSync(directory, { recursive: true });
  let descriptor = null;
  try {
    descriptor = fs.openSync(temporary, 'wx', 0o600);
    fs.writeFileSync(descriptor, content, 'utf8');
    fs.fsyncSync(descriptor);
    fs.closeSync(descriptor);
    descriptor = null;
    fs.renameSync(temporary, resolved);
  } finally {
    if (descriptor !== null) {
      try { fs.closeSync(descriptor); } catch {}
    }
    try { fs.rmSync(temporary, { force: true }); } catch {}
  }
}

function normalizeEnvKey(key) {
  const normalized = String(key).replace(/[\r\n]/g, '');
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(normalized)) {
    throw new Error(`Invalid environment variable name: ${normalized || '(empty)'}`);
  }
  return normalized;
}

function upsertEnvValue(envFile, key, value) {
  const safeKey = normalizeEnvKey(key);
  const safeValue = String(value).replace(/[\r\n]/g, '');
  const raw = readEnvFileRaw(envFile);
  const lines = raw ? raw.split('\n') : [];
  let replaced = false;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(`${safeKey}=`)) {
      lines[i] = `${safeKey}=${safeValue}`;
      replaced = true;
      break;
    }
  }

  if (!replaced) {
    lines.push(`${safeKey}=${safeValue}`);
  }

  const output = lines.filter((line, idx, arr) => idx !== arr.length - 1 || line !== '').join('\n') + '\n';
  writeEnvFileAtomic(envFile, output);
}

function removeEnvValue(envFile, key) {
  const safeKey = normalizeEnvKey(key);
  const raw = readEnvFileRaw(envFile);
  if (!raw) return false;
  const lines = raw.split('\n').filter((line) => !line.startsWith(`${safeKey}=`));
  const output = lines.filter((line, idx, arr) => idx !== arr.length - 1 || line !== '').join('\n') + '\n';
  writeEnvFileAtomic(envFile, output);
  return true;
}

function generateSecret(bytes = 32) {
  return crypto.randomBytes(bytes).toString('hex');
}

function getDefaultVmBaseImageUrl(arch = 'x64') {
  return arch === 'arm64' ? DEFAULT_VM_BASE_IMAGE_URLS.arm64 : DEFAULT_VM_BASE_IMAGE_URLS.x64;
}

function isPlaceholderValue(value, placeholders) {
  const secret = String(value || '').trim();
  return !secret || placeholders.has(secret);
}

function isValidVmGuestToken(value) {
  const secret = String(value || '').trim();
  if (!secret || secret.length < 32) return false;
  if (/^(change|replace|set|your|example|sample|placeholder|token|secret)[-_a-z0-9]*$/i.test(secret)) return false;
  if (/change-this-guest-token-before-prod/i.test(secret)) return false;
  if (/^(.)\1+$/.test(secret)) return false;
  return true;
}

function ensureSecureRuntimeEnv({ envFile = ENV_FILE, env = process.env, logger = console } = {}) {
  const raw = readEnvFileRaw(envFile);
  const parsed = parseEnv(raw);
  const changes = [];
  const defaultProfile = 'prod';
  const sessionPlaceholders = new Set([
    'neoagent-dev-secret-change-me',
    'change-this-to-a-random-secret-in-production',
    'change-me-to-something-random',
  ]);

  let deploymentProfile = String(env.NEOAGENT_PROFILE || parsed.get('NEOAGENT_PROFILE') || '').trim();
  if (!deploymentProfile) {
    deploymentProfile = defaultProfile;
    upsertEnvValue(envFile, 'NEOAGENT_PROFILE', deploymentProfile);
    changes.push('NEOAGENT_PROFILE');
  }
  env.NEOAGENT_PROFILE = deploymentProfile;

  let vmBaseImageUrl = String(env.NEOAGENT_VM_BASE_IMAGE_URL || parsed.get('NEOAGENT_VM_BASE_IMAGE_URL') || '').trim();
  const preferredVmBaseImageUrl = getDefaultVmBaseImageUrl();
  if (!vmBaseImageUrl || /arm64|aarch64/i.test(vmBaseImageUrl)) {
    vmBaseImageUrl = preferredVmBaseImageUrl;
    upsertEnvValue(envFile, 'NEOAGENT_VM_BASE_IMAGE_URL', vmBaseImageUrl);
    changes.push('NEOAGENT_VM_BASE_IMAGE_URL');
  }
  env.NEOAGENT_VM_BASE_IMAGE_URL = vmBaseImageUrl;

  let vmMemoryMb = String(env.NEOAGENT_VM_MEMORY_MB || parsed.get('NEOAGENT_VM_MEMORY_MB') || '').trim();
  if (!vmMemoryMb) {
    vmMemoryMb = '4096';
    upsertEnvValue(envFile, 'NEOAGENT_VM_MEMORY_MB', vmMemoryMb);
    changes.push('NEOAGENT_VM_MEMORY_MB');
  }
  env.NEOAGENT_VM_MEMORY_MB = vmMemoryMb;

  let vmCpus = String(env.NEOAGENT_VM_CPUS || parsed.get('NEOAGENT_VM_CPUS') || '').trim();
  if (!vmCpus) {
    vmCpus = '2';
    upsertEnvValue(envFile, 'NEOAGENT_VM_CPUS', vmCpus);
    changes.push('NEOAGENT_VM_CPUS');
  }
  env.NEOAGENT_VM_CPUS = vmCpus;

  let sessionSecret = String(env.SESSION_SECRET || parsed.get('SESSION_SECRET') || '').trim();
  if (isPlaceholderValue(sessionSecret, sessionPlaceholders)) {
    sessionSecret = generateSecret(32);
    upsertEnvValue(envFile, 'SESSION_SECRET', sessionSecret);
    changes.push('SESSION_SECRET');
  }
  env.SESSION_SECRET = sessionSecret;

  let adminUsername = String(env.ADMIN_USERNAME || parsed.get('ADMIN_USERNAME') || '').trim();
  if (!adminUsername) {
    adminUsername = 'admin';
    upsertEnvValue(envFile, 'ADMIN_USERNAME', adminUsername);
    changes.push('ADMIN_USERNAME');
  }
  env.ADMIN_USERNAME = adminUsername;

  let adminPassword = String(env.ADMIN_PASSWORD || parsed.get('ADMIN_PASSWORD') || '').trim();
  if (!adminPassword) {
    adminPassword = generateSecret(16);
    upsertEnvValue(envFile, 'ADMIN_PASSWORD', adminPassword);
    changes.push('ADMIN_PASSWORD');
  }
  env.ADMIN_PASSWORD = adminPassword;

  let guestToken = String(env.NEOAGENT_VM_GUEST_TOKEN || parsed.get('NEOAGENT_VM_GUEST_TOKEN') || '').trim();
  if (!isValidVmGuestToken(guestToken)) {
    guestToken = generateSecret(32);
    upsertEnvValue(envFile, 'NEOAGENT_VM_GUEST_TOKEN', guestToken);
    changes.push('NEOAGENT_VM_GUEST_TOKEN');
  }
  env.NEOAGENT_VM_GUEST_TOKEN = guestToken;

  if (changes.length > 0 && logger) {
    const message = `Initialized runtime defaults: ${changes.join(', ')}`;
    if (typeof logger.info === 'function') {
      logger.info(message);
    } else if (typeof logger.log === 'function') {
      logger.log(message);
    }
  }

  return {
    changes,
    sessionSecret: env.SESSION_SECRET || null,
    guestToken: env.NEOAGENT_VM_GUEST_TOKEN || null,
  };
}

module.exports = {
  APP_DIR,
  HOME_DIR,
  RUNTIME_HOME,
  DATA_DIR,
  AGENT_DATA_DIR,
  LOG_DIR,
  ENV_FILE,
  DATABASE_FILE,
  UPDATE_STATUS_FILE,
  PID_FILE,
  SETUP_STATE_FILE,
  LEGACY_ENV_FILE,
  LEGACY_DATA_DIR,
  LEGACY_AGENT_DATA_DIR,
  LEGACY_DESKTOP_RUNTIME_DIR,
  LEGACY_DESKTOP_ENV_FILE,
  DEFAULT_VM_BASE_IMAGE_URLS,
  applySecureUmask,
  ensurePrivateDirectory,
  ensurePrivateFile,
  ensureRuntimeDirs,
  ensureSecureRuntimeEnv,
  getDefaultVmBaseImageUrl,
  migrateLegacyDesktopEnv,
  migrateLegacyRuntime,
  removeEnvValue,
  upsertEnvValue,
  readEnvFileRaw,
};
