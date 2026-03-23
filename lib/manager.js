const fs = require('fs');
const os = require('os');
const path = require('path');
const net = require('net');
const crypto = require('crypto');
const readline = require('readline');
const { spawn, spawnSync } = require('child_process');
const {
  buildBundledWebClientIfPossible: buildWebClient,
  commandExists: sharedCommandExists,
  hasBundledWebClient,
  withInstallEnv,
} = require('./install_helpers');
const {
  APP_DIR,
  RUNTIME_HOME,
  DATA_DIR,
  LOG_DIR,
  ENV_FILE,
  PID_FILE,
  ensureRuntimeDirs,
  migrateLegacyRuntime
} = require('../runtime/paths');

const APP_NAME = 'NeoAgent';
const SERVICE_LABEL = 'com.neoagent';
const PLIST_SRC = path.join(APP_DIR, 'com.neoagent.plist');
const PLIST_DST = path.join(os.homedir(), 'Library', 'LaunchAgents', 'com.neoagent.plist');
const SYSTEMD_UNIT = path.join(os.homedir(), '.config', 'systemd', 'user', 'neoagent.service');
const FLUTTER_APP_DIR = path.join(APP_DIR, 'flutter_app');
const WEB_CLIENT_DIR = path.join(APP_DIR, 'server', 'public');
const PACKAGE_JSON_PATH = path.join(APP_DIR, 'package.json');

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

function launchctlDomain() {
  if (typeof process.getuid !== 'function') return null;
  return `gui/${process.getuid()}`;
}

function launchctlServiceTarget() {
  const domain = launchctlDomain();
  return domain ? `${domain}/${SERVICE_LABEL}` : SERVICE_LABEL;
}

function loadEnvPort() {
  try {
    const env = fs.readFileSync(ENV_FILE, 'utf8');
    const line = env.split('\n').find((entry) => entry.startsWith('PORT='));
    if (!line) return 3333;
    const raw = line.split('=')[1]?.trim();
    const num = Number(raw);
    return Number.isFinite(num) && num > 0 ? num : 3333;
  } catch {
    return 3333;
  }
}

function readEnvFileRaw() {
  if (!fs.existsSync(ENV_FILE)) return '';
  return fs.readFileSync(ENV_FILE, 'utf8');
}

function parseEnv(raw) {
  const lines = raw.split('\n');
  const map = new Map();
  for (const line of lines) {
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const idx = line.indexOf('=');
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1);
    if (key) map.set(key, value);
  }
  return map;
}

function upsertEnvValue(key, value) {
  const raw = readEnvFileRaw();
  const lines = raw ? raw.split('\n') : [];
  let replaced = false;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(`${key}=`)) {
      lines[i] = `${key}=${value}`;
      replaced = true;
      break;
    }
  }

  if (!replaced) lines.push(`${key}=${value}`);
  const output = lines.filter((_, idx, arr) => idx !== arr.length - 1 || arr[idx] !== '').join('\n') + '\n';
  fs.writeFileSync(ENV_FILE, output, { mode: 0o600 });
}

function removeEnvValue(key) {
  const raw = readEnvFileRaw();
  if (!raw) return false;
  const lines = raw.split('\n').filter((line) => !line.startsWith(`${key}=`));
  const output = lines.filter((_, idx, arr) => idx !== arr.length - 1 || arr[idx] !== '').join('\n') + '\n';
  fs.writeFileSync(ENV_FILE, output, { mode: 0o600 });
  return true;
}

