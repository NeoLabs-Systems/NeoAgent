const fs = require('fs');
const os = require('os');
const path = require('path');
const net = require('net');
const crypto = require('crypto');
const readline = require('readline');
const { spawn, spawnSync } = require('child_process');

const APP_DIR = path.resolve(__dirname, '..');
const APP_NAME = 'NeoAgent';
const SERVICE_LABEL = 'com.neoagent';
const PLIST_SRC = path.join(APP_DIR, 'com.neoagent.plist');
const PLIST_DST = path.join(os.homedir(), 'Library', 'LaunchAgents', 'com.neoagent.plist');
const SYSTEMD_UNIT = path.join(os.homedir(), '.config', 'systemd', 'user', 'neoagent.service');
const LOG_DIR = path.join(APP_DIR, 'data', 'logs');
const ENV_FILE = path.join(APP_DIR, '.env');

const COLORS = process.stdout.isTTY
  ? {
      reset: '\x1b[0m',
      bold: '\x1b[1m',
      red: '\x1b[1;31m',
      green: '\x1b[1;32m',
      yellow: '\x1b[1;33m',
      blue: '\x1b[1;34m',
      cyan: '\x1b[1;36m',
      dim: '\x1b[2m'
    }
  : { reset: '', bold: '', red: '', green: '', yellow: '', blue: '', cyan: '', dim: '' };

function logInfo(msg) {
  console.log(`  ${COLORS.blue}->${COLORS.reset} ${msg}`);
}

function logOk(msg) {
  console.log(`  ${COLORS.green}ok${COLORS.reset} ${msg}`);
}

function logWarn(msg) {
  console.warn(`  ${COLORS.yellow}warn${COLORS.reset} ${msg}`);
}

function logErr(msg) {
  console.error(`  ${COLORS.red}err${COLORS.reset} ${msg}`);
}

function heading(text) {
  console.log(`\n${COLORS.bold}${text}${COLORS.reset}`);
}

function detectPlatform() {
  if (process.platform === 'darwin') return 'macos';
  if (process.platform === 'linux') return 'linux';
  return 'other';
}

function loadEnvPort() {
  try {
    const env = fs.readFileSync(ENV_FILE, 'utf8');
    const line = env.split('\n').find((entry) => entry.startsWith('PORT='));
    if (!line) return 3060;
    const raw = line.split('=')[1]?.trim();
    const num = Number(raw);
    return Number.isFinite(num) && num > 0 ? num : 3060;
  } catch {
    return 3060;
  }
}

function runOrThrow(cmd, args, options = {}) {
  const res = spawnSync(cmd, args, { stdio: 'inherit', cwd: APP_DIR, ...options });
  if (res.status !== 0) {
    throw new Error(`Command failed: ${cmd} ${args.join(' ')}`);
  }
}

function runQuiet(cmd, args, options = {}) {
  return spawnSync(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8', cwd: APP_DIR, ...options });
}

function commandExists(cmd) {
  const res = runQuiet('bash', ['-lc', `command -v ${cmd}`]);
  return res.status === 0;
}

function ensureLogDir() {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

function killByPort(port) {
  if (!commandExists('lsof')) return false;
  const res = runQuiet('bash', ['-lc', `lsof -ti tcp:${port}`]);
  if (res.status !== 0 || !res.stdout.trim()) return false;
  const pids = res.stdout
    .trim()
    .split('\n')
    .map((v) => Number(v.trim()))
    .filter((v) => Number.isFinite(v) && v > 0);
  let killed = false;
  for (const pid of pids) {
    try {
      process.kill(pid, 'SIGTERM');
      killed = true;
    } catch {
      // Ignore stale pids.
    }
  }
  return killed;
}

function isPortOpen(port) {
  return new Promise((resolve) => {
    const sock = new net.Socket();
    let done = false;

    const finish = (open) => {
      if (done) return;
      done = true;
      sock.destroy();
      resolve(open);
    };

    sock.setTimeout(700);
    sock.once('connect', () => finish(true));
    sock.once('timeout', () => finish(false));
    sock.once('error', () => finish(false));
    sock.connect(port, '127.0.0.1');
  });
}

function randomSecret() {
  return crypto.randomBytes(24).toString('hex');
}

async function ask(question, fallback = '') {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    const suffix = fallback ? ` [${fallback}]` : '';
    rl.question(`  ? ${question}${suffix}: `, (answer) => {
      rl.close();
      const trimmed = answer.trim();
      resolve(trimmed || fallback);
    });
  });
}

