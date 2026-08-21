'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const net = require('net');
const crypto = require('crypto');
const readline = require('readline');
const { spawnSync } = require('child_process');
const { CLAUDE_CODE_SCOPES } = require('../server/services/ai/providers/claudeCode');
const {
  getGrokOAuthTokenExpiresAt,
  GROK_OAUTH_SCOPES,
  GROK_OAUTH_CLIENT_ID,
} = require('../server/services/ai/providers/grokOauth');
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
  DATABASE_FILE,
  PID_FILE,
  SETUP_STATE_FILE,
  getDefaultVmBaseImageUrl,
  ensureRuntimeDirs,
  migrateLegacyRuntime,
  removeEnvValue: removeRuntimeEnvValue,
  upsertEnvValue: upsertRuntimeEnvValue,
} = require('../runtime/paths');
const {
  SETUP_PROFILES,
  clearSetupState,
  createInstallPlan,
  findAvailablePort,
  normalizeSetupProfile,
  parseSetupArguments,
  readSetupState,
  writeSetupState,
} = require('./setup/profiles');
const { SetupEventWriter } = require('./setup/events');
const { DEFAULT_NEOAGENT_PORT } = require('./setup/contract');
const {
  prepareFullSetupResume,
  runFullSetup,
} = require('./setup/full_setup');
const { createServiceAdapters } = require('./setup/service_adapters');
const {
  parseReleaseChannel,
  getReleaseChannelBranch,
  getReleaseChannelDistTag,
  readConfiguredReleaseChannel,
  writeReleaseChannelToEnvFile,
  describeReleaseChannelPolicy,
  choosePreferredBranchForChannel,
  choosePreferredNpmTagForChannel,
} = require('../runtime/release_channel');
const { parseEnv } = require('../runtime/env');
const { createGitHelpers } = require('../runtime/git_helpers');
const {
  parseDeploymentMode
} = require('../server/utils/deployment');
const {
  AI_PROVIDER_DEFINITIONS,
} = require('../server/services/ai/provider_definitions');
const {
  detectSourceAgents,
  cmdMigrateDryRun,
  cmdMigrateRun
} = require('./migrations');
const { fetchResponseText } = require('../server/services/network/http');
const { abortableDelay } = require('../server/utils/retry');

const APP_NAME = 'NeoAgent';
const SERVICE_LABEL = 'com.neoagent';
const PLIST_DST = path.join(os.homedir(), 'Library', 'LaunchAgents', 'com.neoagent.plist');
const SYSTEMD_UNIT = path.join(os.homedir(), '.config', 'systemd', 'user', 'neoagent.service');
const FLUTTER_APP_DIR = path.join(APP_DIR, 'flutter_app');
const WEB_CLIENT_DIR = path.join(APP_DIR, 'server', 'public');
const PACKAGE_JSON_PATH = path.join(APP_DIR, 'package.json');
const API_KEY_PROVIDERS = Object.freeze(
  Object.values(AI_PROVIDER_DEFINITIONS)
    .filter((definition) => definition.authentication === 'api_key'),
);

const COLORS = process.stdout.isTTY
  ? {
      reset: '\x1b[0m',
      bold: '\x1b[1m',
      red: '\x1b[1;31m',
      green: '\x1b[1;32m',
      yellow: '\x1b[1;33m',
      blue: '\x1b[1;34m',
      magenta: '\x1b[1;35m',
      cyan: '\x1b[1;36m',
      dim: '\x1b[2m'
    }
  : { reset: '', bold: '', red: '', green: '', yellow: '', blue: '', magenta: '', cyan: '', dim: '' };

const CLI_INTERACTIVE = process.stdout.isTTY;
let cliJsonOutput = false;
let setupEventWriter = null;
const installActionItems = [];

async function fetchBoundedJsonResponse(url, init = {}, label = 'Authentication request') {
  const { response, text } = await fetchResponseText(url, {
    ...init,
    redirect: init.redirect || 'error',
    timeoutMs: init.timeoutMs || 20000,
    maxResponseBytes: init.maxResponseBytes || 1024 * 1024,
    serviceName: label,
    timeoutCode: 'AUTH_HTTP_TIMEOUT',
    tooLargeCode: 'AUTH_RESPONSE_TOO_LARGE',
  });
  let data = null;
  try {
    data = JSON.parse(text || '{}');
  } catch {
    data = null;
  }
  return { response, text, data };
}

async function fetchAuthJson(url, init = {}, label = 'Authentication request') {
  const result = await fetchBoundedJsonResponse(url, init, label);
  if (!result.response.ok) {
    throw new Error(
      `${label} failed: HTTP ${result.response.status} — ${result.text.slice(0, 500) || 'empty response'}`,
    );
  }
  if (!result.data || typeof result.data !== 'object') {
    throw new Error(`${label} returned malformed JSON.`);
  }
  return result.data;
}

function logInfo(msg) {
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.message(msg);
    return;
  }
  const mark = CLI_INTERACTIVE ? `${COLORS.blue}◇${COLORS.reset}` : '->';
  console.log(`  ${mark} ${msg}`);
}

function logOk(msg) {
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.message(msg);
    return;
  }
  const mark = CLI_INTERACTIVE ? `${COLORS.green}◆${COLORS.reset}` : 'ok';
  console.log(`  ${mark} ${msg}`);
}

function logWarn(msg) {
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.message(msg, { warning: true });
    return;
  }
  const mark = CLI_INTERACTIVE ? `${COLORS.yellow}▲${COLORS.reset}` : 'warn';
  console.warn(`  ${mark} ${msg}`);
}

function logErr(msg) {
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.message(msg, { error: true });
    return;
  }
  const mark = CLI_INTERACTIVE ? `${COLORS.red}✕${COLORS.reset}` : 'err';
  console.error(`  ${mark} ${msg}`);
}

function heading(text) {
  if (cliJsonOutput) return;
  if (!CLI_INTERACTIVE) {
    console.log(`\n${text}`);
    return;
  }
  console.log(`\n${COLORS.bold}${COLORS.cyan}${text}${COLORS.reset}`);
}

function cliBanner(title = APP_NAME, subtitle = 'local agent control') {
  if (cliJsonOutput) return;
  if (!CLI_INTERACTIVE) return;
  const c = COLORS;
  const width = 38;
  const stripAnsi = (text) => String(text).replace(/\x1b\[[0-9;]*m/g, '');
  const boxLine = (content) => {
    const padding = Math.max(0, width - stripAnsi(content).length);
    console.log(`  ${c.cyan}│${c.reset} ${content}${' '.repeat(padding)} ${c.cyan}│${c.reset}`);
  };
  console.log('');
  console.log(`  ${c.cyan}╭────────────────────────────────────────╮${c.reset}`);
  boxLine(`${c.bold}${c.magenta}NeoAgent${c.reset} ${c.dim}arcade ops console${c.reset}`);
  boxLine(`${c.bold}${title}${c.reset} ${c.dim}${subtitle}${c.reset}`);
  console.log(`  ${c.cyan}╰────────────────────────────────────────╯${c.reset}`);
}

function cliSection(text) {
  if (cliJsonOutput) return;
  if (CLI_INTERACTIVE) {
    console.log(`${COLORS.dim}  ──${COLORS.reset} ${COLORS.bold}${text}${COLORS.reset}`);
  } else {
    console.log(text);
  }
}

function statusLine(ok, label, value, hint = '') {
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.message(`${label}: ${value}${hint ? ` (${hint})` : ''}`);
    return;
  }
  const mark = ok ? (CLI_INTERACTIVE ? `${COLORS.green}●${COLORS.reset}` : 'ok') : (CLI_INTERACTIVE ? `${COLORS.yellow}●${COLORS.reset}` : 'warn');
  const padded = String(label).padEnd(9);
  const suffix = hint ? ` ${COLORS.dim}${hint}${COLORS.reset}` : '';
  console.log(`  ${mark} ${padded} ${value}${suffix}`);
}

function rememberInstallAction(message) {
  if (!installActionItems.includes(message)) {
    installActionItems.push(message);
  }
}

function printInstallActionItems() {
  if (installActionItems.length === 0) return;
  heading('Post-install actions');
  for (const item of installActionItems) {
    logWarn(item);
  }
}

function detectPlatform() {
  if (process.platform === 'darwin') return 'macos';
  if (process.platform === 'linux') return 'linux';
  if (process.platform === 'win32') return 'windows';
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
    if (!line) return DEFAULT_NEOAGENT_PORT;
    const raw = line.split('=')[1]?.trim();
    const num = Number(raw);
    return Number.isFinite(num) && num > 0 ? num : DEFAULT_NEOAGENT_PORT;
  } catch {
    return DEFAULT_NEOAGENT_PORT;
  }
}

function readEnvFileRaw() {
  if (!fs.existsSync(ENV_FILE)) return '';
  return fs.readFileSync(ENV_FILE, 'utf8');
}

function sanitizeEnvKey(key) {
  return String(key).replace(/[\r\n]/g, '');
}

function validateEnvKey(key) {
  if (!/^[A-Z][A-Z0-9_]*$/.test(key)) {
    throw new Error(`Invalid env key "${key}". Keys must be uppercase letters, digits, and underscores (e.g. PORT, ANTHROPIC_API_KEY).`);
  }
}

function upsertEnvValue(key, value) {
  upsertRuntimeEnvValue(ENV_FILE, key, value);
}

function removeEnvValue(key) {
  return removeRuntimeEnvValue(ENV_FILE, sanitizeEnvKey(key));
}

function readAdminCredentials() {
  const env = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());
  return {
    username: env.ADMIN_USERNAME || 'admin',
    password: env.ADMIN_PASSWORD || '(not set — run `neoagent setup`)',
  };
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

const {
  latestGitTagVersion,
  gitWorkingTreeDirty,
  gitLocalBranchExists,
  gitRemoteBranchExists,
} = createGitHelpers((cmd, args) => runQuiet(cmd, args));

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

function currentReleaseChannel() {
  return readConfiguredReleaseChannel({ envFile: ENV_FILE });
}

function releaseChannelSummary(channel) {
  return describeReleaseChannelPolicy(parseReleaseChannel(channel) || currentReleaseChannel());
}

function resolvePreferredGitBranch(channel) {
  const normalized = parseReleaseChannel(channel) || currentReleaseChannel();
  if (normalized === 'stable') {
    return getReleaseChannelBranch(normalized);
  }

  const stableVersion = latestGitTagVersion('v[0-9]*.[0-9]*.[0-9]*');
  const betaVersion = latestGitTagVersion('v[0-9]*.[0-9]*.[0-9]*-beta.*');
  const preferred = choosePreferredBranchForChannel(normalized, {
    stable: stableVersion,
    beta: betaVersion,
  });

  if (preferred === 'beta' && !gitRemoteBranchExists('beta')) {
    return 'main';
  }
  return preferred;
}

function resolvePreferredNpmTag(channel) {
  const normalized = parseReleaseChannel(channel) || currentReleaseChannel();
  if (normalized === 'stable') {
    return getReleaseChannelDistTag(normalized);
  }

  const distTags = {};
  const tagsRes = runQuiet('npm', ['view', 'neoagent', 'dist-tags', '--json'], {
    env: withInstallEnv(),
  });
  if (tagsRes.status === 0) {
    try {
      const parsed = JSON.parse(tagsRes.stdout || '{}');
      if (parsed && typeof parsed === 'object') {
        Object.assign(distTags, parsed);
      }
    } catch {
      // Ignore parse failures and fall back to the beta tag.
    }
  }

  return choosePreferredNpmTagForChannel(normalized, {
    latest: distTags.latest,
    beta: distTags.beta,
  });
}

