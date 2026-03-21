#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const {
  APP_DIR,
  DATA_DIR,
  UPDATE_STATUS_FILE: STATUS_FILE,
  migrateLegacyRuntime,
  ensureRuntimeDirs
} = require('../runtime/paths');

const MAX_LOG_LINES = 220;
const FLUTTER_APP_DIR = path.join(APP_DIR, 'flutter_app');
const WEB_CLIENT_DIR = path.join(APP_DIR, 'server', 'public');

function nowIso() {
  return new Date().toISOString();
}

function readStatus() {
  try {
    return JSON.parse(fs.readFileSync(STATUS_FILE, 'utf8'));
  } catch {
    return {};
  }
}

function writeStatus(patch) {
  const next = {
    state: 'idle',
    progress: 0,
    phase: 'idle',
    message: 'No update running',
    startedAt: null,
    completedAt: null,
    versionBefore: null,
    versionAfter: null,
    changelog: [],
    logs: [],
    ...readStatus(),
    ...patch,
    updatedAt: nowIso()
  };

  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(STATUS_FILE, JSON.stringify(next, null, 2));
  return next;
}

function appendLog(line) {
  const status = readStatus();
  const logs = Array.isArray(status.logs) ? status.logs : [];
  logs.push(`[${new Date().toLocaleTimeString('en-US', { hour12: false })}] ${line}`);
  if (logs.length > MAX_LOG_LINES) {
    logs.splice(0, logs.length - MAX_LOG_LINES);
  }
  writeStatus({ logs });
}

function withInstallEnv(extraEnv = {}) {
  return {
    ...process.env,
    PUPPETEER_SKIP_DOWNLOAD: process.env.PUPPETEER_SKIP_DOWNLOAD || 'true',
    ...extraEnv
  };
}

function run(cmd, args, options = {}) {
  appendLog(`$ ${cmd} ${args.join(' ')}`);
  const res = spawnSync(cmd, args, {
    cwd: APP_DIR,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    ...options
  });

  if (res.stdout) {
    for (const line of res.stdout.split('\n').map((v) => v.trim()).filter(Boolean)) {
      appendLog(line);
    }
  }
  if (res.stderr) {
    for (const line of res.stderr.split('\n').map((v) => v.trim()).filter(Boolean)) {
      appendLog(line);
    }
  }

  return res;
}

function commandExists(cmd) {
  const r = run('bash', ['-lc', `command -v ${cmd}`]);
  return r.status === 0;
}

function hasBundledWebClient() {
  return fs.existsSync(path.join(WEB_CLIENT_DIR, 'index.html'));
}

function buildBundledWebClientIfPossible({ required = false } = {}) {
  if (!fs.existsSync(FLUTTER_APP_DIR)) {
    if (hasBundledWebClient()) {
      appendLog('Flutter app sources not found. Keeping existing bundled web client.');
      return false;
    }
    if (required) {
      fail(`Missing Flutter app sources at ${FLUTTER_APP_DIR}`);
    }
    appendLog('Flutter app sources not found and no bundled web client was detected.');
    return false;
  }

  if (!commandExists('flutter')) {
    if (hasBundledWebClient()) {
      appendLog('Flutter SDK not found. Keeping existing bundled web client.');
      return false;
    }
    fail('Flutter SDK is required because no bundled web client was found.');
  }

  info(82, 'building', 'Building bundled Flutter web client');
  const build = run('flutter', [
    'build',
    'web',
    '--output',
    '../server/public',
    `--dart-define=NEOAGENT_BACKEND_URL=${process.env.NEOAGENT_BACKEND_URL || ''}`
  ], {
    cwd: FLUTTER_APP_DIR,
    env: process.env
  });

  if (build.status !== 0) {
    if (hasBundledWebClient()) {
      appendLog('Flutter build failed, but an existing bundled web client is still present.');
      return false;
    }
    fail('Flutter web build failed and no bundled web client is available.');
  }

  appendLog('Bundled Flutter web client updated.');
  return true;
}

