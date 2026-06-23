'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { afterEach, test } = require('node:test');
const Sqlite = require('better-sqlite3');

const { flushProjectCache } = require('../../helpers/db');

let cleanup = null;

afterEach(() => {
  if (cleanup) {
    cleanup();
    cleanup = null;
  }
});

function setupLegacyRuntime() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-legacy-db-'));
  const homeDir = path.join(dir, 'home');
  const dataDir = path.join(dir, 'data');
  const agentDataDir = path.join(dir, 'agent-data');
  const envFile = path.join(dir, '.env');
  const previousEnv = {};
  for (const key of [
    'NODE_ENV',
    'NEOAGENT_HOME',
    'NEOAGENT_DATA_DIR',
    'NEOAGENT_AGENT_DATA_DIR',
    'NEOAGENT_ENV_FILE',
    'NEOAGENT_PROFILE',
    'SESSION_SECRET',
    'ALLOWED_ORIGINS',
    'PUBLIC_URL',
    'SECURE_COOKIES',
    'TRUST_PROXY',
    'OPENAI_API_KEY',
    'GOOGLE_AI_KEY',
  ]) {
    previousEnv[key] = process.env[key];
  }

  Object.assign(process.env, {
    NODE_ENV: 'test',
    NEOAGENT_HOME: homeDir,
    NEOAGENT_DATA_DIR: dataDir,
    NEOAGENT_AGENT_DATA_DIR: agentDataDir,
    NEOAGENT_ENV_FILE: envFile,
    NEOAGENT_PROFILE: 'private',
    SESSION_SECRET: 'test-secret-32-chars-long-for-suite',
    ALLOWED_ORIGINS: '',
    PUBLIC_URL: '',
    SECURE_COOKIES: 'false',
    TRUST_PROXY: 'true',
    OPENAI_API_KEY: '',
    GOOGLE_AI_KEY: '',
  });

  fs.mkdirSync(dataDir, { recursive: true });
  fs.mkdirSync(agentDataDir, { recursive: true });
  flushProjectCache();

  cleanup = () => {
    try {
      const db = require('../../../server/db/database');
      if (db?.open) db.close();
    } catch {}
    flushProjectCache();
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value == null) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
    fs.rmSync(dir, { recursive: true, force: true });
  };

  return { dataDir };
}

test('database bootstrap tolerates legacy screen_history and desktop device tables', () => {
  const { dataDir } = setupLegacyRuntime();
  const dbPath = path.join(dataDir, 'neoagent.db');
  const legacyDb = new Sqlite(dbPath);

  legacyDb.exec(`
    CREATE TABLE screen_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      timestamp TEXT DEFAULT (datetime('now')),
      app_name TEXT,
      text_content TEXT
    );

    CREATE TABLE desktop_companion_devices (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      device_id TEXT NOT NULL,
      label TEXT NOT NULL,
      hostname TEXT,
      platform TEXT,
      platform_version TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(user_id, device_id)
    );
  `);
  legacyDb.close();

  assert.doesNotThrow(() => require('../../../server/db/database'));
  const db = require('../../../server/db/database');

  const screenHistoryColumns = new Set(
    db.prepare('PRAGMA table_info(screen_history)').all().map((column) => column.name),
  );
  assert.ok(screenHistoryColumns.has('captured_at'));
  assert.ok(screenHistoryColumns.has('device_id'));
  assert.ok(screenHistoryColumns.has('device_label'));

  const desktopColumns = new Set(
    db.prepare('PRAGMA table_info(desktop_companion_devices)').all().map((column) => column.name),
  );
  assert.ok(desktopColumns.has('status'));
  assert.ok(desktopColumns.has('updated_at'));

  const screenIndexes = db.prepare('PRAGMA index_list(screen_history)').all();
  assert.ok(screenIndexes.some((index) => index.name === 'idx_screen_history_device'));

  const desktopIndexes = db.prepare('PRAGMA index_list(desktop_companion_devices)').all();
  assert.ok(desktopIndexes.some((index) => index.name === 'idx_desktop_companion_devices_user'));
});