function ensureGitBranchForReleaseChannel(targetBranch) {
  const branchRes = runQuiet('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  const currentBranch = branchRes.status === 0 ? branchRes.stdout.trim() : '';
  if (currentBranch === targetBranch) {
    return currentBranch;
  }

  if (!gitRemoteBranchExists(targetBranch)) {
    throw new Error(`Release channel branch "${targetBranch}" was not found on origin.`);
  }

  if (gitWorkingTreeDirty()) {
    throw new Error(
      `Cannot switch to ${targetBranch} while the git worktree has local changes. Commit or stash them first, then rerun the update.`,
    );
  }

  if (gitLocalBranchExists(targetBranch)) {
    runOrThrow('git', ['checkout', targetBranch]);
  } else {
    runOrThrow('git', ['checkout', '-b', targetBranch, '--track', `origin/${targetBranch}`]);
  }

  if (currentBranch) {
    logOk(`Switched git branch ${currentBranch} -> ${targetBranch}`);
  } else {
    logOk(`Checked out git branch ${targetBranch}`);
  }
  return targetBranch;
}

function ensureLogDir() {
  ensureRuntimeDirs();
}

function pruneOldRuntimeBackups(backupsDir, keepLatest = 3) {
  if (!fs.existsSync(backupsDir) || keepLatest < 0) return;

  const backupDirs = fs
    .readdirSync(backupsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && entry.name.startsWith('pre-update-'))
    .map((entry) => {
      const fullPath = path.join(backupsDir, entry.name);
      let mtimeMs = 0;
      try {
        mtimeMs = fs.statSync(fullPath).mtimeMs;
      } catch {
        // Skip entries that disappear or cannot be statted.
        return null;
      }
      return { name: entry.name, fullPath, mtimeMs };
    })
    .filter(Boolean)
    .sort((a, b) => {
      if (b.mtimeMs !== a.mtimeMs) return b.mtimeMs - a.mtimeMs;
      return b.name.localeCompare(a.name);
    });

  for (const backup of backupDirs.slice(keepLatest)) {
    try {
      fs.rmSync(backup.fullPath, { recursive: true, force: true });
    } catch {
      // Best-effort cleanup only.
    }
  }
}

function backupRuntimeData({ prefix = 'pre-update' } = {}) {
  const backupsDir = path.join(RUNTIME_HOME, 'backups');
  fs.mkdirSync(backupsDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/:/g, '-').replace(/\.\d{3}Z$/, 'Z');
  const target = path.join(backupsDir, `${prefix}-${stamp}`);
  fs.mkdirSync(target, { recursive: true });

  if (fs.existsSync(ENV_FILE)) fs.copyFileSync(ENV_FILE, path.join(target, '.env'));
  if (fs.existsSync(DATA_DIR)) {
    const excludedRoots = [
      path.join(DATA_DIR, 'computers'),
      path.join(DATA_DIR, 'teach-sessions'),
    ].map((value) => path.resolve(value));
    fs.cpSync(DATA_DIR, path.join(target, 'data'), {
      recursive: true,
      force: false,
      errorOnExist: false,
      filter: (source) => {
        const resolved = path.resolve(source);
        return !excludedRoots.some((root) => resolved === root || resolved.startsWith(`${root}${path.sep}`));
      },
    });
  }
  pruneOldRuntimeBackups(backupsDir, 3);
  return target;
}

async function backupComputerDisks(target) {
  const { resolveQemuImgBinary } = require('../server/services/runtime/qemu_vm_manager');
  const qemuImg = resolveQemuImgBinary();
  const instancesRoot = path.join(DATA_DIR, 'computers', 'instances');
  if (!qemuImg || !fs.existsSync(instancesRoot)) return { disks: 0 };
  const outputRoot = path.join(target, 'data', 'computers', 'instances');
  let disks = 0;
  for (const entry of fs.readdirSync(instancesRoot, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const sourceDirectory = path.join(instancesRoot, entry.name);
    const outputDirectory = path.join(outputRoot, entry.name);
    fs.mkdirSync(outputDirectory, { recursive: true, mode: 0o700 });
    for (const name of ['base-build', 'guest-token', 'workspace-migration.json']) {
      const source = path.join(sourceDirectory, name);
      if (fs.existsSync(source)) fs.copyFileSync(source, path.join(outputDirectory, name));
    }
    for (const name of fs.readdirSync(sourceDirectory).filter((value) => value.endsWith('.qcow2'))) {
      const source = path.join(sourceDirectory, name);
      const destination = path.join(outputDirectory, name);
      const converted = runQuiet(qemuImg, ['convert', '-O', 'qcow2', '-c', source, destination]);
      if (converted.status !== 0) {
        throw new Error(`Computer disk backup failed for ${entry.name}/${name}: ${converted.stderr.trim() || converted.stdout.trim()}`);
      }
      const checked = runQuiet(qemuImg, ['check', destination]);
      if (checked.status !== 0) throw new Error(`Computer disk backup verification failed for ${entry.name}/${name}.`);
      disks += 1;
    }
  }
  const profile = path.join(RUNTIME_HOME, 'computer-runtime', 'profile.json');
  if (fs.existsSync(profile)) {
    const destination = path.join(target, 'computer-runtime', 'profile.json');
    fs.mkdirSync(path.dirname(destination), { recursive: true, mode: 0o700 });
    fs.copyFileSync(profile, destination);
  }
  return { disks };
}

function repairComputerDisks() {
  const { resolveQemuImgBinary } = require('../server/services/runtime/qemu_vm_manager');
  const qemuImg = resolveQemuImgBinary();
  const instancesRoot = path.join(DATA_DIR, 'computers', 'instances');
  if (!qemuImg || !fs.existsSync(instancesRoot)) return { checked: 0, repaired: 0 };
  let checked = 0;
  let repaired = 0;
  const pending = [instancesRoot];
  while (pending.length > 0) {
    const directory = pending.pop();
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) pending.push(target);
      if (!entry.isFile() || !entry.name.endsWith('.qcow2')) continue;
      checked += 1;
      const check = runQuiet(qemuImg, ['check', target]);
      if (check.status === 0) continue;
      const repair = runQuiet(qemuImg, ['check', '-r', 'leaks', target]);
      if (repair.status !== 0) throw new Error(`Computer disk repair failed: ${target}`);
      repaired += 1;
    }
  }
  return { checked, repaired };
}

function killByPort(port) {
  if (!commandExists('lsof')) return false;
  const normalizedPort = Number(port);
  if (!Number.isInteger(normalizedPort) || normalizedPort <= 0 || normalizedPort > 65535) {
    return false;
  }
  const res = runQuiet('lsof', ['-ti', `tcp:${normalizedPort}`]);
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

  const normalizedAppIndexPath = path.join(APP_DIR, 'server', 'index.js').replace(/\\/g, '/');
  const escapedAppIndexPath = normalizedAppIndexPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const appIndexPattern = new RegExp(`(^|\\s|["'])${escapedAppIndexPath}(?=$|\\s|["'])`);
  const genericNeoAgentPattern = /(^|[\s"'])[^\s"']*\/neoagent\/server\/index\.js(?=$|[\s"'])/i;
  const repoNamePattern = new RegExp(`(^|[\\s"'])[^\\s"']*${path.sep === '\\' ? '\\\\' : '/'}NeoAgent${path.sep === '\\' ? '\\\\' : '/'}server${path.sep === '\\' ? '\\\\' : '/'}index\\.js(?=$|[\\s"'])`, 'i');

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
    .filter((entry) => {
      if (entry.pid === process.pid) return false;
      const cmd = String(entry.command || '');
      const cmdNormalized = cmd.replace(/\\/g, '/');
      const executablePart = cmd.split(/\s+/)[0] || '';
      const executableBase = path.basename(executablePart);
      const isNode = /^node\d*$/.test(executableBase) || /(^|\s)node\d*(\s|$)/.test(cmd);
      return isNode && (
        appIndexPattern.test(cmdNormalized) ||
        genericNeoAgentPattern.test(cmdNormalized) ||
        repoNamePattern.test(cmd)
      );
    });
}

function scanForInstalledInstance({
  platform = detectPlatform(),
  databaseFile = DATABASE_FILE,
  macServiceFile = PLIST_DST,
  linuxServiceFile = SYSTEMD_UNIT,
  serverProcesses = listNeoAgentServerProcesses(),
} = {}) {
  const evidence = [];

  if (fs.existsSync(databaseFile)) {
    evidence.push({ type: 'runtime-data', path: databaseFile });
  }
  if (platform === 'macos' && fs.existsSync(macServiceFile)) {
    evidence.push({ type: 'launchd-service', path: macServiceFile });
  }
  if (platform === 'linux' && fs.existsSync(linuxServiceFile)) {
    evidence.push({ type: 'systemd-service', path: linuxServiceFile });
  }
  if (serverProcesses.length > 0) {
    evidence.push({
      type: 'running-server',
      pids: serverProcesses.map((processInfo) => processInfo.pid),
    });
  }

  return {
    installed: evidence.length > 0,
    evidence,
  };
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

async function askSecret(question, currentValue = '') {
  if (
    !process.stdin.isTTY ||
    !process.stdout.isTTY ||
    typeof process.stdin.setRawMode !== 'function'
  ) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise((resolve) => {
      const suffix = currentValue ? ' [configured]' : '';
      rl.question(`  ? ${question}${suffix}: `, (answer) => {
        rl.close();
        const trimmed = answer.trim();
        resolve(trimmed || currentValue);
      });
    });
  }

  const input = process.stdin;
  const output = process.stdout;
  const wasRaw = Boolean(input.isRaw);
  const wasPaused = input.isPaused();

  output.write(`  ? ${question}${currentValue ? ' [configured]' : ''}: `);

  return new Promise((resolve, reject) => {
    let value = '';
    let escapeSequenceState = 0;

    const eraseLastMask = () => output.write('\b \b');
    const cleanup = () => {
      input.removeListener('data', onData);
      input.setRawMode(wasRaw);
      if (wasPaused) input.pause();
    };
    const finish = () => {
      cleanup();
      output.write('\n');
      resolve(value || currentValue);
    };
    const onData = (chunk) => {
      for (const character of String(chunk)) {
        if (escapeSequenceState === 1) {
          escapeSequenceState = character === '[' || character === 'O' ? 2 : 0;
          continue;
        }
        if (escapeSequenceState === 2) {
          if (/[@-~]/.test(character)) escapeSequenceState = 0;
          continue;
        }
        if (character === '\u001b') {
          escapeSequenceState = 1;
          continue;
        }
        if (character === '\u0003') {
          cleanup();
          output.write('\n');
          reject(new Error('Setup cancelled.'));
          return;
        }
        if (character === '\r' || character === '\n' || character === '\u0004') {
          finish();
          return;
        }
        if (character === '\b' || character === '\u007f') {
          if (value) {
            value = value.slice(0, -1);
            eraseLastMask();
          }
          continue;
        }
        if (character === '\u0015') {
          while (value) {
            value = value.slice(0, -1);
            eraseLastMask();
          }
          continue;
        }
        if (character >= ' ') {
          value += character;
          output.write('•');
        }
      }
    };

    input.setEncoding('utf8');
    input.setRawMode(true);
    input.resume();
    input.on('data', onData);
  });
}

function parseProviderChoices(answer, providerCount = API_KEY_PROVIDERS.length) {
  const normalized = String(answer || '').trim();
  if (!normalized || normalized === '0') return [];

  const choices = normalized.split(',').map((choice) => Number(choice.trim()));
  if (
    choices.some(
      (choice) => !Number.isInteger(choice) || choice < 1 || choice > providerCount,
    )
  ) {
    throw new Error(`Choose provider numbers from 1 to ${providerCount}, separated by commas.`);
  }
  return [...new Set(choices)];
}

async function cmdApiKeySetup() {
  heading('AI Provider Setup');
  const current = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());

  logInfo('Choose one or more hosted providers. You can also configure these later in Settings.');
  for (const [index, provider] of API_KEY_PROVIDERS.entries()) {
    const configured = String(current[provider.envKey] || '').trim() ? ' (configured)' : '';
    console.log(`  [${index + 1}] ${provider.label}${configured}`);
  }
  console.log('  [0] Skip for now');

  let choices;
  while (!choices) {
    const answer = await ask('Provider numbers, separated by commas', '0');
    try {
      choices = parseProviderChoices(answer);
    } catch (error) {
      logWarn(error.message);
    }
  }
  if (choices.length === 0) {
    logInfo('Skipping hosted provider keys. Local Ollama and the Settings UI remain available.');
    rememberInstallAction('Add a hosted provider later in Settings or with `neoagent setup`.');
    return 0;
  }

  let saved = 0;
  for (const choice of choices) {
    const provider = API_KEY_PROVIDERS[choice - 1];
    const apiKey = await askSecret(
      `${provider.label} API key`,
      current[provider.envKey] || '',
    );
    if (!String(apiKey || '').trim()) {
      logWarn(`${provider.label} was skipped because no key was entered.`);
      continue;
    }
    upsertEnvValue(provider.envKey, apiKey);
    logOk(`${provider.label} API key saved`);
    saved += 1;
  }

  return saved;
}