async function cmdSetup() {
  heading('Environment Setup');

  const current = {};
  if (fs.existsSync(ENV_FILE)) {
    const lines = fs.readFileSync(ENV_FILE, 'utf8').split('\n');
    for (const line of lines) {
      if (!line || line.startsWith('#') || !line.includes('=')) continue;
      const idx = line.indexOf('=');
      const key = line.slice(0, idx).trim();
      const value = line.slice(idx + 1).trim();
      current[key] = value;
    }
  }

  const port = await ask('Server port', current.PORT || '3060');
  const sessionSecret = await ask('Session secret', current.SESSION_SECRET || randomSecret());
  const anthropic = await ask('Anthropic API key', current.ANTHROPIC_API_KEY || '');
  const openai = await ask('OpenAI API key', current.OPENAI_API_KEY || '');
  const xai = await ask('xAI API key', current.XAI_API_KEY || '');
  const google = await ask('Google API key', current.GOOGLE_AI_KEY || '');
  const ollama = await ask('Ollama URL', current.OLLAMA_URL || 'http://localhost:11434');
  const origins = await ask('Allowed CORS origins', current.ALLOWED_ORIGINS || '');

  const lines = [
    `NODE_ENV=production`,
    `PORT=${port}`,
    `SESSION_SECRET=${sessionSecret}`,
    anthropic ? `ANTHROPIC_API_KEY=${anthropic}` : '',
    openai ? `OPENAI_API_KEY=${openai}` : '',
    xai ? `XAI_API_KEY=${xai}` : '',
    google ? `GOOGLE_AI_KEY=${google}` : '',
    ollama ? `OLLAMA_URL=${ollama}` : '',
    origins ? `ALLOWED_ORIGINS=${origins}` : ''
  ].filter(Boolean);

  fs.writeFileSync(ENV_FILE, `${lines.join('\n')}\n`, { mode: 0o600 });
  logOk(`Wrote ${ENV_FILE}`);
}

function installDependencies() {
  heading('Dependencies');
  runOrThrow('npm', ['install', '--omit=dev', '--no-audit', '--no-fund']);
  logOk('Dependencies installed');
}

function installMacService() {
  ensureLogDir();
  fs.mkdirSync(path.dirname(PLIST_DST), { recursive: true });

  if (!fs.existsSync(PLIST_SRC)) {
    throw new Error(`Missing plist template at ${PLIST_SRC}`);
  }

  const nodeBin = process.execPath;
  const content = fs
    .readFileSync(PLIST_SRC, 'utf8')
    .replace(/\/usr\/local\/bin\/node/g, nodeBin)
    .replace(/\/Users\/neo\/NeoAgent/g, APP_DIR)
    .replace(/\/Users\/neo/g, os.homedir());

  fs.writeFileSync(PLIST_DST, content);

  runQuiet('launchctl', ['unload', PLIST_DST]);
  runOrThrow('launchctl', ['load', PLIST_DST]);
  logOk(`launchd service loaded (${SERVICE_LABEL})`);
}

