const fs = require('fs');
const os = require('os');
const path = require('path');

const APP_DIR = path.resolve(__dirname, '..');
const HOME_DIR = os.homedir();
const RUNTIME_HOME = path.resolve(process.env.NEOAGENT_HOME || path.join(HOME_DIR, '.neoagent'));
const DATA_DIR = path.resolve(process.env.NEOAGENT_DATA_DIR || path.join(RUNTIME_HOME, 'data'));
const AGENT_DATA_DIR = path.resolve(process.env.NEOAGENT_AGENT_DATA_DIR || path.join(RUNTIME_HOME, 'agent-data'));
const LOG_DIR = path.join(DATA_DIR, 'logs');
const ENV_FILE = path.resolve(process.env.NEOAGENT_ENV_FILE || path.join(RUNTIME_HOME, '.env'));
const UPDATE_STATUS_FILE = path.join(DATA_DIR, 'update-status.json');
const PID_FILE = path.join(DATA_DIR, 'neoagent.pid');

const LEGACY_ENV_FILE = path.join(APP_DIR, '.env');
const LEGACY_DATA_DIR = path.join(APP_DIR, 'data');
const LEGACY_AGENT_DATA_DIR = path.join(APP_DIR, 'agent-data');

function ensureRuntimeDirs() {
  for (const dir of [RUNTIME_HOME, DATA_DIR, LOG_DIR, AGENT_DATA_DIR]) {
    fs.mkdirSync(dir, { recursive: true });
  }
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

function migrateLegacyRuntime(logger = () => {}) {
  ensureRuntimeDirs();
  let changed = false;

  if (copyFileIfMissing(LEGACY_ENV_FILE, ENV_FILE)) {
    try { fs.chmodSync(ENV_FILE, 0o600); } catch {}
    logger(`migrated ${LEGACY_ENV_FILE} -> ${ENV_FILE}`);
    changed = true;
  }
  if (copyDirMerge(LEGACY_DATA_DIR, DATA_DIR)) {
    logger(`migrated ${LEGACY_DATA_DIR} -> ${DATA_DIR}`);
    changed = true;
  }
  if (copyDirMerge(LEGACY_AGENT_DATA_DIR, AGENT_DATA_DIR)) {
    logger(`migrated ${LEGACY_AGENT_DATA_DIR} -> ${AGENT_DATA_DIR}`);
    changed = true;
  }

  return changed;
}

module.exports = {
  APP_DIR,
  HOME_DIR,
  RUNTIME_HOME,
  DATA_DIR,
  AGENT_DATA_DIR,
  LOG_DIR,
  ENV_FILE,
  UPDATE_STATUS_FILE,
  PID_FILE,
  LEGACY_ENV_FILE,
  LEGACY_DATA_DIR,
  LEGACY_AGENT_DATA_DIR,
  ensureRuntimeDirs,
  migrateLegacyRuntime
};