function defaultEnvLines(current = {}) {
  const defaultVmBaseImageUrl = getDefaultVmBaseImageUrl();
  const port = current.PORT || String(DEFAULT_NEOAGENT_PORT);
  const publicUrl = current.PUBLIC_URL || '';
  const secureCookies = current.SECURE_COOKIES ||
    (String(publicUrl || '').trim().startsWith('https://') ? 'true' : 'false');
  const trustProxy = current.TRUST_PROXY || secureCookies;
  return [
    'NODE_ENV=production',
    `PORT=${port}`,
    publicUrl ? `PUBLIC_URL=${publicUrl}` : '',
    `SECURE_COOKIES=${String(secureCookies || '').trim().toLowerCase() === 'true' ? 'true' : 'false'}`,
    `TRUST_PROXY=${String(trustProxy || '').trim().toLowerCase() === 'true' ? 'true' : 'false'}`,
    `SESSION_SECRET=${current.SESSION_SECRET || randomSecret()}`,
    `NEOAGENT_PROFILE=${current.NEOAGENT_PROFILE || 'prod'}`,
    `NEOAGENT_DEPLOYMENT_MODE=${parseDeploymentMode(current.NEOAGENT_DEPLOYMENT_MODE || 'self_hosted')}`,
    `NEOAGENT_RELEASE_CHANNEL=${parseReleaseChannel(current.NEOAGENT_RELEASE_CHANNEL || 'stable') || 'stable'}`,
    `NEOAGENT_VM_BASE_IMAGE_URL=${current.NEOAGENT_VM_BASE_IMAGE_URL || defaultVmBaseImageUrl}`,
    `NEOAGENT_VM_MEMORY_MB=${current.NEOAGENT_VM_MEMORY_MB || '4096'}`,
    `NEOAGENT_VM_CPUS=${current.NEOAGENT_VM_CPUS || '2'}`,
    `NEOAGENT_VM_GUEST_TOKEN=${current.NEOAGENT_VM_GUEST_TOKEN || randomSecret()}`,
    `ADMIN_USERNAME=${current.ADMIN_USERNAME || 'admin'}`,
    `ADMIN_PASSWORD=${current.ADMIN_PASSWORD || randomSecret()}`,
    current.XAI_BASE_URL ? `XAI_BASE_URL=${current.XAI_BASE_URL}` : 'XAI_BASE_URL=https://api.x.ai/v1',
    current.OLLAMA_URL ? `OLLAMA_URL=${current.OLLAMA_URL}` : 'OLLAMA_URL=http://localhost:11434',
    current.DEEPGRAM_BASE_URL ? `DEEPGRAM_BASE_URL=${current.DEEPGRAM_BASE_URL}` : 'DEEPGRAM_BASE_URL=https://api.deepgram.com',
    current.DEEPGRAM_MODEL ? `DEEPGRAM_MODEL=${current.DEEPGRAM_MODEL}` : 'DEEPGRAM_MODEL=nova-3',
    current.DEEPGRAM_LANGUAGE ? `DEEPGRAM_LANGUAGE=${current.DEEPGRAM_LANGUAGE}` : 'DEEPGRAM_LANGUAGE=multi',
  ].filter(Boolean);
}

function writeDefaultEnvFile({ remindProviderSetup = true, port = null } = {}) {
  ensureRuntimeDirs();
  const current = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());
  const defaults = {
    ...current,
    PORT: current.PORT || (port == null ? '' : String(port)),
  };
  for (const line of defaultEnvLines(defaults)) {
    const separatorIndex = line.indexOf('=');
    const key = line.slice(0, separatorIndex);
    if (String(current[key] || '').trim()) continue;
    upsertEnvValue(key, line.slice(separatorIndex + 1));
  }
  logOk(`Ensured default config at ${ENV_FILE}`);
  if (remindProviderSetup) {
    rememberInstallAction('Add provider keys with `neoagent setup`, `neoagent env set KEY VALUE`, or the login commands when you are ready.');
  }
}

async function cmdFullSetup({
  suggestedPort = null,
  startSectionId = null,
  completedSections = [],
  initialValues = {},
  onTransition = async () => {},
} = {}) {
  return runFullSetup({
    suggestedPort,
    startSectionId,
    completedSections,
    initialValues,
    onTransition,
    io: { ask, askSecret, heading, logInfo, logOk },
  });
}

async function askSetupProfile() {
  heading('Choose setup');
  console.log('  [1] Quickstart — safe defaults, core features first (recommended)');
  console.log('  [2] Full setup — configure every available section');
  const answer = await ask('Setup mode', '1');
  return answer === '2' ? 'full' : 'quick';
}

async function resolveSetupProfile(options) {
  if (options.resume) {
    const state = readSetupState(SETUP_STATE_FILE);
    if (!state) {
      const error = new Error('No interrupted setup was found.');
      error.code = 'SETUP_RESUME_NOT_FOUND';
      throw error;
    }
    return state.profile;
  }
  if (options.profile) return normalizeSetupProfile(options.profile);
  if (
    options.json
    || options.nonInteractive
    || !process.stdin.isTTY
    || !process.stdout.isTTY
  ) {
    return 'quick';
  }
  return askSetupProfile();
}

function validateSetupInteraction(profile, options) {
  const requiresInteractiveFullSetup = normalizeSetupProfile(profile) === 'full'
    && !options.deferOptionalSections
    && (
      options.json
      || options.nonInteractive
      || !process.stdin.isTTY
      || !process.stdout.isTTY
    );
  if (requiresInteractiveFullSetup) {
    const error = new Error(
      'Full setup requires an interactive terminal. Use --quick for unattended setup.',
    );
    error.code = 'SETUP_REQUIRED_VALUE_MISSING';
    throw error;
  }
}

async function runSetupProfile(profile, options = {}) {
  const normalizedProfile = normalizeSetupProfile(profile);
  validateSetupInteraction(normalizedProfile, options);
  const current = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());
  const port = current.PORT
    ? Number(current.PORT)
    : await findAvailablePort(DEFAULT_NEOAGENT_PORT);
  const plan = createInstallPlan({
    profile: normalizedProfile,
    port,
    platform: detectPlatform(),
    existingInstallation: scanForInstalledInstance().installed,
    runtimePackage: options.runtimePackage,
    deferredOptionalSections: options.deferOptionalSections,
  });
  const previousState = options.resume ? readSetupState(SETUP_STATE_FILE) : null;
  const state = writeSetupState(SETUP_STATE_FILE, {
    runId: previousState?.runId || setupEventWriter?.runId,
    profile: normalizedProfile,
    stage: previousState?.stage || 'configuration',
    status: 'in_progress',
    completedSections: previousState?.completedSections || [],
    resumeValues: previousState?.resumeValues || {},
  });
  let completedSections = previousState?.completedSections || [];

  setupEventWriter?.start('configuration', `Preparing ${SETUP_PROFILES[normalizedProfile].label}`, 0.05);
  if (normalizedProfile === 'quick') {
    heading('Quickstart');
    logInfo(`NeoAgent will use port ${port} and a per-user background service.`);
    writeDefaultEnvFile({ remindProviderSetup: false, port });
    writeSetupState(SETUP_STATE_FILE, {
      ...state,
      stage: 'provider',
      completedSections: ['core'],
    });
    completedSections = ['core'];
    if (!options.nonInteractive && process.stdin.isTTY && process.stdout.isTTY) {
      const configureProvider = await ask('Connect an AI provider now? (Y/n)', 'Y');
      if (!['n', 'no'].includes(configureProvider.trim().toLowerCase())) {
        const savedProviders = await cmdApiKeySetup();
        if (savedProviders > 0) completedSections.push('providers');
      } else {
        rememberInstallAction('Connect an AI provider later in Settings or with `neoagent setup`.');
      }
    } else {
      rememberInstallAction('Connect an AI provider later in Settings or with `neoagent setup`.');
    }
  } else if (options.deferOptionalSections && options.nonInteractive) {
    heading('Full setup');
    logInfo(
      `NeoAgent will use port ${port}; the remaining setup sections continue in the app.`,
    );
    writeDefaultEnvFile({ remindProviderSetup: false, port });
    rememberInstallAction(
      'Continue providers, integrations, voice, and optional tools in the NeoAgent app.',
    );
    completedSections = ['core'];
  } else {
    const resume = options.resume
      ? prepareFullSetupResume(previousState)
      : prepareFullSetupResume();
    const result = await cmdFullSetup({
      suggestedPort: port,
      startSectionId: resume.startSectionId,
      completedSections: resume.completedSections,
      initialValues: resume.initialValues,
      onTransition: async (progress) => {
        writeSetupState(SETUP_STATE_FILE, {
          ...state,
          stage: progress.sectionId,
          status: 'in_progress',
          completedSections: progress.completedSections,
          resumeValues: progress.resumeValues,
        });
      },
    });
    completedSections = result.completedSections;
  }

  upsertEnvValue('NEOAGENT_SETUP_PROFILE', normalizedProfile);
  upsertEnvValue('NEOAGENT_SETUP_COMPLETED_SECTIONS', completedSections.join(','));
  writeSetupState(SETUP_STATE_FILE, {
    ...state,
    stage: 'configured',
    status: 'configured',
    completedSections,
  });
  setupEventWriter?.complete('configuration', 'Configuration saved', 0.15);
  return plan;
}

async function cmdSetup(args = []) {
  const options = parseSetupArguments(args);
  const profile = await resolveSetupProfile(options);
  if (!setupEventWriter) {
    setupEventWriter = new SetupEventWriter({
      profile,
      json: options.json,
    });
  }
  setupEventWriter.profile = profile;
  await runSetupProfile(profile, options);
  clearSetupState(SETUP_STATE_FILE);
  setupEventWriter?.complete('setup', 'Setup configuration is complete', 1);
  if (!cliJsonOutput) {
    heading('Setup saved');
    logOk('Run `neoagent install` to install or update the background service.');
  }
}

async function cmdMigrate(args = []) {
  const subcommand = args[0] || 'run';
  const sources = detectSourceAgents();

  if (subcommand === '--help' || subcommand === '-h' || subcommand === 'help') {
    console.log('\nNeoAgent Migration');
    console.log('Usage: neoagent migrate [subcommand]');
    console.log('');
    console.log('Subcommands:');
    console.log('  neoagent migrate           Interactive migration (select sources)');
    console.log('  neoagent migrate dry-run  Preview what would be migrated');
    console.log('  neoagent migrate status   Show detected source agents');
    console.log('  neoagent migrate openclaw-only   Migrate from OpenClaw only');
    console.log('  neoagent migrate hermes-only     Migrate from Hermes only');
    console.log('');
    console.log('Migration searches for:');
    console.log('  - OpenClaw at ~/.openclaw/');
    console.log('  - Hermes at ~/.hermes/');
    console.log('');
    return;
  }

  if (!sources.openclaw && !sources.hermes) {
    logWarn('No OpenClaw or Hermes installation detected.');
    logInfo('Migration searches for:');
    logInfo('  - OpenClaw: ~/.openclaw/');
    logInfo('  - Hermes: ~/.hermes/');
    logInfo('\nIf you have an existing installation at a custom path,');
    logInfo('please ensure the data is accessible and run this command again.');
    logInfo('\nRun `neoagent migrate --help` for usage information.');
    return;
  }

  console.log('\n=== NeoAgent Migration ===\n');
  if (sources.openclaw) logInfo('OpenClaw detected at ~/.openclaw/');
  if (sources.hermes) logInfo('Hermes detected at ~/.hermes/');

  if (subcommand === 'dry-run' || subcommand === '--dry-run') {
    await cmdMigrateDryRun(sources);
    return;
  }

  if (subcommand === 'status') {
    console.log('\nSource agents:');
    console.log(`  OpenClaw: ${sources.openclaw ? 'FOUND' : 'not found'}`);
    console.log(`  Hermes: ${sources.hermes ? 'FOUND' : 'not found'}`);
    console.log('\nRun `neoagent migrate` to start migration.');
    return;
  }

  if (subcommand === 'openclaw-only') {
    await cmdMigrateRun({ openclaw: true, hermes: false });
    return;
  }

  if (subcommand === 'hermes-only') {
    await cmdMigrateRun({ openclaw: false, hermes: true });
    return;
  }

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  console.log('\nWhat would you like to migrate?');
  console.log('  [1] Migrate from all detected sources');
  console.log('  [2] Migrate from OpenClaw only');
  console.log('  [3] Migrate from Hermes only');
  console.log('  [4] Cancel');

  await new Promise((resolve) => {
    rl.question('  Choice [1]: ', async (answer) => {
      rl.close();
      const choice = answer.trim() || '1';

      if (choice === '1') {
        await cmdMigrateRun(sources);
      } else if (choice === '2') {
        await cmdMigrateRun({ openclaw: true, hermes: false });
      } else if (choice === '3') {
        await cmdMigrateRun({ openclaw: false, hermes: true });
      } else {
        console.log('Migration cancelled.');
      }
    });
  });
}

