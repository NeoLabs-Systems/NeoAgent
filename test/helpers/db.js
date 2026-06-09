'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const REPO_ROOT = path.resolve(__dirname, '../..');

function resetRuntimeEnv(ctx = null) {
  if (ctx?.previousEnv) {
    for (const [key, value] of Object.entries(ctx.previousEnv)) {
      if (value == null) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  }
}

function flushProjectCache() {
  const prefixes = [
    path.join(REPO_ROOT, 'runtime') + path.sep,
    path.join(REPO_ROOT, 'server') + path.sep,
  ];
  for (const key of Object.keys(require.cache)) {
    if (prefixes.some((prefix) => key.startsWith(prefix))) {
      delete require.cache[key];
    }
  }
}

function createTestRuntime() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-test-'));
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
  const db = require('../../server/db/database');
  return { dir, homeDir, dataDir, agentDataDir, envFile, previousEnv, db };
}

async function createTestUser(db, overrides = {}) {
  const bcrypt = require('bcrypt');
  const suffix = `${Date.now()}_${Math.random().toString(16).slice(2)}`;
  const username = overrides.username || `testuser_${suffix}`;
  const email = overrides.email || `${username}@example.com`;
  const password = overrides.password || 'TestPass1!SecureEnough';
  const hash = await bcrypt.hash(password, 4);
  const result = db.prepare(
    `INSERT INTO users (
      username, email, email_verified_at, password, password_login_enabled, display_name
    ) VALUES (?, ?, datetime('now'), ?, 1, ?)`
  ).run(username, email, hash, overrides.displayName || null);
  return {
    userId: Number(result.lastInsertRowid),
    username,
    email,
    password,
    displayName: overrides.displayName || null,
  };
}

function closeDatabase() {
  try {
    const db = require('../../server/db/database');
    if (db && db.open) db.close();
  } catch {}
}

function teardownTestRuntime(ctx) {
  closeDatabase();
  flushProjectCache();
  if (ctx?.dir) {
    fs.rmSync(ctx.dir, { recursive: true, force: true });
  }
  resetRuntimeEnv(ctx);
}

module.exports = {
  createTestRuntime,
  createTestUser,
  flushProjectCache,
  teardownTestRuntime,
};