function fail(message) {
  writeStatus({
    state: 'failed',
    progress: 100,
    phase: 'failed',
    message,
    completedAt: nowIso()
  });
  appendLog(`FAILED: ${message}`);
  process.exit(1);
}

function info(progress, phase, message) {
  writeStatus({ state: 'running', progress, phase, message });
  appendLog(message);
}

function main() {
  migrateLegacyRuntime();
  ensureRuntimeDirs();
  const startedAt = nowIso();
  writeStatus({
    state: 'running',
    progress: 2,
    phase: 'starting',
    message: 'Preparing update job',
    startedAt,
    completedAt: null,
    versionBefore: null,
    versionAfter: null,
    changelog: [],
    logs: []
  });

  const gitDir = path.join(APP_DIR, '.git');
  const hasGit = fs.existsSync(gitDir) && commandExists('git');

  if (!hasGit) {
    info(20, 'checking', 'No git repository detected. Trying package-based update.');
    if (!commandExists('npm')) {
      fail('Update unavailable: no git repository detected and npm is not installed.');
    }

    info(45, 'updating', 'Installing latest NeoAgent package');
    const npmUpdate = run('npm', ['install', '-g', 'neoagent@latest'], {
      env: withInstallEnv()
    });
    if (npmUpdate.status !== 0) {
      fail('npm global update failed');
    }

    if (!hasBundledWebClient()) {
      fail('No bundled Flutter web client found after package update.');
    }

    info(70, 'restarting', 'Restarting NeoAgent service');
    const restart = run(process.execPath, ['bin/neoagent.js', 'restart']);
    if (restart.status !== 0) fail('Restart failed while trying to refresh runtime');

    writeStatus({
      state: 'completed',
      progress: 100,
      phase: 'completed',
      message: 'Package update completed and service restarted.',
      completedAt: nowIso()
    });
    return;
  }

  info(8, 'checking', 'Detecting branch and current version');
  const branchRes = run('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  const currentRes = run('git', ['rev-parse', '--short', 'HEAD']);
  const branch = (branchRes.stdout || '').trim() || 'main';
  const current = (currentRes.stdout || '').trim() || null;
  writeStatus({ versionBefore: current });

  info(20, 'fetching', `Fetching latest commits from origin/${branch}`);
  const fetch = run('git', ['fetch', 'origin']);
  if (fetch.status !== 0) fail('git fetch failed');

  info(35, 'pulling', `Rebasing with origin/${branch}`);
  const pull = run('git', ['pull', '--rebase', '--autostash', 'origin', branch]);
  if (pull.status !== 0) fail('git pull --rebase failed');

  const nextRes = run('git', ['rev-parse', '--short', 'HEAD']);
  const next = (nextRes.stdout || '').trim() || null;
  writeStatus({ versionAfter: next });

  const changed = current && next && current !== next;

  if (changed) {
    info(55, 'changelog', `Collecting changelog (${current} -> ${next})`);
    const log = run('git', ['log', '--oneline', `${current}..${next}`]);
    const changelog = (log.stdout || '')
      .split('\n')
      .map((v) => v.trim())
      .filter(Boolean)
      .slice(0, 25);
    writeStatus({ changelog });

    info(70, 'dependencies', 'Installing updated dependencies');
    const npmInstall = run('npm', ['install', '--omit=dev', '--no-audit', '--no-fund'], {
      env: withInstallEnv()
    });
    if (npmInstall.status !== 0) fail('Dependency installation failed');
  } else {
    info(68, 'changelog', 'Already up to date. No new commits to apply.');
    writeStatus({ changelog: [] });
  }

  buildBundledWebClientIfPossible();

  info(92, 'restarting', 'Restarting NeoAgent service');
  const restart = run(process.execPath, ['bin/neoagent.js', 'restart']);
  if (restart.status !== 0) fail('Service restart failed');

  writeStatus({
    state: 'completed',
    progress: 100,
    phase: 'completed',
    message: changed
      ? `Update completed successfully (${current} -> ${next})`
      : 'Already up to date. Service restarted.',
    completedAt: nowIso()
  });
}

try {
  main();
} catch (err) {
  fail(err.message || 'Unexpected update runner error');
}