async function pollDeviceCode({
  pollUrl,
  pollBody,
  pollHeaders = {},
  intervalMs,
  timeoutMs,
  onToken,
  signal = null,
}) {
  const start = Date.now();
  let currentInterval = Math.max(1000, Number(intervalMs) || 5000);
  while (Date.now() - start < timeoutMs) {
    await abortableDelay(currentInterval, signal);
    let result;
    try {
      result = await fetchBoundedJsonResponse(pollUrl, {
        method: 'POST',
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', ...pollHeaders },
        body: JSON.stringify(pollBody()),
        signal,
      }, 'Device authorization poll');
    } catch (error) {
      if (signal?.aborted) throw signal.reason || error;
      if (/timed out|fetch failed|ECONNRESET|ECONNREFUSED|socket/i.test(String(error?.message || error))) {
        continue;
      }
      throw error;
    }
    const { response, text, data } = result;
    if (response.status === 403 || response.status === 404) continue;
    if (!response.ok) {
      throw new Error(`Token poll failed: HTTP ${response.status} — ${text.slice(0, 500)}`);
    }
    if (!data || typeof data !== 'object') {
      throw new Error('Device authorization poll returned malformed JSON.');
    }
    const done = await onToken(data);
    if (done) return;
    if (data.error === 'authorization_pending') continue;
    if (data.error === 'slow_down') {
      currentInterval = Math.min(currentInterval + 5000, 30000);
      continue;
    }
    if (data.error) throw new Error(`Authentication failed: ${data.error_description || data.error}`);
  }
  throw new Error(`Authentication timed out after ${Math.ceil(timeoutMs / 60000)} minutes.`);
}

async function cmdLoginClaudeCode() {
  heading('Claude Code Login');

  // Check for Claude CLI credential file first (set by `claude login`)
  const cliCredsPath = path.join(os.homedir(), '.claude', '.credentials.json');
  if (fs.existsSync(cliCredsPath)) {
    try {
      const raw = fs.readFileSync(cliCredsPath, 'utf8');
      const data = JSON.parse(raw);
      const token = data?.claudeAiOauthTokens?.accessToken;
      if (token) {
        upsertEnvValue('CLAUDE_CODE_OAUTH_TOKEN', token);
        logOk('Imported access token from Claude CLI credentials store');
        logInfo('Restarting NeoAgent to apply credentials...');
        cmdRestart();
        return;
      }
    } catch { }
  }

  // Browser-based PKCE OAuth flow.
  // client_id is the metadata URL per claude.ai's dynamic client registration.
  // Redirect URIs registered: http://localhost/callback and http://127.0.0.1/callback (port 80).
  // Per RFC 8252 §7.3, servers SHOULD allow any loopback port — we try high ports first
  // and fall back to 80 if everything else is occupied.
  const http = require('http');
  const { URL: NodeURL } = require('url');

  const clientId = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
  const SCOPES = CLAUDE_CODE_SCOPES;

  // The registered redirect URIs are http://localhost/callback and http://127.0.0.1/callback
  // (port 80). The OAuth server validates the URI exactly, so we must use port 80.
  // Dynamic high port — the server accepts http://localhost:{any-port}/callback per RFC 8252.
  const redirectPort = Math.floor(Math.random() * 10000) + 49152;
  const redirectUri = `http://localhost:${redirectPort}/callback`;

  // Generate PKCE verifier and challenge
  const codeVerifier = crypto.randomBytes(48).toString('base64url');
  const codeChallenge = crypto
    .createHash('sha256')
    .update(codeVerifier)
    .digest('base64url');

  const state = crypto.randomBytes(16).toString('hex');

  const authUrl = new URL('https://platform.claude.com/oauth/authorize');
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('client_id', clientId);
  authUrl.searchParams.set('redirect_uri', redirectUri);
  authUrl.searchParams.set('scope', SCOPES);
  authUrl.searchParams.set('code_challenge', codeChallenge);
  authUrl.searchParams.set('code_challenge_method', 'S256');
  authUrl.searchParams.set('state', state);

  console.log(`\n  ${COLORS.cyan}Opening browser for Claude Code authorization...${COLORS.reset}`);
  console.log(`  ${COLORS.dim}If the browser doesn't open, visit:${COLORS.reset}`);
  console.log(`  ${authUrl.toString()}\n`);

  // Open browser
  const openCmd = process.platform === 'darwin' ? 'open'
    : process.platform === 'win32' ? 'start'
    : 'xdg-open';
  // Start local redirect server to capture authorization code
  const authCode = await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      server.close();
      reject(new Error('Claude Code authorization timed out after 5 minutes.'));
    }, 5 * 60 * 1000);

    const server = http.createServer((req, res) => {
      try {
        const reqUrl = new NodeURL(req.url, redirectUri);
        const code = reqUrl.searchParams.get('code');
        const returnedState = reqUrl.searchParams.get('state');
        const error = reqUrl.searchParams.get('error');

        if (error) {
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end('<html><body><h2>Authorization failed.</h2><p>You can close this tab.</p></body></html>');
          clearTimeout(timeout);
          server.close();
          reject(new Error(`OAuth error: ${error}`));
          return;
        }

        if (returnedState !== state) {
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end('<html><body><h2>Authorization failed.</h2><p>State mismatch. You can close this tab.</p></body></html>');
          clearTimeout(timeout);
          server.close();
          reject(new Error('OAuth state mismatch — possible CSRF attempt.'));
          return;
        }

        if (code) {
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end('<html><body><h2>Authorization successful!</h2><p>You can close this tab and return to the terminal.</p></body></html>');
          clearTimeout(timeout);
          server.close();
          resolve(code);
          return;
        }
        res.writeHead(400, { 'Content-Type': 'text/html' });
        res.end('<html><body><h2>Authorization failed.</h2><p>Missing authorization code.</p></body></html>');
      } catch (err) {
        res.writeHead(500);
        res.end('Internal error');
      }
    });

    server.listen(redirectPort, 'localhost', () => {
      logInfo(`Waiting for OAuth callback on ${redirectUri} ...`);
      spawnSync(openCmd, [authUrl.toString()], { stdio: 'ignore' });
    });
    server.on('error', (err) => {
      clearTimeout(timeout);
      reject(new Error(`Could not start OAuth callback server: ${err.message}`));
    });
  });

  logInfo('Exchanging authorization code for access token...');
  const tokenData = await fetchAuthJson('https://platform.claude.com/v1/oauth/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      grant_type: 'authorization_code',
      code: authCode,
      redirect_uri: redirectUri,
      client_id: clientId,
      code_verifier: codeVerifier,
      scope: SCOPES,
      state,
    }),
  }, 'Claude Code token exchange');
  const accessToken = tokenData.access_token;
  if (!accessToken) {
    throw new Error('Token exchange succeeded but no access_token was returned.');
  }

  upsertEnvValue('CLAUDE_CODE_OAUTH_TOKEN', accessToken);
  if (tokenData.refresh_token) {
    upsertEnvValue('CLAUDE_CODE_REFRESH_TOKEN', tokenData.refresh_token);
  }
  logOk('Saved Claude Code OAuth token to .env');
  logInfo('Restarting NeoAgent to apply credentials...');
  cmdRestart();
}

async function cmdLoginGrokOAuth() {
  heading('Grok (xAI OAuth) Login');

  const http = require('http');
  const { URL: NodeURL } = require('url');

  const clientId = GROK_OAUTH_CLIENT_ID;
  const SCOPES = GROK_OAUTH_SCOPES;
  const redirectPort = 56121;
  const redirectUri = `http://127.0.0.1:${redirectPort}/callback`;

  const codeVerifier = crypto.randomBytes(48).toString('base64url');
  const codeChallenge = crypto
    .createHash('sha256')
    .update(codeVerifier)
    .digest('base64url');
  const state = crypto.randomBytes(16).toString('hex');

  const authUrl = new URL('https://auth.x.ai/oauth2/authorize');
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('client_id', clientId);
  authUrl.searchParams.set('redirect_uri', redirectUri);
  authUrl.searchParams.set('scope', SCOPES);
  authUrl.searchParams.set('code_challenge', codeChallenge);
  authUrl.searchParams.set('code_challenge_method', 'S256');
  authUrl.searchParams.set('state', state);

  console.log(`\n  ${COLORS.cyan}Opening browser for Grok (xAI) authorization...${COLORS.reset}`);
  console.log(`  ${COLORS.dim}If the browser doesn't open, visit:${COLORS.reset}`);
  console.log(`  ${authUrl.toString()}\n`);

  const openCmd = process.platform === 'darwin' ? 'open'
    : process.platform === 'win32' ? 'start'
    : 'xdg-open';
  const authCode = await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      server.close();
      reject(new Error('Grok OAuth authorization timed out after 5 minutes.'));
    }, 5 * 60 * 1000);

    const server = http.createServer((req, res) => {
      try {
        const reqUrl = new NodeURL(req.url, redirectUri);
        const code = reqUrl.searchParams.get('code');
        const returnedState = reqUrl.searchParams.get('state');
        const error = reqUrl.searchParams.get('error');

        if (error) {
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end('<html><body><h2>Authorization failed.</h2><p>You can close this tab.</p></body></html>');
          clearTimeout(timeout);
          server.close();
          reject(new Error(`OAuth error: ${error}`));
          return;
        }

        if (returnedState !== state) {
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end('<html><body><h2>Authorization failed.</h2><p>State mismatch. You can close this tab.</p></body></html>');
          clearTimeout(timeout);
          server.close();
          reject(new Error('OAuth state mismatch — possible CSRF attempt.'));
          return;
        }

        if (code) {
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end('<html><body><h2>Authorization successful!</h2><p>You can close this tab and return to the terminal.</p></body></html>');
          clearTimeout(timeout);
          server.close();
          resolve(code);
          return;
        }
        res.writeHead(400, { 'Content-Type': 'text/html' });
        res.end('<html><body><h2>Authorization failed.</h2><p>Missing authorization code.</p></body></html>');
      } catch (err) {
        res.writeHead(500);
        res.end('Internal error');
      }
    });

    server.listen(redirectPort, '127.0.0.1', () => {
      logInfo(`Waiting for OAuth callback on ${redirectUri} ...`);
      spawnSync(openCmd, [authUrl.toString()], { stdio: 'ignore' });
    });
    server.on('error', (err) => {
      clearTimeout(timeout);
      reject(new Error(`Could not start OAuth callback server on port ${redirectPort}: ${err.message}`));
    });
  });

  logInfo('Exchanging authorization code for access token...');
  const tokenData = await fetchAuthJson('https://auth.x.ai/oauth2/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code: authCode,
      redirect_uri: redirectUri,
      client_id: clientId,
      code_verifier: codeVerifier,
    }),
  }, 'Grok OAuth token exchange');
  const accessToken = tokenData.access_token;
  if (!accessToken) {
    throw new Error('Token exchange succeeded but no access_token was returned.');
  }

  upsertEnvValue('GROK_OAUTH_ACCESS_TOKEN', accessToken);
  if (tokenData.refresh_token) {
    upsertEnvValue('GROK_OAUTH_REFRESH_TOKEN', tokenData.refresh_token);
  }
  const expiresAt = getGrokOAuthTokenExpiresAt(accessToken, tokenData);
  if (expiresAt) {
    upsertEnvValue('GROK_OAUTH_EXPIRES_AT', String(Math.trunc(expiresAt)));
  } else {
    removeEnvValue('GROK_OAUTH_EXPIRES_AT');
  }
  logOk('Saved Grok OAuth tokens to .env');
  logInfo('Restarting NeoAgent to apply credentials...');
  cmdRestart();
}