function installLinuxService() {
  ensureLogDir();
  fs.mkdirSync(path.dirname(SYSTEMD_UNIT), { recursive: true });

  const unit = `[Unit]\nDescription=NeoAgent — Proactive personal AI agent\nAfter=network.target\n\n[Service]\nType=simple\nWorkingDirectory=${APP_DIR}\nExecStart=${process.execPath} ${path.join(APP_DIR, 'server', 'index.js')}\nRestart=always\nRestartSec=10\nEnvironmentFile=-${ENV_FILE}\nEnvironment=NODE_ENV=production\nStandardOutput=append:${path.join(LOG_DIR, 'neoagent.log')}\nStandardError=append:${path.join(LOG_DIR, 'neoagent.error.log')}\n\n[Install]\nWantedBy=default.target\n`;

  fs.writeFileSync(SYSTEMD_UNIT, unit);

  runOrThrow('systemctl', ['--user', 'daemon-reload']);
  runOrThrow('systemctl', ['--user', 'enable', 'neoagent']);
  runOrThrow('systemctl', ['--user', 'start', 'neoagent']);
  logOk('systemd user service installed and started');
}

function startFallback() {
  ensureLogDir();
  const out = fs.openSync(path.join(LOG_DIR, 'neoagent.log'), 'a');
  const err = fs.openSync(path.join(LOG_DIR, 'neoagent.error.log'), 'a');

  const child = spawn(process.execPath, [path.join(APP_DIR, 'server', 'index.js')], {
    cwd: APP_DIR,
    detached: true,
    stdio: ['ignore', out, err]
  });
  child.unref();

  fs.mkdirSync(path.join(APP_DIR, 'data'), { recursive: true });
  fs.writeFileSync(path.join(APP_DIR, 'data', 'neoagent.pid'), String(child.pid));
  logOk(`Started detached process (pid ${child.pid})`);
}

async function cmdInstall() {
  heading(`Install ${APP_NAME}`);
  if (!fs.existsSync(ENV_FILE)) {
    logWarn('.env not found; starting setup');
    await cmdSetup();
  }

  installDependencies();

  const platform = detectPlatform();
  if (platform === 'macos' && commandExists('launchctl')) {
    installMacService();
  } else if (platform === 'linux' && commandExists('systemctl')) {
    installLinuxService();
  } else {
    startFallback();
  }

  const port = loadEnvPort();
  logOk(`Running on http://localhost:${port}`);
}

function cmdStart() {
  heading(`Start ${APP_NAME}`);
  const platform = detectPlatform();

  if (platform === 'macos' && fs.existsSync(PLIST_DST)) {
    runQuiet('launchctl', ['load', PLIST_DST]);
    logOk('launchd start requested');
    return;
  }

  if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    runOrThrow('systemctl', ['--user', 'start', 'neoagent']);
    logOk('systemd start requested');
    return;
  }

  startFallback();
}

function cmdStop() {
  heading(`Stop ${APP_NAME}`);
  const platform = detectPlatform();

  if (platform === 'macos' && fs.existsSync(PLIST_DST)) {
    runQuiet('launchctl', ['unload', PLIST_DST]);
    logOk('launchd stop requested');
    return;
  }

  if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    runQuiet('systemctl', ['--user', 'stop', 'neoagent']);
    logOk('systemd stop requested');
    return;
  }

  const pidPath = path.join(APP_DIR, 'data', 'neoagent.pid');
  let stopped = false;
  if (fs.existsSync(pidPath)) {
    const pid = Number(fs.readFileSync(pidPath, 'utf8').trim());
    if (Number.isFinite(pid) && pid > 0) {
      try {
        process.kill(pid, 'SIGTERM');
        logOk(`Stopped pid ${pid}`);
        stopped = true;
      } catch {
        logWarn(`pid ${pid} not running`);
      }
    }
    fs.rmSync(pidPath, { force: true });
  }

  const port = loadEnvPort();
  if (killByPort(port)) {
    logOk(`Stopped process listening on port ${port}`);
    stopped = true;
  }
  if (!stopped) logWarn('No running process found');
}

function cmdRestart() {
  heading(`Restart ${APP_NAME}`);
  cmdStop();
  cmdStart();
}