function maskEnvValue(key, value) {
  if (!/(KEY|TOKEN|SECRET|PASSWORD)/i.test(key)) return value;
  const text = String(value || '');
  if (text.length <= 8) return '********';
  return `${text.slice(0, 4)}...${text.slice(-4)}`;
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

function readInstalledPackageVersion() {
  try {
    const pkg = JSON.parse(fs.readFileSync(PACKAGE_JSON_PATH, 'utf8'));
    return pkg.version || 'unknown';
  } catch {
    return 'unknown';
  }
}

function readGitVersionLabel() {
  const gitVersion = runQuiet('git', ['describe', '--tags', '--always', '--dirty']);
  if (gitVersion.status !== 0) return null;
  return gitVersion.stdout.trim().replace(/^v/, '') || null;
}

function currentInstalledVersionLabel() {
  const pkg = readInstalledPackageVersion();
  const git = readGitVersionLabel();
  if (git && git !== pkg) {
    return `${pkg} (${git})`;
  }
  return pkg;
}

function commandExists(cmd) {
  return sharedCommandExists((command, args) => runQuiet(command, args), cmd);
}

function ensureLogDir() {
  ensureRuntimeDirs();
}

function backupRuntimeData() {
  const backupsDir = path.join(RUNTIME_HOME, 'backups');
  fs.mkdirSync(backupsDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const target = path.join(backupsDir, `pre-update-${stamp}`);
  fs.mkdirSync(target, { recursive: true });

  if (fs.existsSync(ENV_FILE)) fs.copyFileSync(ENV_FILE, path.join(target, '.env'));
  if (fs.existsSync(DATA_DIR)) fs.cpSync(DATA_DIR, path.join(target, 'data'), { recursive: true, force: false, errorOnExist: false });
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

function listNeoAgentServerProcesses() {
  const res = runQuiet('ps', ['-axo', 'pid=,ppid=,command=']);
  if (res.status !== 0) return [];

  return res.stdout
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(\d+)\s+(\d+)\s+(.*)$/);
      if (!match) return null;
      return {
        pid: Number(match[1]),
        ppid: Number(match[2]),
        command: match[3],
      };
    })
    .filter(Boolean)
    .filter((entry) =>
      entry.pid !== process.pid &&
      /(^|\s)node(\s|$)/.test(entry.command) &&
      (
        entry.command.includes('/neoagent/server/index.js') ||
        entry.command.includes(`${path.sep}NeoAgent${path.sep}server${path.sep}index.js`) ||
        entry.command.includes(`${APP_DIR}${path.sep}server${path.sep}index.js`)
      )
    );
}

function killNeoAgentServerProcesses() {
  const processes = listNeoAgentServerProcesses();
  let killed = false;
  for (const proc of processes) {
    try {
      process.kill(proc.pid, 'SIGTERM');
      killed = true;
    } catch {
      // Ignore stale processes.
    }
  }
  return { killed, processes };
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
  ensureRuntimeDirs();

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

  const port = await ask('Server port', current.PORT || '3333');
  const sessionSecret = await ask('Session secret', current.SESSION_SECRET || randomSecret());
  const anthropic = await ask('Anthropic API key', current.ANTHROPIC_API_KEY || '');
  const openai = await ask('OpenAI API key', current.OPENAI_API_KEY || '');
  const xai = await ask('xAI API key', current.XAI_API_KEY || '');
  const google = await ask('Google API key', current.GOOGLE_AI_KEY || '');
  const minimax = await ask('MiniMax Code key', current.MINIMAX_API_KEY || '');
  const brave = await ask('Brave Search API key', current.BRAVE_SEARCH_API_KEY || '');
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
    minimax ? `MINIMAX_API_KEY=${minimax}` : '',
    brave ? `BRAVE_SEARCH_API_KEY=${brave}` : '',
    ollama ? `OLLAMA_URL=${ollama}` : '',
    origins ? `ALLOWED_ORIGINS=${origins}` : ''
  ].filter(Boolean);

  fs.writeFileSync(ENV_FILE, `${lines.join('\n')}\n`, { mode: 0o600 });
  logOk(`Wrote ${ENV_FILE}`);
}

function installDependencies() {
  heading('Dependencies');
  runOrThrow('npm', ['install', '--omit=dev', '--no-audit', '--no-fund'], {
    env: withInstallEnv()
  });
  logOk('Dependencies installed');
}