async function cmdLogin(args = []) {
  const provider = args[0];
  if (provider !== 'github-copilot' && provider !== 'openai-codex' && provider !== 'claude-code' && provider !== 'grok-oauth') {
    throw new Error(`Unsupported login provider: ${provider || 'none'}. Available: github-copilot, openai-codex, claude-code, grok-oauth`);
  }

  if (provider === 'github-copilot') {
    heading('GitHub Copilot Login');
    const clientId = '01ab8ac9400c4e429b23';
    logInfo('Requesting device code from GitHub...');

    const deviceData = await fetchAuthJson('https://github.com/login/device/code', {
      method: 'POST',
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: clientId, scope: 'user:email' })
    }, 'GitHub device-code request');

    const { device_code, user_code, verification_uri, interval } = deviceData;
    if (!device_code || !user_code || !verification_uri) {
      throw new Error('GitHub device-code response was missing required fields.');
    }
    console.log(`\n  ${COLORS.cyan}Please visit:${COLORS.reset} ${verification_uri}`);
    console.log(`  ${COLORS.cyan}Enter code:${COLORS.reset}   ${COLORS.bold}${user_code}${COLORS.reset}\n`);
    logInfo('Waiting for authorization (timeout in 15m)...');

    await pollDeviceCode({
      pollUrl: 'https://github.com/login/oauth/access_token',
      pollBody: () => ({ client_id: clientId, device_code, grant_type: 'urn:ietf:params:oauth:grant-type:device_code' }),
      intervalMs: (interval || 5) * 1000,
      timeoutMs: 15 * 60 * 1000,
      onToken: async (data) => {
        if (!data.access_token) return false;
        upsertEnvValue('GITHUB_COPILOT_ACCESS_TOKEN', data.access_token);
        logOk('Saved GitHub Copilot access token to .env');
        logInfo('Restarting NeoAgent to apply credentials...');
        cmdRestart();
        return true;
      },
    });
    return;
  } else if (provider === 'openai-codex') {
    heading('OpenAI Codex Login');
    const clientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
    logInfo('Requesting device code from OpenAI...');

    const data = await fetchAuthJson('https://auth.openai.com/api/accounts/deviceauth/usercode', {
      method: 'POST',
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: clientId, scope: 'openid profile email offline_access model.request model.read model.create' })
    }, 'OpenAI device-code request');
    const { device_auth_id, interval } = data;
    const user_code = data.user_code || data.usercode;
    const verification_uri = 'https://auth.openai.com/codex/device';
    if (!device_auth_id || !user_code) {
      throw new Error('OpenAI device-code response was missing required fields.');
    }

    console.log(`\n  ${COLORS.cyan}Please visit:${COLORS.reset} ${verification_uri}`);
    console.log(`  ${COLORS.cyan}Enter code:${COLORS.reset}   ${COLORS.bold}${user_code}${COLORS.reset}\n`);
    logInfo('Waiting for authorization (timeout in 15m)...');

    let authorizationCode = null;
    let codeVerifier = null;

    await pollDeviceCode({
      pollUrl: 'https://auth.openai.com/api/accounts/deviceauth/token',
      pollBody: () => ({ device_auth_id, user_code }),
      intervalMs: (interval || 5) * 1000,
      timeoutMs: 15 * 60 * 1000,
      onToken: async (data) => {
        if (!data.authorization_code || !data.code_verifier) return false;
        authorizationCode = data.authorization_code;
        codeVerifier = data.code_verifier;
        return true;
      },
    });

    logInfo('Exchanging authorization code for access token...');
    const exchangeData = await fetchAuthJson('https://auth.openai.com/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code: authorizationCode,
        redirect_uri: 'https://auth.openai.com/deviceauth/callback',
        client_id: clientId,
        code_verifier: codeVerifier,
      }),
    }, 'OpenAI token exchange');
    if (!exchangeData.access_token) {
      throw new Error('OpenAI token exchange succeeded but did not return an access token.');
    }
    upsertEnvValue('OPENAI_CODEX_ACCESS_TOKEN', exchangeData.access_token);
    if (exchangeData.refresh_token) {
      upsertEnvValue('OPENAI_CODEX_REFRESH_TOKEN', exchangeData.refresh_token);
    }
    logOk('Saved OpenAI Codex tokens to .env');
    logInfo('Restarting NeoAgent to apply credentials...');
    cmdRestart();
  } else if (provider === 'claude-code') {
    await cmdLoginClaudeCode();
  } else if (provider === 'grok-oauth') {
    await cmdLoginGrokOAuth();
  }
}

function installDependencies() {
  heading('Dependencies');
  runOrThrow('npm', ['install', '--omit=dev', '--no-audit', '--no-fund'], {
    env: withInstallEnv()
  });
  logOk('Dependencies installed');
}

function assertSupportedNodeRuntime() {
  const major = Number(String(process.versions.node || '').split('.')[0]);
  if (!Number.isInteger(major) || major < 20) {
    throw new Error(`NeoAgent requires Node.js 20 or newer. Current runtime is ${process.versions.node || 'unknown'}.`);
  }
  logOk(`Node.js ${process.versions.node}`);
}

function installPreflight({ runtimePackage = false } = {}) {
  heading('Installer preflight');
  ensureRuntimeDirs();
  assertSupportedNodeRuntime();

  if (!dependenciesReady() && runtimePackage) {
    const error = new Error('The verified NeoAgent runtime package is incomplete.');
    error.code = 'SETUP_RUNTIME_INCOMPLETE';
    throw error;
  }
  if (!dependenciesReady() && !commandExists('npm')) {
    throw new Error('npm is needed only because this source installation does not contain its runtime dependencies.');
  }
  if (commandExists('npm')) {
    const npmVersion = runQuiet('npm', ['--version']);
    logOk(`npm ${npmVersion.status === 0 ? npmVersion.stdout.trim() : '(version unknown)'}`);
  } else {
    logOk('Self-contained runtime dependencies');
  }

  const platform = detectPlatform();
  if (platform === 'other') {
    rememberInstallAction('Automatic service installation is available on macOS and Linux. This machine will use a detached process fallback.');
  } else {
    logOk(`platform ${platform}`);
  }

  if (platform === 'macos' && !commandExists('launchctl')) {
    rememberInstallAction('launchctl was not found, so the installer will use a detached process fallback instead of a login service.');
  }
  if (platform === 'linux' && !commandExists('systemctl')) {
    rememberInstallAction('systemctl was not found, so the installer will use a detached process fallback instead of a user service.');
  }

  const port = loadEnvPort();
  const portOwner = commandExists('lsof')
    ? runQuiet('lsof', ['-nP', '-iTCP:' + port, '-sTCP:LISTEN'])
    : null;
  if (portOwner && portOwner.status === 0 && portOwner.stdout.trim()) {
    logInfo(`Port ${port} already has a listener; install will keep existing processes unless service start replaces them.`);
  } else {
    logOk(`port ${port} available`);
  }
}

function buildBundledWebClientIfPossible({ required = false, requireFreshBuild = false } = {}) {
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
    requireFreshBuild,
  });
}

function getServiceAdapters() {
  return createServiceAdapters({
    plistDestination: PLIST_DST,
    systemdUnit: SYSTEMD_UNIT,
    commandExists,
    launchctlDomain,
    launchctlServiceTarget,
    logOk,
    logWarn,
    runOrThrow,
    runQuiet,
  });
}
function dependenciesReady() {
  try {
    require.resolve('express', { paths: [APP_DIR] });
    require.resolve('better-sqlite3', { paths: [APP_DIR] });
    return true;
  } catch {
    return false;
  }
}

async function waitForServerReady(port, timeoutMs = 30000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (await isPortOpen(port)) {
      try {
        const { response, data } = await fetchBoundedJsonResponse(
          `http://127.0.0.1:${port}/api/setup/handshake`,
          { timeoutMs: 1500, maxResponseBytes: 64 * 1024 },
          'NeoAgent readiness handshake',
        );
        if (
          response.ok
          && data?.product === 'NeoAgent'
          && Number(data?.protocolVersion) === 1
        ) {
          const expectedInstanceId = require(
            '../server/services/setup/onboarding'
          ).ensureInstance().instance_id;
          if (data.instanceId === expectedInstanceId) return true;
        }
      } catch {
        // The service may still be migrating or starting.
      }
    }
    await abortableDelay(400);
  }
  const error = new Error(`NeoAgent did not become reachable on port ${port}.`);
  error.code = 'SETUP_SERVER_NOT_READY';
  throw error;
}

async function ensureComputerRuntime({ required = false, downloadImage = true } = {}) {
  heading('Ensure Computer Runtime');
  cleanupLegacyDockerRuntime();
  try {
    const { QemuVMManager } = require('../server/services/runtime/qemu_vm_manager');
    const vmManager = new QemuVMManager();
    const readiness = await vmManager.prepareRuntime({ downloadImage });
    const profilePath = path.join(RUNTIME_HOME, 'computer-runtime', 'profile.json');
    fs.mkdirSync(path.dirname(profilePath), { recursive: true, mode: 0o700 });
    fs.writeFileSync(profilePath, `${JSON.stringify(readiness.resources, null, 2)}\n`, {
      mode: 0o600,
    });
    logOk(`QEMU computer runtime is ready (${readiness.accelerator || 'TCG'})`);
    if (readiness.compatibilityMode) {
      logWarn('Hardware acceleration is unavailable; compatibility mode limits concurrency to one computer.');
    }
    if (readiness.imageReady) logOk('Pinned Debian guest image is verified and ready');
    return true;
  } catch (err) {
    const message = `Computer runtime preparation did not complete: ${err.message}`;
    if (required) throw new Error(message);
    logWarn(message);
    rememberInstallAction('Run `neoagent repair` to restore the signed QEMU runtime and pinned Debian guest image.');
    return false;
  }
}

function cleanupLegacyDockerRuntime() {
  const markerPath = path.join(RUNTIME_HOME, 'computer-runtime', 'legacy-docker-cleanup.json');
  if (fs.existsSync(markerPath)) return;
  fs.mkdirSync(path.dirname(markerPath), { recursive: true, mode: 0o700 });
  if (!commandExists('docker')) {
    fs.writeFileSync(markerPath, `${JSON.stringify({ completedAt: new Date().toISOString(), removed: 0 })}\n`, {
      mode: 0o600,
    });
    return;
  }
  const daemon = runQuiet('docker', ['info', '--format', '{{.ServerVersion}}']);
  if (daemon.status !== 0) {
    logWarn('Docker is installed but unavailable; legacy NeoAgent container cleanup will retry later.');
    return;
  }
  const containers = runQuiet('docker', [
    'container', 'ls', '--all', '--quiet', '--filter', 'label=neoagent.managed=1',
  ]);
  const containerIds = containers.status === 0
    ? containers.stdout.split(/\s+/).filter((value) => /^[a-f0-9]{12,64}$/i.test(value))
    : [];
  if (containerIds.length > 0) {
    const removed = runQuiet('docker', ['container', 'rm', '--force', ...containerIds]);
    if (removed.status !== 0) {
      logWarn('Legacy NeoAgent containers could not be removed; cleanup will retry later.');
      return;
    }
  }
  const images = runQuiet('docker', [
    'image', 'ls', '--quiet', '--filter', 'reference=neoagent-guest-agent:*',
  ]);
  const imageIds = images.status === 0
    ? [...new Set(images.stdout.split(/\s+/).filter((value) => /^(?:sha256:)?[a-f0-9]{12,64}$/i.test(value)))]
    : [];
  if (imageIds.length > 0) {
    const removed = runQuiet('docker', ['image', 'rm', '--force', ...imageIds]);
    if (removed.status !== 0) {
      logWarn('Legacy NeoAgent images could not be removed; cleanup will retry later.');
      return;
    }
  }
  fs.writeFileSync(markerPath, `${JSON.stringify({
    completedAt: new Date().toISOString(),
    removedContainers: containerIds.length,
    removedImages: imageIds.length,
  })}\n`, { mode: 0o600 });
  if (containerIds.length > 0 || imageIds.length > 0) {
    logOk(`Removed ${containerIds.length} legacy NeoAgent container(s) and ${imageIds.length} image(s); Docker itself was not changed.`);
  }
}