function cmdUninstall() {
  heading(`Uninstall ${APP_NAME}`);
  const platform = detectPlatform();

  if (platform === 'macos') {
    runQuiet('launchctl', ['unload', PLIST_DST]);
    fs.rmSync(PLIST_DST, { force: true });
    logOk('Removed launchd service');
    return;
  }

  if (platform === 'linux') {
    runQuiet('systemctl', ['--user', 'stop', 'neoagent']);
    runQuiet('systemctl', ['--user', 'disable', 'neoagent']);
    fs.rmSync(SYSTEMD_UNIT, { force: true });
    runQuiet('systemctl', ['--user', 'daemon-reload']);
    logOk('Removed systemd service');
    return;
  }

  cmdStop();
}

async function cmdStatus() {
  heading(`${APP_NAME} Status`);
  const port = loadEnvPort();
  const running = await isPortOpen(port);

  if (running) {
    logOk(`running on http://localhost:${port}`);
  } else {
    logWarn(`not reachable on port ${port}`);
  }

  const gitSha = runQuiet('git', ['rev-parse', '--short', 'HEAD']);
  if (gitSha.status === 0) {
    console.log(`  version ${gitSha.stdout.trim()}`);
  }
}

function cmdLogs() {
  heading('Logs');
  ensureLogDir();
  const log = path.join(LOG_DIR, 'neoagent.log');
  const err = path.join(LOG_DIR, 'neoagent.error.log');
  if (!fs.existsSync(log)) fs.writeFileSync(log, '');
  if (!fs.existsSync(err)) fs.writeFileSync(err, '');

  runOrThrow('tail', ['-f', log, err], { cwd: APP_DIR });
}

function cmdUpdate() {
  heading(`Update ${APP_NAME}`);

  if (fs.existsSync(path.join(APP_DIR, '.git')) && commandExists('git')) {
    const branch = runQuiet('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
    const current = runQuiet('git', ['rev-parse', '--short', 'HEAD']);

    runOrThrow('git', ['fetch', 'origin']);
    if (branch.status === 0) {
      runOrThrow('git', ['pull', '--rebase', 'origin', branch.stdout.trim()]);
    } else {
      runOrThrow('git', ['pull', '--rebase']);
    }

    const next = runQuiet('git', ['rev-parse', '--short', 'HEAD']);
    if (current.status === 0 && next.status === 0 && current.stdout.trim() !== next.stdout.trim()) {
      logOk(`Updated ${current.stdout.trim()} -> ${next.stdout.trim()}`);
      installDependencies();
    } else {
      logOk('Already up to date');
    }
  } else {
    logWarn('No git repo detected; attempting npm global update.');
    if (commandExists('npm')) {
      try {
        runOrThrow('npm', ['install', '-g', 'neoagent@latest']);
        logOk('npm global update completed');
      } catch {
        logWarn('npm global update failed. Run: npm install -g neoagent@latest');
      }
    } else {
      logWarn('npm not found. Cannot perform global update.');
    }
  }

  cmdRestart();
}

function printHelp() {
  console.log(`${APP_NAME} manager`);
  console.log('Usage: neoagent <command>');
  console.log('Commands: install | setup | update | restart | start | stop | status | logs | uninstall');
}

async function runCLI(argv) {
  const command = argv[0] || 'help';

  switch (command) {
    case 'install':
      await cmdInstall();
      break;
    case 'setup':
      await cmdSetup();
      break;
    case 'update':
      cmdUpdate();
      break;
    case 'restart':
      cmdRestart();
      break;
    case 'start':
      cmdStart();
      break;
    case 'stop':
      cmdStop();
      break;
    case 'status':
      await cmdStatus();
      break;
    case 'logs':
      cmdLogs();
      break;
    case 'uninstall':
      cmdUninstall();
      break;
    case 'help':
    case '--help':
    case '-h':
      printHelp();
      break;
    default:
      throw new Error(`Unknown command: ${command}`);
  }
}

module.exports = { runCLI };