function buildBundledWebClientIfPossible({ required = false } = {}) {
  heading('Web Client');
  return buildWebClient({
    flutterAppDir: FLUTTER_APP_DIR,
    webClientDir: WEB_CLIENT_DIR,
    runCommand: (command, args, options = {}) =>
      runQuiet(command, args, options.stdio ? options : { ...options, stdio: 'inherit' }),
    commandExistsFn: commandExists,
    onMissingSources: () =>
      logWarn('Flutter app sources not found; keeping existing bundled web client'),
    onUsingBundledClient: () => logOk('Using bundled Flutter web client'),
    onMissingFlutter: () => logWarn('Flutter SDK not found; using bundled web client'),
    onBuildSuccess: () => logOk('Bundled Flutter web client updated'),
    fail: (message) => {
      throw new Error(message);
    },
    required,
  });
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
    .replace(/__NODE_BIN__/g, nodeBin)
    .replace(/__APP_DIR__/g, APP_DIR)
    .replace(/__HOME__/g, os.homedir())
    .replace(/__RUNTIME_HOME__/g, RUNTIME_HOME)
    .replace(/__LOG_DIR__/g, LOG_DIR);

  fs.writeFileSync(PLIST_DST, content);

  const domain = launchctlDomain();
  if (domain) {
    runQuiet('launchctl', ['bootout', domain, PLIST_DST]);
    const bootstrap = runQuiet('launchctl', ['bootstrap', domain, PLIST_DST]);
    if (bootstrap.status !== 0) {
      runQuiet('launchctl', ['unload', PLIST_DST]);
      runOrThrow('launchctl', ['load', PLIST_DST]);
    } else {
      runQuiet('launchctl', ['enable', launchctlServiceTarget()]);
      runQuiet('launchctl', ['kickstart', '-k', launchctlServiceTarget()]);
    }
  } else {
    runQuiet('launchctl', ['unload', PLIST_DST]);
    runOrThrow('launchctl', ['load', PLIST_DST]);
  }
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

  fs.writeFileSync(PID_FILE, String(child.pid));
  logOk(`Started detached process (pid ${child.pid})`);
}

async function cmdInstall() {
  heading(`Install ${APP_NAME}`);
  if (!fs.existsSync(ENV_FILE)) {
    logWarn('.env not found; starting setup');
    await cmdSetup();
  }

  installDependencies();
  buildBundledWebClientIfPossible({ required: true });

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
    installMacService();
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
    const domain = launchctlDomain();
    if (domain) {
      runQuiet('launchctl', ['bootout', domain, PLIST_DST]);
      runQuiet('launchctl', ['bootout', launchctlServiceTarget()]);
    }
    runQuiet('launchctl', ['unload', PLIST_DST]);
    logOk('launchd stop requested');
  } else if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    runQuiet('systemctl', ['--user', 'stop', 'neoagent']);
    logOk('systemd stop requested');
  } else {
    const pidPath = PID_FILE;
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

  const port = loadEnvPort();
  const { killed, processes } = killNeoAgentServerProcesses();
  if (killed) {
    logOk(`Stopped ${processes.length} extra NeoAgent process${processes.length === 1 ? '' : 'es'}`);
  }
  if (killByPort(port)) {
    logOk(`Stopped process listening on port ${port}`);
  }
}