function ensureYtDlpInstalled() {
  heading('Ensure yt-dlp Installed');
  if (commandExists('yt-dlp')) {
    const ver = runQuiet('yt-dlp', ['--version']);
    logOk(`yt-dlp ${ver.status === 0 ? ver.stdout.trim() : '(version unknown)'}`);
    return true;
  }

  logInfo('yt-dlp not found. Attempting to install...');
  const platform = detectPlatform();

  if (platform === 'macos') {
    if (!commandExists('brew')) {
      logWarn('Homebrew not found; skipping yt-dlp auto-install.');
      rememberInstallAction('Install yt-dlp with `brew install yt-dlp` if you need video/audio extraction.');
      return false;
    }
    try {
      runOrThrow('brew', ['install', 'yt-dlp']);
      logOk('yt-dlp installed via Homebrew');
      return true;
    } catch {
      logWarn('yt-dlp install failed.');
      rememberInstallAction('Install yt-dlp with `brew install yt-dlp` if you need video/audio extraction.');
      return false;
    }
  }

  if (platform === 'linux') {
    if (commandExists('pipx')) {
      try {
        runOrThrow('pipx', ['install', 'yt-dlp']);
        logOk('yt-dlp installed via pipx');
        return true;
      } catch {
        // fall through to pip3
      }
    }
    if (commandExists('pip3')) {
      try {
        runOrThrow('pip3', ['install', '--user', 'yt-dlp']);
        logOk('yt-dlp installed via pip3');
        return true;
      } catch {
        // fall through to warn
      }
    }
    logWarn('Could not install yt-dlp automatically.');
    rememberInstallAction('Install yt-dlp with `pipx install yt-dlp` or your OS package manager if you need video/audio extraction.');
    return false;
  }
  rememberInstallAction('Install yt-dlp manually if you need video/audio extraction.');
  return false;
}

async function cmdInstall({ args = [], showBanner = true } = {}) {
  const options = parseSetupArguments(args);
  const profile = await resolveSetupProfile(options);
  if (!setupEventWriter) {
    setupEventWriter = new SetupEventWriter({
      profile,
      json: options.json,
    });
  }
  setupEventWriter.profile = profile;
  installActionItems.length = 0;
  if (showBanner) {
    cliBanner(`Install ${APP_NAME}`, 'guided bootstrap');
  }
  heading(`Install ${APP_NAME}`);
  try {
    setupEventWriter.start('prepare', 'Checking this computer', 0.01);
    installPreflight({ runtimePackage: options.runtimePackage });
    const plan = await runSetupProfile(profile, options);

    setupEventWriter.start('dependencies', 'Preparing NeoAgent runtime', 0.2);
    if (dependenciesReady()) {
      logOk('Runtime dependencies are ready');
    } else {
      if (options.runtimePackage) {
        const error = new Error('The verified runtime package is missing required dependencies.');
        error.code = 'SETUP_RUNTIME_INCOMPLETE';
        throw error;
      }
      installDependencies();
    }
    if (options.runtimePackage) {
      if (!hasBundledWebClient(WEB_CLIENT_DIR)) {
        const error = new Error('The verified runtime package does not contain the web client.');
        error.code = 'SETUP_RUNTIME_INCOMPLETE';
        throw error;
      }
      logOk('Bundled web client is ready');
    } else {
      buildBundledWebClientIfPossible({ required: true, requireFreshBuild: true });
    }
    setupEventWriter.complete('dependencies', 'Runtime prepared', 0.45);

    if (profile === 'full' && !options.nonInteractive && !options.json) {
      const prepareIsolation = await ask(
        'Download and verify the Linux cloud computer image now? (Y/n)',
        'Y',
      );
      if (['y', 'yes'].includes(prepareIsolation.trim().toLowerCase())) {
        await ensureComputerRuntime({ required: false, downloadImage: true });
      } else {
        rememberInstallAction('Prepare the cloud computer later with `neoagent repair`.');
      }
      const prepareMedia = await ask('Install optional media extraction support now? (y/N)', 'N');
      if (['y', 'yes'].includes(prepareMedia.trim().toLowerCase())) {
        ensureYtDlpInstalled();
      }
    } else {
      await ensureComputerRuntime({ required: false, downloadImage: false });
      rememberInstallAction('The Debian guest image downloads automatically when the first computer starts.');
    }

    setupEventWriter.start('service', 'Starting NeoAgent in the background', 0.55);
    const platform = detectPlatform();
    getServiceAdapters().install(platform);
    const port = plan.port;
    await waitForServerReady(port);
    setupEventWriter.complete('service', 'NeoAgent is ready', 0.85);

    const backendUrl = `http://localhost:${port}`;
    clearSetupState(SETUP_STATE_FILE);
    setupEventWriter.emit('ready', {
      stage: 'complete',
      progress: 1,
      message: 'NeoAgent setup is complete',
      result: {
        backendUrl,
        instanceId: require('../server/services/setup/onboarding').ensureInstance().instance_id,
        serverVersion: readInstalledPackageVersion(),
      },
    });

    if (!cliJsonOutput) {
      logOk(`Running on ${backendUrl}`);
      printInstallActionItems();
      heading('Ready');
      logInfo(`Open ${backendUrl} to continue.`);
      logInfo('Administrative dashboard credentials are available only with `neoagent admin`.');
    }
  } catch (error) {
    writeSetupState(SETUP_STATE_FILE, {
      profile,
      stage: setupEventWriter.stage,
      status: 'failed',
    });
    setupEventWriter.fail(error, {
      stage: setupEventWriter.stage,
      retryable: true,
      action: 'neoagent setup --resume',
    });
    error.setupEventEmitted = true;
    throw error;
  }
}

async function cmdDefault() {
  cliBanner('Welcome', 'installation scan');
  heading('Scan This Computer');
  logInfo('Checking NeoAgent runtime data, system services, and running processes…');

  const interruptedSetup = readSetupState(SETUP_STATE_FILE);
  if (interruptedSetup && interruptedSetup.status !== 'completed') {
    logInfo(
      `An interrupted ${interruptedSetup.profile} setup was found at ${interruptedSetup.stage}.`,
    );
    await cmdInstall({ args: ['--resume'], showBanner: false });
    return;
  }

  const scan = scanForInstalledInstance();
  if (scan.installed) {
    const locations = scan.evidence
      .map((item) => item.path)
      .filter(Boolean);
    logOk('Existing NeoAgent installation found');
    if (locations.length > 0) {
      logInfo(`Detected ${locations.join(', ')}`);
    }
    const port = loadEnvPort();
    const healthy = fs.existsSync(ENV_FILE)
      && dependenciesReady()
      && hasBundledWebClient(WEB_CLIENT_DIR)
      && await isPortOpen(port);
    if (!healthy) {
      logWarn('The installation needs attention.');
      await cmdDoctor();
      if (!cliJsonOutput) {
        logInfo('Run `neoagent repair` after reviewing the diagnostic checks.');
      }
      return;
    }
    await cmdStatus({ showBanner: false });
    console.log('');
    logInfo('Run `neoagent --help` to see all commands.');
    return;
  }

  logInfo('No installed NeoAgent instance was found. Starting first-time setup.');
  if (fs.existsSync(ENV_FILE)) {
    logInfo(`Existing configuration at ${ENV_FILE} will be preserved.`);
  }
  await cmdInstall({ showBanner: false });
}

function cmdStart() {
  cliBanner(`Start ${APP_NAME}`, 'boot sequence');
  heading(`Start ${APP_NAME}`);
  const platform = detectPlatform();

  if (platform === 'macos' && fs.existsSync(PLIST_DST)) {
    logInfo('Handing launch to launchd');
    getServiceAdapters().installMacService();
    logOk('launchd start requested');
    return;
  }

  if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    logInfo('Handing launch to systemd');
    runOrThrow('systemctl', ['--user', 'start', 'neoagent']);
    runOrThrow('systemctl', ['--user', 'is-active', '--quiet', 'neoagent']);
    logOk('systemd start requested');
    return;
  }

  getServiceAdapters().startFallback();
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
          logWarn(`pid ${pid} was not running (stale PID file)`);
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
}

function cmdRestart() {
  heading(`Restart ${APP_NAME}`);
  buildBundledWebClientIfPossible();
  cmdStop();
  cmdStart();
}

async function cmdRebuildWeb() {
  heading(`Rebuild Flutter Web Client`);
  buildBundledWebClientIfPossible();
}

async function cmdBackup() {
  cliBanner(`Backup ${APP_NAME}`, 'persistent computer snapshot');
  const wasRunning = listNeoAgentServerProcesses().length > 0;
  let target;
  try {
    if (wasRunning) {
      heading('Quiesce');
      cmdStop();
      const deadline = Date.now() + 15_000;
      while (listNeoAgentServerProcesses().length > 0 && Date.now() < deadline) {
        await abortableDelay(250);
      }
      if (listNeoAgentServerProcesses().length > 0) {
        throw new Error('NeoAgent did not stop in time for a consistent computer backup.');
      }
    }
    heading('Backup');
    target = backupRuntimeData({ prefix: 'manual' });
    const result = await backupComputerDisks(target);
    logOk(`Backup verified at ${target} (${result.disks} computer disk(s))`);
  } finally {
    if (wasRunning) cmdStart();
  }
  return target;
}

async function cmdFix(args = []) {
  const runtimePackage = args.includes('--runtime-package');
  cliBanner(`Fix ${APP_NAME}`, 'reset and recover');
  heading('Stop');
  cmdStop();
  const stopDeadline = Date.now() + 15_000;
  while (listNeoAgentServerProcesses().length > 0 && Date.now() < stopDeadline) {
    await abortableDelay(250);
  }
  if (listNeoAgentServerProcesses().length > 0) {
    throw new Error('NeoAgent did not stop in time for a consistent repair backup.');
  }

  heading('Backup');
  backupRuntimeData();
  logOk(`Runtime data backed up to ${path.join(RUNTIME_HOME, 'backups')}`);

  if (fs.existsSync(path.join(APP_DIR, '.git')) && commandExists('git')) {
    heading('Reset source files');
    const dirty = runQuiet('git', ['status', '--porcelain']);
    if (dirty.status === 0 && dirty.stdout.trim()) {
      runOrThrow('git', ['checkout', '--', '.']);
      logOk('Tracked source files reset to HEAD');
    } else {
      logOk('Working tree clean — nothing to reset');
    }
  }

  heading('Dependencies');
  if (runtimePackage) {
    if (!dependenciesReady()) {
      const error = new Error(
        'The verified runtime package is missing required dependencies.',
      );
      error.code = 'SETUP_RUNTIME_INCOMPLETE';
      throw error;
    }
    logOk('Verified runtime dependencies are present');
  } else {
    const nodeModulesDir = path.join(APP_DIR, 'node_modules');
    if (fs.existsSync(nodeModulesDir)) {
      logInfo('Removing node_modules…');
      fs.rmSync(nodeModulesDir, { recursive: true, force: true });
      logOk('node_modules removed');
    }
    installDependencies();
  }

  heading('Web Client');
  if (runtimePackage && !hasBundledWebClient(WEB_CLIENT_DIR)) {
    const error = new Error(
      'The verified runtime package is missing the bundled web client.',
    );
    error.code = 'SETUP_RUNTIME_INCOMPLETE';
    throw error;
  }
  if (!runtimePackage) buildBundledWebClientIfPossible({ required: true });

  await ensureComputerRuntime({ required: runtimePackage, downloadImage: true });
  const diskRepair = repairComputerDisks();
  if (diskRepair.checked > 0) {
    logOk(`Verified ${diskRepair.checked} computer disk(s); repaired ${diskRepair.repaired}.`);
  }

  heading('Start');
  const platform = detectPlatform();
  getServiceAdapters().install(platform);

  const port = loadEnvPort();
  logOk(`Running on http://localhost:${port}`);
  heading('Ready');
  logInfo('Fix complete. Run `neoagent status` to verify.');
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

async function cmdStatus({ showBanner = true } = {}) {
  if (showBanner) {
    cliBanner(`${APP_NAME} Status`, 'systems sweep');
  }
  heading(`${APP_NAME} Status`);
  const port = loadEnvPort();
  const running = await isPortOpen(port);
  const releaseChannel = currentReleaseChannel();
  const platform = detectPlatform();

  cliSection('Runtime');
  statusLine(
    running,
    'server',
    running ? `http://localhost:${port}` : `not reachable on port ${port}`,
  );

  if (platform === 'macos' && fs.existsSync(PLIST_DST)) {
    const svcRes = runQuiet('launchctl', ['list', SERVICE_LABEL]);
    statusLine(
      svcRes.status === 0 && Boolean(svcRes.stdout.trim()),
      'service',
      svcRes.status === 0 && svcRes.stdout.trim()
        ? `launchd (${SERVICE_LABEL})`
        : 'launchd unit not loaded',
      svcRes.status === 0 && svcRes.stdout.trim() ? '' : 'run: neoagent install',
    );
  } else if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    const svcRes = runQuiet('systemctl', ['--user', 'is-active', 'neoagent']);
    statusLine(
      svcRes.status === 0 && svcRes.stdout.trim() === 'active',
      'service',
      svcRes.status === 0 && svcRes.stdout.trim() === 'active'
        ? 'systemd (neoagent)'
        : 'systemd unit not active',
      svcRes.status === 0 && svcRes.stdout.trim() === 'active' ? '' : 'run: neoagent install',
    );
  }

  cliSection('Assets');
  statusLine(
    fs.existsSync(ENV_FILE),
    'config',
    fs.existsSync(ENV_FILE) ? ENV_FILE : '.env not found',
    fs.existsSync(ENV_FILE) ? '' : 'run: neoagent setup',
  );

  statusLine(
    hasBundledWebClient(WEB_CLIENT_DIR),
    'web',
    hasBundledWebClient(WEB_CLIENT_DIR)
      ? 'bundled Flutter client present'
      : 'no bundled client',
    hasBundledWebClient(WEB_CLIENT_DIR) ? '' : 'run: neoagent rebuild-web',
  );

  try {
    const { QemuVMManager } = require('../server/services/runtime/qemu_vm_manager');
    const computer = new QemuVMManager().getReadiness();
    statusLine(
      computer.ready,
      'computer',
      computer.ready
        ? `${computer.accelerator || 'QEMU'} · ${computer.imageReady ? 'guest image ready' : 'guest image downloads on first start'}`
        : 'QEMU runtime missing',
      computer.ready ? '' : 'run: neoagent repair',
    );
  } catch (error) {
    statusLine(false, 'computer', error.message, 'run: neoagent repair');
  }

  if (!cliJsonOutput) console.log('');
  cliSection('Build');
  if (!cliJsonOutput) {
    console.log(`  install   ${APP_DIR}`);
    console.log(`  version   ${currentInstalledVersionLabel()}`);
    console.log(`  channel   ${releaseChannelSummary(releaseChannel)}`);
  }

  const processes = listNeoAgentServerProcesses();
  if (processes.length > 0) {
    if (!cliJsonOutput) {
      console.log(`  pids      ${processes.map((proc) => proc.pid).join(', ')}`);
    }
    if (processes.length > 1) {
      logWarn(`multiple NeoAgent processes detected (${processes.length})`);
    }
  }
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.emit('ready', {
      stage: 'status',
      progress: 1,
      message: running ? 'NeoAgent is reachable' : 'NeoAgent is not reachable',
      result: {
        running,
        backendUrl: `http://localhost:${port}`,
        configPresent: fs.existsSync(ENV_FILE),
        webClientPresent: hasBundledWebClient(WEB_CLIENT_DIR),
        version: currentInstalledVersionLabel(),
        releaseChannel,
        processCount: processes.length,
      },
    });
  }
}

async function cmdDoctor() {
  cliBanner(`${APP_NAME} Doctor`, 'read-only diagnostics');
  heading(`${APP_NAME} Doctor`);
  const port = loadEnvPort();
  const setupState = readSetupState(SETUP_STATE_FILE);
  let computerReadiness = null;
  try {
    const { QemuVMManager } = require('../server/services/runtime/qemu_vm_manager');
    computerReadiness = new QemuVMManager().getReadiness();
  } catch {}
  let runtimeWritable = true;
  try {
    fs.accessSync(RUNTIME_HOME, fs.constants.R_OK | fs.constants.W_OK);
  } catch {
    runtimeWritable = false;
  }
  const checks = [
    {
      id: 'runtime-access',
      ok: runtimeWritable,
      code: runtimeWritable ? null : 'DOCTOR_RUNTIME_NOT_WRITABLE',
      message: runtimeWritable
        ? 'Runtime data directory is accessible'
        : 'Runtime data directory is not writable',
      action: 'Check the current user permissions for the NeoAgent data directory.',
    },
    {
      id: 'configuration',
      ok: fs.existsSync(ENV_FILE),
      code: fs.existsSync(ENV_FILE) ? null : 'DOCTOR_CONFIG_MISSING',
      message: fs.existsSync(ENV_FILE)
        ? 'Configuration is present'
        : 'Configuration is missing',
      action: 'Run `neoagent setup --quick`.',
    },
    {
      id: 'dependencies',
      ok: dependenciesReady(),
      code: dependenciesReady() ? null : 'DOCTOR_RUNTIME_INCOMPLETE',
      message: dependenciesReady()
        ? 'Runtime dependencies are present'
        : 'Runtime dependencies are incomplete',
      action: 'Run `neoagent repair`.',
    },
    {
      id: 'web-client',
      ok: hasBundledWebClient(WEB_CLIENT_DIR),
      code: hasBundledWebClient(WEB_CLIENT_DIR)
        ? null
        : 'DOCTOR_WEB_CLIENT_MISSING',
      message: hasBundledWebClient(WEB_CLIENT_DIR)
        ? 'Bundled client is present'
        : 'Bundled client is missing',
      action: 'Run `neoagent repair`.',
    },
    {
      id: 'computer-runtime',
      ok: computerReadiness?.ready === true,
      code: computerReadiness?.ready === true
        ? null
        : 'DOCTOR_COMPUTER_RUNTIME_MISSING',
      message: computerReadiness?.ready === true
        ? `QEMU computer runtime is present (${computerReadiness.accelerator || 'TCG'})`
        : 'QEMU computer runtime is missing or incomplete',
      action: 'Run `neoagent repair` to restore the signed computer runtime.',
    },
    {
      id: 'computer-image',
      ok: computerReadiness?.ready === true,
      code: computerReadiness?.ready === true ? null : 'DOCTOR_COMPUTER_IMAGE_UNAVAILABLE',
      message: computerReadiness?.imageReady === true
        ? 'Pinned Debian guest image is present'
        : 'Pinned Debian guest image will be verified on first start',
      action: 'Run `neoagent repair` to download and verify the guest image now.',
    },
    {
      id: 'server',
      ok: await isPortOpen(port),
      code: null,
      message: '',
      action: 'Run `neoagent start` or `neoagent repair`.',
    },
    {
      id: 'setup-state',
      ok: !setupState || setupState.status === 'completed',
      code: setupState && setupState.status !== 'completed'
        ? 'DOCTOR_SETUP_INCOMPLETE'
        : null,
      message: setupState && setupState.status !== 'completed'
        ? `Setup can be resumed from ${setupState.stage}`
        : 'No interrupted setup is pending',
      action: 'Run `neoagent setup --resume`.',
    },
  ];
  const serverCheck = checks.find((check) => check.id === 'server');
  serverCheck.message = serverCheck.ok
    ? `NeoAgent is reachable on port ${port}`
    : `NeoAgent is not reachable on port ${port}`;
  serverCheck.code = serverCheck.ok ? null : 'DOCTOR_SERVER_UNREACHABLE';

  if (cliJsonOutput && setupEventWriter) {
    const healthy = checks.every((check) => check.ok);
    setupEventWriter.emit('ready', {
      stage: 'doctor',
      progress: 1,
      message: healthy
        ? 'No NeoAgent problems were found'
        : 'NeoAgent needs attention',
      result: {
        healthy,
        port,
        checks,
      },
    });
    return;
  }

  for (const check of checks) {
    statusLine(
      check.ok,
      check.id,
      check.message,
      check.ok ? '' : check.action,
    );
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

function cmdChannel(args = []) {
  heading('Release Channel');
  const requested = args[0];

  if (!requested) {
    const channel = currentReleaseChannel();
    console.log(`  configured ${releaseChannelSummary(channel)}`);
    return;
  }

  const nextChannel = parseReleaseChannel(requested);
  if (!nextChannel) {
    throw new Error('Usage: neoagent channel [stable|beta]');
  }

  writeReleaseChannelToEnvFile(nextChannel, ENV_FILE);
  process.env.NEOAGENT_RELEASE_CHANNEL = nextChannel;
  logOk(`Release channel set to ${releaseChannelSummary(nextChannel)}`);
}

async function cmdUpdate(args = []) {
  heading(`Update ${APP_NAME}`);
  migrateLegacyRuntime((msg) => logInfo(msg));
  ensureRuntimeDirs();
  const requestedChannel = args[0] ? parseReleaseChannel(args[0]) : null;
  if (args[0] && !requestedChannel) {
    throw new Error('Usage: neoagent update [stable|beta]');
  }
  const releaseChannel = requestedChannel || currentReleaseChannel();
  if (requestedChannel) {
    writeReleaseChannelToEnvFile(releaseChannel, ENV_FILE);
    process.env.NEOAGENT_RELEASE_CHANNEL = releaseChannel;
    logOk(`Release channel set to ${releaseChannelSummary(releaseChannel)}`);
  }
  const versionBefore = currentInstalledVersionLabel();
  let versionAfter = versionBefore;
  const githubInstallRef = releaseChannel === 'beta' ? '#beta' : '';
  const githubInstallSpec = `git+https://github.com/NeoLabs-Systems/NeoAgent.git${githubInstallRef}`;

  if (fs.existsSync(path.join(APP_DIR, '.git')) && commandExists('git')) {
    const current = runQuiet('git', ['rev-parse', '--short', 'HEAD']);

    runOrThrow('git', ['fetch', 'origin', '--tags']);
    const targetBranch = resolvePreferredGitBranch(releaseChannel);
    logInfo(`Using git branch ${targetBranch} for the ${releaseChannel} channel.`);
    ensureGitBranchForReleaseChannel(targetBranch);
    backupRuntimeData();
    runOrThrow('git', ['pull', '--rebase', '--autostash', 'origin', targetBranch]);

    const next = runQuiet('git', ['rev-parse', '--short', 'HEAD']);
    if (current.status === 0 && next.status === 0 && current.stdout.trim() !== next.stdout.trim()) {
      logOk(`Updated ${current.stdout.trim()} -> ${next.stdout.trim()}`);
      installDependencies();
      buildBundledWebClientIfPossible({ requireFreshBuild: true });
    } else {
      logOk('Already up to date');
      buildBundledWebClientIfPossible({ requireFreshBuild: true });
    }
  } else {
    logWarn(`No git repo detected; attempting npm global update from ${githubInstallSpec}.`);
    if (commandExists('npm')) {
      try {
        backupRuntimeData();
        runOrThrow('npm', ['install', '-g', githubInstallSpec, '--force'], {
          env: withInstallEnv()
        });
        logOk('npm global update completed (forced reinstall from GitHub)');
      } catch {
        logWarn(`npm global update failed. Run: npm install -g ${githubInstallSpec} --force`);
      }
    } else {
      logWarn('npm not found. Cannot perform global update.');
    }
  }

  versionAfter = currentInstalledVersionLabel();
  ensureYtDlpInstalled();
  await ensureComputerRuntime({ required: false, downloadImage: false });

  if (!hasBundledWebClient(WEB_CLIENT_DIR)) {
    throw new Error('No bundled Flutter web client found after update.');
  }

  cmdRestart();
  logOk(`Installed version ${versionBefore} -> ${versionAfter}`);
}

async function cmdEnv(args = []) {
  heading('Environment Variables');
  const action = (args[0] || '').trim().toLowerCase();

  if (!action) {
    console.log('Usage: neoagent env <subcommand>');
    console.log('');
    console.log('  neoagent env list            List all variables (secrets masked)');
    console.log('  neoagent env get KEY         Print a single variable');
    console.log('  neoagent env set KEY VALUE   Set a variable');
    console.log('  neoagent env unset KEY       Remove a variable');
    return;
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
    const key = args[1];
    const value = args.slice(2).join(' ');
    if (!key || !value) throw new Error('Usage: neoagent env set <KEY> <VALUE>');
    validateEnvKey(key);
    upsertEnvValue(key, value);
    logOk(`Set ${key} in ${ENV_FILE}`);
    return;
  }

  if (action === 'unset') {
    const key = args[1];
    if (!key) throw new Error('Usage: neoagent env unset <KEY>');
    removeEnvValue(key);
    logOk(`Removed ${key} from ${ENV_FILE}`);
    return;
  }

  throw new Error('Usage: neoagent env [list|get|set|unset] ...');
}

function cmdVersion() {
  console.log(currentInstalledVersionLabel());
}

async function cmdBilling(args = []) {
  const sub = (args[0] || 'status').toLowerCase();

  if (sub === '--help' || sub === '-h' || sub === 'help') {
    console.log('\nNeoAgent Billing');
    console.log('Usage: neoagent billing [subcommand]');
    console.log('');
    console.log('Subcommands:');
    console.log('  neoagent billing           Show billing configuration status');
    console.log('  neoagent billing setup     Interactive Stripe setup wizard');
    console.log('  neoagent billing enable    Enable billing and restart');
    console.log('  neoagent billing disable   Disable billing and restart');
    console.log('');
    return;
  }

  if (sub === 'status') {
    cliBanner('Billing', 'configuration status');
    heading('Billing Status');
    const env = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());
    const enabled = ['1', 'true', 'yes'].includes(String(env.NEOAGENT_BILLING_ENABLED || '').toLowerCase());
    const hasSecret = Boolean(env.STRIPE_SECRET_KEY);
    const hasPub = Boolean(env.STRIPE_PUBLISHABLE_KEY);
    const hasWebhook = Boolean(env.STRIPE_WEBHOOK_SECRET);
    const trialDays = env.BILLING_TRIAL_DAYS || '14';

    cliSection('Billing config');
    statusLine(enabled, 'enabled', enabled ? 'yes' : 'no', enabled ? '' : 'run: neoagent billing enable');
    statusLine(hasSecret, 'secret', hasSecret ? maskEnvValue('SECRET', env.STRIPE_SECRET_KEY) : 'not set', hasSecret ? '' : 'run: neoagent billing setup');
    statusLine(hasPub, 'public', hasPub ? maskEnvValue('KEY', env.STRIPE_PUBLISHABLE_KEY) : 'not set');
    statusLine(hasWebhook, 'webhook', hasWebhook ? 'configured' : 'not set');
    console.log('');
    cliSection('Trial');
    console.log(`  trial days  ${trialDays}`);

    const port = loadEnvPort();
    const publicUrl = env.PUBLIC_URL || `http://localhost:${port}`;
    console.log('');
    cliSection('Webhook endpoint');
    console.log(`  ${publicUrl}/api/billing/webhook`);
    console.log('');

    if (!hasSecret || !hasPub) {
      logWarn('Stripe keys not configured. Run `neoagent billing setup` to get started.');
    } else if (!enabled) {
      logInfo('Billing is configured but not enabled. Run `neoagent billing enable` to activate.');
    } else {
      logOk('Billing is active. Manage plans in Admin › Billing.');
    }
    return;
  }

  if (sub === 'enable') {
    heading('Enable Billing');
    upsertEnvValue('NEOAGENT_BILLING_ENABLED', 'true');
    logOk('Set NEOAGENT_BILLING_ENABLED=true');
    logInfo('Restarting NeoAgent to apply changes...');
    cmdRestart();
    return;
  }

  if (sub === 'disable') {
    heading('Disable Billing');
    upsertEnvValue('NEOAGENT_BILLING_ENABLED', 'false');
    logOk('Set NEOAGENT_BILLING_ENABLED=false');
    logInfo('Restarting NeoAgent to apply changes...');
    cmdRestart();
    return;
  }

  if (sub === 'setup') {
    cliBanner('Billing Setup', 'Stripe configuration');
    heading('Billing Setup');
    ensureRuntimeDirs();

    const current = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());
    const port = loadEnvPort();
    const publicUrl = current.PUBLIC_URL || `http://localhost:${port}`;

    logInfo('Press Enter to keep the current value shown in brackets.');
    logInfo(`Webhook endpoint: ${publicUrl}/api/billing/webhook`);
    console.log('');

    heading('Stripe API keys');
    logInfo('Find these in your Stripe dashboard: https://dashboard.stripe.com/apikeys');
    const secretKey = await askSecret('Stripe secret key (sk_live_... or sk_test_...)', current.STRIPE_SECRET_KEY || '');
    const publishableKey = await askSecret('Stripe publishable key (pk_live_... or pk_test_...)', current.STRIPE_PUBLISHABLE_KEY || '');

    if (secretKey && !secretKey.startsWith('sk_')) {
      logWarn('Secret key does not start with "sk_" — double-check the value.');
    }
    if (publishableKey && !publishableKey.startsWith('pk_')) {
      logWarn('Publishable key does not start with "pk_" — double-check the value.');
    }

    heading('Webhook');
    logInfo(`Register this endpoint in Stripe: ${publicUrl}/api/billing/webhook`);
    logInfo('Required events: customer.subscription.*, invoice.payment_succeeded, invoice.payment_failed');
    const webhookSecret = await askSecret('Stripe webhook signing secret (whsec_...)', current.STRIPE_WEBHOOK_SECRET || '');

    if (webhookSecret && !webhookSecret.startsWith('whsec_')) {
      logWarn('Webhook secret does not start with "whsec_" — double-check the value.');
    }

    heading('Trial');
    const trialDaysRaw = await ask('Free trial length in days (0 to disable)', current.BILLING_TRIAL_DAYS || '14');
    const trialDays = Number(trialDaysRaw);
    if (!Number.isInteger(trialDays) || trialDays < 0) {
      throw new Error(`Invalid trial length "${trialDaysRaw}". Must be a non-negative integer.`);
    }

    if (secretKey) upsertEnvValue('STRIPE_SECRET_KEY', secretKey);
    if (publishableKey) upsertEnvValue('STRIPE_PUBLISHABLE_KEY', publishableKey);
    if (webhookSecret) upsertEnvValue('STRIPE_WEBHOOK_SECRET', webhookSecret);
    upsertEnvValue('BILLING_TRIAL_DAYS', String(trialDays));

    logOk('Stripe credentials saved to .env');

    const isAlreadyEnabled = ['1', 'true', 'yes'].includes(String(current.NEOAGENT_BILLING_ENABLED || '').toLowerCase());
    let enableNow = isAlreadyEnabled;
    if (!isAlreadyEnabled) {
      const enableAnswer = await ask('Enable billing now? (y/N)', 'N');
      enableNow = enableAnswer.toLowerCase() === 'y' || enableAnswer.toLowerCase() === 'yes';
    }

    if (enableNow) {
      upsertEnvValue('NEOAGENT_BILLING_ENABLED', 'true');
      logOk('Billing enabled');
      logInfo('Restarting NeoAgent to apply credentials...');
      cmdRestart();
    } else {
      logInfo('Billing is not yet enabled. Run `neoagent billing enable` when ready.');
    }

    console.log('');
    heading('Next steps');
    logInfo('1. Verify the webhook endpoint is reachable from Stripe');
    logInfo('2. Create subscription plans in Admin › Billing › Plans');
    logInfo('3. Add a free plan (price = 0) for users without a paid subscription');
    logInfo('   See: neoagent billing status');
    return;
  }

  throw new Error(`Unknown billing subcommand: ${sub}. Run "neoagent billing --help" for usage.`);
}