function cmdRestart() {
  heading(`Restart ${APP_NAME}`);
  buildBundledWebClientIfPossible();
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

  console.log(`  install root ${APP_DIR}`);
  console.log(`  version ${currentInstalledVersionLabel()}`);

  const processes = listNeoAgentServerProcesses();
  if (processes.length > 0) {
    console.log(`  neoagent pids ${processes.map((proc) => proc.pid).join(', ')}`);
    if (processes.length > 1) {
      logWarn(`multiple NeoAgent server processes detected (${processes.length})`);
    }
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
  migrateLegacyRuntime((msg) => logInfo(msg));
  ensureRuntimeDirs();
  const versionBefore = currentInstalledVersionLabel();
  let versionAfter = versionBefore;

  if (fs.existsSync(path.join(APP_DIR, '.git')) && commandExists('git')) {
    const branch = runQuiet('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
    const current = runQuiet('git', ['rev-parse', '--short', 'HEAD']);

    runOrThrow('git', ['fetch', 'origin']);
    if (branch.status === 0) {
      runOrThrow('git', ['pull', '--rebase', '--autostash', 'origin', branch.stdout.trim()]);
    } else {
      runOrThrow('git', ['pull', '--rebase', '--autostash']);
    }

    const next = runQuiet('git', ['rev-parse', '--short', 'HEAD']);
    if (current.status === 0 && next.status === 0 && current.stdout.trim() !== next.stdout.trim()) {
      logOk(`Updated ${current.stdout.trim()} -> ${next.stdout.trim()}`);
      installDependencies();
      buildBundledWebClientIfPossible();
    } else {
      logOk('Already up to date');
      buildBundledWebClientIfPossible();
    }
  } else {
    logWarn('No git repo detected; attempting npm global update.');
    if (commandExists('npm')) {
      try {
        backupRuntimeData();
        runOrThrow('npm', ['install', '-g', 'neoagent@latest', '--force'], {
          env: withInstallEnv()
        });
        logOk('npm global update completed (forced reinstall)');
      } catch {
        logWarn('npm global update failed. Run: npm install -g neoagent@latest --force');
      }
    } else {
      logWarn('npm not found. Cannot perform global update.');
    }
  }

  versionAfter = currentInstalledVersionLabel();

  if (!hasBundledWebClient(WEB_CLIENT_DIR)) {
    throw new Error('No bundled Flutter web client found after update.');
  }

  cmdRestart();
  logOk(`Installed version ${versionBefore} -> ${versionAfter}`);
}

async function cmdEnv(args = []) {
  heading('Environment Variables');
  let action = args[0];

  if (!action) {
    const picked = await ask('Action (list/get/set/unset)', 'list');
    action = (picked || 'list').trim().toLowerCase();
  }

  if (action === 'list') {
    const env = parseEnv(readEnvFileRaw());
    if (env.size === 0) {
      logWarn(`No .env found at ${ENV_FILE}`);
      return;
    }
    for (const [k, v] of [...env.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
      console.log(`${k}=${maskEnvValue(k, v)}`);
    }
    return;
  }

  if (action === 'get') {
    const key = args[1] || await ask('Key', 'PORT');
    if (!key) throw new Error('Usage: neoagent env get <KEY>');
    const env = parseEnv(readEnvFileRaw());
    if (!env.has(key)) throw new Error(`Key not found: ${key}`);
    console.log(env.get(key));
    return;
  }

  if (action === 'set') {
    const key = args[1] || await ask('Key', 'PORT');
    const value = args.slice(2).join(' ') || await ask('Value', key === 'PORT' ? '3333' : '');
    if (!key || !value) throw new Error('Usage: neoagent env set <KEY> <VALUE>');
    upsertEnvValue(key, value);
    logOk(`Set ${key} in ${ENV_FILE}`);
    return;
  }

  if (action === 'unset') {
    const key = args[1] || await ask('Key', 'PORT');
    if (!key) throw new Error('Usage: neoagent env unset <KEY>');
    removeEnvValue(key);
    logOk(`Removed ${key} from ${ENV_FILE}`);
    return;
  }

  throw new Error('Usage: neoagent env [list|get|set|unset] ...');
}

function printHelp() {
  console.log(`${APP_NAME} manager`);
  console.log('Usage: neoagent <command>');
  console.log('Commands: install | setup | env | update | restart | start | stop | status | logs | uninstall');
  console.log('Env usage: neoagent env list | neoagent env get PORT | neoagent env set PORT 3333 | neoagent env unset PORT');
}

async function runCLI(argv) {
  migrateLegacyRuntime((msg) => logInfo(msg));
  ensureRuntimeDirs();
  const command = argv[0] || 'help';

  switch (command) {
    case 'install':
      await cmdInstall();
      break;
    case 'setup':
      await cmdSetup();
      break;
    case 'env':
      await cmdEnv(argv.slice(1));
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