function printHelp() {
  const c = COLORS;
  const W = 38;

  function row(cmd, desc) {
    const padded = `  neoagent ${cmd}`.padEnd(W);
    const arrow = CLI_INTERACTIVE ? `${c.cyan}›${c.reset} ` : '';
    console.log(`${padded}${arrow}${c.dim}${desc}${c.reset}`);
  }

  cliBanner('neoagent', 'command deck');
  console.log(`\n${c.bold}Usage${c.reset}  neoagent [command] [args]\n`);
  console.log(`${c.dim}  Run neoagent without a command to detect or install NeoAgent.${c.reset}\n`);

  cliSection('Lifecycle');
  row('install',              'Guided bootstrap, dependencies, config, service');
  row('start',               'Start the server');
  row('stop',                'Stop the server');
  row('restart',             'Stop, then start');
  row('status',              'Health overview (server, service, config)');
  row('doctor',              'Read-only setup and runtime diagnostics');
  row('logs',                'Tail server logs');
  row('backup',              'Snapshot config, data, and persistent computer disks');
  row('repair',              'Backup, repair dependencies, and restart');
  row('fix',                 'Alias for repair');
  row('uninstall',           'Remove the system service');
  console.log('');

  cliSection('Configuration');
  row('setup',               'Choose Quickstart or full configuration');
  row('setup --quick',       'Apply safe core defaults');
  row('setup --full',        'Configure every setup section');
  row('setup --resume',      'Resume an interrupted setup');
  row('env list',            'List all variables (secrets masked)');
  row('env get KEY',         'Print a single variable');
  row('env set KEY VALUE',   'Set a variable');
  row('env unset KEY',       'Remove a variable');
  row('channel',             'Show current release channel');
  row('channel stable|beta', 'Switch release channel');
  console.log('');

  cliSection('Updates & Auth');
  row('update',              'Update to latest on current channel');
  row('update stable|beta',  'Update and switch channel');
  row('login github-copilot','Authenticate GitHub Copilot');
  row('login openai-codex',  'Authenticate OpenAI Codex');
  row('login claude-code',   'Authenticate Claude Code');
  row('login grok-oauth',    'Authenticate Grok (xAI OAuth)');
  console.log('');

  cliSection('Admin');
  row('admin',               'Show admin dashboard URL and credentials');
  console.log('');

  cliSection('Billing');
  row('billing',             'Show billing configuration status');
  row('billing setup',       'Interactive Stripe setup wizard');
  row('billing enable',      'Enable billing and restart');
  row('billing disable',     'Disable billing and restart');
  console.log('');

  cliSection('Maintenance');
  row('migrate',             'Migrate from another agent installation');
  row('migrate dry-run',     'Preview what would be migrated');
  row('rebuild-web',         'Rebuild the bundled Flutter web client');
  row('version',             'Print installed version');
  console.log('');
}

async function runCLI(argv) {
  cliJsonOutput = argv.includes('--json');
  const setupCommand = argv[0] === 'install' || argv[0] === 'setup';
  const setupOptions = setupCommand
    ? parseSetupArguments(argv.slice(1))
    : {
        profile: null,
        json: cliJsonOutput,
      };
  if (setupCommand && setupOptions.profile) {
    validateSetupInteraction(setupOptions.profile, setupOptions);
  }
  setupEventWriter = new SetupEventWriter({
    profile: setupOptions.profile || 'quick',
    json: cliJsonOutput,
  });
  migrateLegacyRuntime((msg) => logInfo(msg));
  ensureRuntimeDirs();
  const command = argv[0];

  if (!command) {
    await cmdDefault();
    return;
  }

  switch (command) {
    case 'install':
      await cmdInstall({ args: argv.slice(1) });
      break;
    case 'setup':
      await cmdSetup(argv.slice(1));
      break;
    case 'env':
      await cmdEnv(argv.slice(1));
      break;
    case 'channel':
      cmdChannel(argv.slice(1));
      break;
    case 'update':
      await cmdUpdate(argv.slice(1));
      break;
    case 'restart':
      cmdRestart();
      break;
    case 'rebuild-web':
      await cmdRebuildWeb();
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
    case 'doctor':
      await cmdDoctor();
      break;
    case 'logs':
      cmdLogs();
      break;
    case 'backup':
      await cmdBackup();
      break;
    case 'fix':
    case 'repair':
      await cmdFix(argv.slice(1));
      break;
    case 'uninstall':
      cmdUninstall();
      break;
    case 'migrate':
      await cmdMigrate(argv.slice(1));
      break;
    case 'login':
      await cmdLogin(argv.slice(1));
      break;
    case 'billing':
      await cmdBilling(argv.slice(1));
      break;
    case 'admin': {
      cliBanner('Admin Dashboard', 'credentials');
      const adminCreds = readAdminCredentials();
      const port = loadEnvPort();
      logOk(`URL:      http://localhost:${port}/admin`);
      logInfo(`Username: ${adminCreds.username}`);
      logInfo(`Password: ${adminCreds.password}`);
      break;
    }
    case 'version':
    case '--version':
    case '-V':
      cmdVersion();
      break;
    case 'help':
    case '--help':
    case '-h':
      printHelp();
      break;
    default:
      throw new Error(`Unknown command: ${command}. Run "neoagent --help" for usage.`);
  }
}

module.exports = {
  parseProviderChoices,
  runCLI,
  scanForInstalledInstance,
};
