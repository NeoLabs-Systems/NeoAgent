'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const net = require('net');
const crypto = require('crypto');
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
  AGENT_DATA_DIR,
  LOG_DIR,
  ENV_FILE,
  DATABASE_FILE,
  PID_FILE,
  SETUP_STATE_FILE,
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
  readConfiguredReleaseChannel,
  writeReleaseChannelToEnvFile,
  describeReleaseChannelPolicy,
  choosePreferredBranchForChannel,
} = require('../runtime/release_channel');
const { parseEnv } = require('../runtime/env');
const { createGitHelpers } = require('../runtime/git_helpers');
const {
  isContainerImage,
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
const {
  defaultSourceInstallDirectory,
  prepareSourceInstallation,
  replaceSourceCheckoutWithRemote,
} = require('./source_install');
const ui = require('./cli/ui');
const prompt = require('./cli/prompt');
const { closeStepList, createStepList, formatDuration, noteActiveStep } = require('./cli/steps');
const { printHelp } = require('./cli/help');
const {
  needsAttention,
  printChecks,
  printStatus,
  statusChecks,
} = require('./cli/status');
const {
  printHomeHeader,
  printSetupFinished,
  printSetupProgress,
} = require('./cli/screens');
const { createUpdateGit } = require('./cli/updates');

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

// spawnSync's 1 MB default is too small for npm and Flutter build output.
const QUIET_OUTPUT_BUFFER = 64 * 1024 * 1024;

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

// While a step list is on screen, progress messages become the current step's
// detail line instead of scrolling past it. Warnings always print.
function logInfo(msg) {
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.message(msg);
    return;
  }
  if (!noteActiveStep(msg)) ui.item('info', msg);
}

function logOk(msg) {
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.message(msg);
    return;
  }
  if (!noteActiveStep(msg)) ui.item('ok', msg);
}

function logWarn(msg) {
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.message(msg, { warning: true });
    return;
  }
  ui.item('warn', msg);
}

function heading(text) {
  ui.section(text);
}

function rememberInstallAction(message) {
  if (!installActionItems.includes(message)) {
    installActionItems.push(message);
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

function maskEnvValue(key, value) {
  if (!/(KEY|TOKEN|SECRET|PASSWORD)/i.test(key)) return value;
  const text = String(value || '');
  if (text.length <= 8) return '********';
  return `${text.slice(0, 4)}...${text.slice(-4)}`;
}

function runQuiet(cmd, args, options = {}) {
  return spawnSync(cmd, args, {
    stdio: ['ignore', 'pipe', 'pipe'],
    encoding: 'utf8',
    cwd: APP_DIR,
    maxBuffer: QUIET_OUTPUT_BUFFER,
    ...options,
  });
}

// The last lines a failed quiet command printed, for its error message.
function outputTail(result, lines = 12) {
  const text = String(result.stderr || result.stdout || result.error?.message || '').trim();
  return text.split('\n').slice(-lines).join('\n');
}

// Runs a command without echoing its output; a failure carries its last lines.
function runOrThrow(cmd, args, options = {}, failureMessage = `Command failed: ${cmd} ${args.join(' ')}`) {
  const result = runQuiet(cmd, args, options);
  if (result.status !== 0) {
    const tail = outputTail(result);
    throw new Error(tail ? `${failureMessage}\n${tail}` : failureMessage);
  }
  return result;
}

const {
  latestGitTagVersion,
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

  const stableVersion = latestGitTagVersion('v[0-9]*.[0-9]*.[0-9]*', { excludePrerelease: true });
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

function ensureGitBranchForReleaseChannel(targetBranch) {
  return replaceSourceCheckoutWithRemote({
    run: (command, args, options = {}) => runQuiet(command, args, options),
    sourceDirectory: APP_DIR,
    targetBranch,
    onInfo: (message) => logInfo(message),
  });
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
  if (fs.existsSync(AGENT_DATA_DIR)) {
    fs.cpSync(AGENT_DATA_DIR, path.join(target, 'agent-data'), {
      recursive: true,
      force: false,
      errorOnExist: false,
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
  for (const proc of listNeoAgentServerProcesses()) {
    try {
      process.kill(proc.pid, 'SIGTERM');
    } catch {
      // Ignore stale processes.
    }
  }
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

// The AI accounts NeoAgent can sign in to; each flow saves its tokens.
const LOGIN_PROVIDERS = Object.freeze([
  { id: 'claude-code', label: 'Claude', flow: loginClaudeCode },
  { id: 'openai-codex', label: 'ChatGPT (OpenAI Codex)', flow: loginOpenAiCodex },
  { id: 'github-copilot', label: 'GitHub Copilot', flow: loginGithubCopilot },
  { id: 'grok-oauth', label: 'Grok (xAI)', flow: loginGrokOAuth },
]);

// Setup's AI question. Returns what was connected, or null when skipped.
async function chooseAiProvider() {
  const current = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());
  ui.title('Which AI should NeoAgent use?', 'This is the "brain" that reads your messages and decides what to do.');
  ui.blank();
  const method = await prompt.select('Connect an AI', [
    { value: 'login', label: 'Sign in with an account I already have', hint: 'Claude, ChatGPT, Copilot or Grok' },
    { value: 'key', label: 'Paste an API key', hint: 'OpenAI, Anthropic, Google, xAI and more' },
    { value: 'later', label: "I'll decide later", hint: "NeoAgent can't answer until you pick one" },
  ]);
  if (method === 'login') {
    const provider = await prompt.select('Which account?', LOGIN_PROVIDERS.map((entry) => ({
      value: entry,
      label: entry.label,
    })));
    await provider.flow();
    return provider.label;
  }
  if (method === 'key') {
    const provider = await prompt.select('Which service is the key from?', API_KEY_PROVIDERS.map((entry) => ({
      value: entry,
      label: entry.label,
      hint: String(current[entry.envKey] || '').trim() ? 'already saved' : '',
    })));
    const apiKey = await prompt.askSecret(`${provider.label} API key`, current[provider.envKey] || '');
    if (String(apiKey || '').trim()) {
      upsertEnvValue(provider.envKey, apiKey);
      return provider.label;
    }
  }
  rememberInstallAction('Pick an AI any time from the Admin tab in the app, or run `neoagent setup` again.');
  return null;
}

function defaultEnvLines(current = {}) {
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
    `NEOAGENT_DEPLOYMENT_MODE=${parseDeploymentMode(current.NEOAGENT_DEPLOYMENT_MODE || 'self_hosted')}`,
    `NEOAGENT_RELEASE_CHANNEL=${parseReleaseChannel(current.NEOAGENT_RELEASE_CHANNEL || 'stable') || 'stable'}`,
    `NEOAGENT_VM_GUEST_TOKEN=${current.NEOAGENT_VM_GUEST_TOKEN || randomSecret()}`,
    current.XAI_BASE_URL ? `XAI_BASE_URL=${current.XAI_BASE_URL}` : 'XAI_BASE_URL=https://api.x.ai/v1',
    current.OLLAMA_URL ? `OLLAMA_URL=${current.OLLAMA_URL}` : 'OLLAMA_URL=http://localhost:11434',
  ].filter(Boolean);
}

function writeDefaultEnvFile({ port = null } = {}) {
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
    io: { ask: prompt.ask, askSecret: prompt.askSecret, heading, logInfo, logOk },
  });
}

function askSetupProfile() {
  return prompt.select('How would you like to set up?', [
    { value: 'quick', label: 'Quickstart', hint: 'Safe defaults, ready in a few minutes (recommended)' },
    { value: 'full', label: 'Full setup', hint: 'Address, AI, integrations and voice, one by one' },
  ]);
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
  const existingInstallation = scanForInstalledInstance().installed;
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
    writeDefaultEnvFile({ port });
    writeSetupState(SETUP_STATE_FILE, {
      ...state,
      stage: 'provider',
      completedSections: ['core'],
    });
    completedSections = ['core'];
    if (!options.nonInteractive && ui.isInteractive()) {
      printSetupProgress(1);
      const connected = await chooseAiProvider();
      if (connected) completedSections.push('providers');
    } else {
      rememberInstallAction('Pick an AI any time from the Admin tab in the app, or run `neoagent setup` again.');
    }
  } else if (options.deferOptionalSections && options.nonInteractive) {
    writeDefaultEnvFile({ port });
    rememberInstallAction(
      'Configure AI providers from the Admin tab in the app or `neoagent env`. Continue integrations, voice, and optional tools in the NeoAgent app.',
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
  // Full setup may have changed PORT, so the plan reads the saved value.
  return createInstallPlan({
    profile: normalizedProfile,
    port: loadEnvPort(),
    platform: detectPlatform(),
    existingInstallation,
    runtimePackage: options.runtimePackage,
    deferredOptionalSections: options.deferOptionalSections,
  });
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
  if (cliJsonOutput) return;
  ui.blank();
  ui.item('ok', ui.paint.bold('Settings saved'));
  if (!managesLocalService()) {
    ui.note(`Next, run ${ui.paint.command('neoagent install')} to start NeoAgent on this computer.`);
  } else if (ui.isInteractive() && await prompt.confirm('Restart NeoAgent now to use them?')) {
    await cmdRestart();
  } else {
    ui.note(`They take effect after ${ui.paint.command('neoagent restart')}.`);
  }
}

async function cmdMigrate(args = []) {
  const subcommand = args[0] || 'run';
  const sources = detectSourceAgents();

  if (subcommand === '--help' || subcommand === '-h' || subcommand === 'help') {
    console.log('\nNeoAgent Migration');
    console.log('Usage: neoagent migrate [subcommand]');
    ui.blank();
    console.log('Subcommands:');
    console.log('  neoagent migrate           Interactive migration (select sources)');
    console.log('  neoagent migrate dry-run  Preview what would be migrated');
    console.log('  neoagent migrate status   Show detected source agents');
    console.log('  neoagent migrate openclaw-only   Migrate from OpenClaw only');
    console.log('  neoagent migrate hermes-only     Migrate from Hermes only');
    ui.blank();
    console.log('Migration searches for:');
    console.log('  - OpenClaw at ~/.openclaw/');
    console.log('  - Hermes at ~/.hermes/');
    ui.blank();
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

  ui.title('Bring your data to NeoAgent');
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

  ui.blank();
  const selection = await prompt.select('What would you like to bring over?', [
    { value: sources, label: 'Everything that was found' },
    { value: { openclaw: true, hermes: false }, label: 'Only OpenClaw' },
    { value: { openclaw: false, hermes: true }, label: 'Only Hermes' },
    { value: null, label: 'Cancel' },
  ], { cancelValue: null });
  if (selection) await cmdMigrateRun(selection);
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

async function loginClaudeCode() {
  // Check for Claude CLI credential file first (set by `claude login`)
  const cliCredsPath = path.join(os.homedir(), '.claude', '.credentials.json');
  if (fs.existsSync(cliCredsPath)) {
    try {
      const raw = fs.readFileSync(cliCredsPath, 'utf8');
      const data = JSON.parse(raw);
      const token = data?.claudeAiOauthTokens?.accessToken;
      if (token) {
        upsertEnvValue('CLAUDE_CODE_OAUTH_TOKEN', token);
        logOk('Signed in to Claude with your Claude Code login');
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

  printBrowserSignIn('Claude', authUrl.toString());

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
      logInfo('Waiting for you to finish signing in…');
      openInBrowser(authUrl.toString());
    });
    server.on('error', (err) => {
      clearTimeout(timeout);
      reject(new Error(`Could not start OAuth callback server: ${err.message}`));
    });
  });

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
  logOk('Signed in to Claude');
}

async function loginGrokOAuth() {
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

  printBrowserSignIn('Grok', authUrl.toString());

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
      logInfo('Waiting for you to finish signing in…');
      openInBrowser(authUrl.toString());
    });
    server.on('error', (err) => {
      clearTimeout(timeout);
      reject(new Error(`Could not start OAuth callback server on port ${redirectPort}: ${err.message}`));
    });
  });

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
  logOk('Signed in to Grok');
}

function printBrowserSignIn(service, url) {
  ui.title(`Sign in to ${service}`, 'Your browser opens to finish signing in.');
  ui.note("If it doesn't open, visit this address:");
  ui.print(`  ${url}`);
  ui.blank();
}

// Device-code sign-in: the person types a short code on the service's site.
function printDeviceCode(service, url, code) {
  ui.title(`Sign in to ${service}`);
  ui.blank();
  ui.print(`  Go to ${ui.paint.accent(url)}`);
  ui.print(`  and enter ${ui.paint.command(code)}`);
  ui.blank();
  logInfo('Waiting for you to finish signing in (up to 15 minutes)…');
}

async function loginGithubCopilot() {
  const clientId = '01ab8ac9400c4e429b23';
  const deviceData = await fetchAuthJson('https://github.com/login/device/code', {
    method: 'POST',
    headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ client_id: clientId, scope: 'user:email' })
  }, 'GitHub device-code request');

  const { device_code, user_code, verification_uri, interval } = deviceData;
  if (!device_code || !user_code || !verification_uri) {
    throw new Error('GitHub device-code response was missing required fields.');
  }
  printDeviceCode('GitHub Copilot', verification_uri, user_code);

  await pollDeviceCode({
    pollUrl: 'https://github.com/login/oauth/access_token',
    pollBody: () => ({ client_id: clientId, device_code, grant_type: 'urn:ietf:params:oauth:grant-type:device_code' }),
    intervalMs: (interval || 5) * 1000,
    timeoutMs: 15 * 60 * 1000,
    onToken: async (data) => {
      if (!data.access_token) return false;
      upsertEnvValue('GITHUB_COPILOT_ACCESS_TOKEN', data.access_token);
      return true;
    },
  });
  logOk('Signed in to GitHub Copilot');
}

async function loginOpenAiCodex() {
  const clientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
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
  printDeviceCode('ChatGPT', verification_uri, user_code);

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
  logOk('Signed in to ChatGPT');
}

async function cmdLogin(args = []) {
  let provider = LOGIN_PROVIDERS.find((entry) => entry.id === args[0]);
  if (!provider && !args[0] && ui.isInteractive()) {
    ui.blank();
    provider = await prompt.select('Which AI account would you like to connect?', LOGIN_PROVIDERS.map((entry) => ({
      value: entry,
      label: entry.label,
    })));
  }
  if (!provider) {
    throw new Error(`Unsupported login provider: ${args[0] || 'none'}. Available: ${LOGIN_PROVIDERS.map((entry) => entry.id).join(', ')}`);
  }
  await provider.flow();
  // A running server reads credentials at startup.
  if (managesLocalService() || await isPortOpen(loadEnvPort())) await cmdRestart();
}

function installDependencies() {
  runOrThrow(
    'npm',
    ['install', '--omit=dev', '--no-audit', '--no-fund'],
    { env: withInstallEnv() },
    "Installing NeoAgent's dependencies failed.",
  );
  if (!nativeDependenciesLoad()) repairNativeDependencies();
}

function assertSupportedNodeRuntime() {
  const major = Number(String(process.versions.node || '').split('.')[0]);
  if (!Number.isInteger(major) || major < 20) {
    throw new Error(`NeoAgent requires Node.js 20 or newer. Current runtime is ${process.versions.node || 'unknown'}.`);
  }
}

function installPreflight({ runtimePackage = false } = {}) {
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

  const platform = detectPlatform();
  const startsItself = (platform === 'macos' && commandExists('launchctl'))
    || (platform === 'linux' && commandExists('systemctl'));
  if (!startsItself) {
    rememberInstallAction("NeoAgent can't start by itself on this computer. After a restart, run `neoagent start`.");
  }
}

// The committed web client (server/public) is current when it was rebuilt
// after the last change to the app sources; CI commits that rebuild after
// every app change (.github/workflows/build-web-client.yml).
function bundledWebClientIsCurrent() {
  const lastChange = (target) => runQuiet('git', ['log', '-1', '--format=%H', '--', target], { cwd: APP_DIR }).stdout?.trim();
  const app = lastChange('flutter_app');
  const built = lastChange('server/public');
  if (!app || !built) return false;
  return app === built || runQuiet('git', ['merge-base', '--is-ancestor', app, built], { cwd: APP_DIR }).status === 0;
}

function buildBundledWebClientIfPossible({ required = false, requireFreshBuild = false } = {}) {
  // Build tools print a lot; only a failure's last lines are worth showing.
  let failedOutput = '';
  return buildWebClient({
    flutterAppDir: FLUTTER_APP_DIR,
    webClientDir: WEB_CLIENT_DIR,
    runCommand: (command, args, options = {}) => {
      const result = runQuiet(command, args, options);
      if (result.status !== 0) failedOutput = outputTail(result);
      return result;
    },
    commandExistsFn: commandExists,
    onMissingSources: () => logInfo('Using the app that came with NeoAgent'),
    onUsingBundledClient: () => logInfo('Using the app that came with NeoAgent'),
    onMissingFlutter: () => logInfo('Using the app that came with NeoAgent'),
    onBuildStart: () => logInfo('Building the app — this can take a few minutes'),
    onBuildSuccess: () => logOk('App rebuilt'),
    fail: (message) => {
      throw new Error(failedOutput ? `${message}\n${failedOutput}` : message);
    },
    required,
    requireFreshBuild,
    bundledIsCurrent: bundledWebClientIsCurrent,
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
// Dependencies with a compiled part. Being installed is not enough: npm 12
// skips install scripts it was not told to allow (package.json allowScripts),
// and a missing compiler stops a build, both leaving the package without its
// binary until NeoAgent crashes on first use.
// node-pty is optional (commands then run without a pseudo-terminal), so it is
// not required here.
const NATIVE_DEPENDENCIES = ['better-sqlite3', 'bcrypt'];

function nativeDependenciesLoad() {
  const check = "new (require('better-sqlite3'))(':memory:').close(); require('bcrypt');";
  return runQuiet(process.execPath, ['-e', check], { cwd: APP_DIR }).status === 0;
}

function dependenciesReady() {
  try {
    require.resolve('express', { paths: [APP_DIR] });
    require.resolve('better-sqlite3', { paths: [APP_DIR] });
  } catch {
    return false;
  }
  return nativeDependenciesLoad();
}

// What to install so native modules can be built from source, per system.
function buildToolsHint() {
  if (process.platform === 'darwin') return 'xcode-select --install';
  if (process.platform === 'win32') return 'install "Desktop development with C++" from the Visual Studio Build Tools';
  let osRelease = '';
  try {
    osRelease = fs.readFileSync('/etc/os-release', 'utf8');
  } catch {
    // Unknown system: the Debian/Ubuntu hint below.
  }
  if (/\b(arch|manjaro|endeavouros|cachyos)\b/i.test(osRelease)) return 'sudo pacman -S --needed base-devel python';
  if (/\b(fedora|rhel|centos|rocky|alma)\b/i.test(osRelease)) return 'sudo dnf install gcc-c++ make python3';
  if (/\balpine\b/i.test(osRelease)) return 'sudo apk add build-base python3';
  return 'sudo apt install build-essential python3';
}

function repairNativeDependencies() {
  logWarn('Native modules did not load; rebuilding them');
  // npm 12 takes the allowed scripts from package.json (allowScripts) and
  // rejects the command-line flag in a project; older npm runs them anyway.
  runQuiet('npm', ['rebuild', ...NATIVE_DEPENDENCIES], { cwd: APP_DIR, env: withInstallEnv(), stdio: 'inherit' });
  if (nativeDependenciesLoad()) {
    logOk('Native modules rebuilt');
    return;
  }
  throw new Error(`NeoAgent's native modules could not be installed for Node.js ${process.versions.node}. `
    + `Install the build tools (${buildToolsHint()}) and run the installer again.`);
}

async function fetchLocalHandshake(port) {
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
      return data;
    }
  } catch {
    // The service may still be migrating or starting.
  }
  return null;
}

async function isOwnInstanceReachable(port) {
  if (!(await isPortOpen(port))) return false;
  const handshake = await fetchLocalHandshake(port);
  if (!handshake) return false;
  const expectedInstanceId = require(
    '../server/services/setup/onboarding'
  ).ensureInstance().instance_id;
  return handshake.instanceId === expectedInstanceId;
}

async function waitForServerReady(port, timeoutMs = 30000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (await isOwnInstanceReachable(port)) return true;
    await abortableDelay(400);
  }
  const error = new Error(`NeoAgent did not become reachable on port ${port}.`);
  error.code = 'SETUP_SERVER_NOT_READY';
  throw error;
}

async function ensureComputerRuntime({ required = false, downloadImage = true } = {}) {
  const {
    TERMINAL_ENV_DOCKER,
    TERMINAL_ENV_HOST,
    getTerminalEnv,
  } = require('../server/utils/deployment');
  if (getTerminalEnv() === TERMINAL_ENV_HOST) {
    // The runtime is this machine. Nothing to install, nothing to download.
    logOk('Host computer runtime is ready (agents run on this machine, unisolated)');
    return true;
  }
  if (getTerminalEnv() === TERMINAL_ENV_DOCKER) {
    return ensureDockerComputerRuntime({ required, downloadImage });
  }
  cleanupLegacyDockerRuntime();
  try {
    const {
      QemuVMManager,
      resolveQemuImgBinary,
      resolveQemuSystemBinary,
    } = require('../server/services/runtime/qemu_vm_manager');
    const { restoreQemuComputerRuntime } = require('./qemu_runtime_install');
    const qemuAvailable = Boolean(resolveQemuSystemBinary() && resolveQemuImgBinary());
    if (!qemuAvailable) logInfo('QEMU computer runtime is missing. Restoring…');
    const restored = restoreQemuComputerRuntime({
      platform: detectPlatform(),
      commandExists,
      runOrThrow,
      logInfo,
      allowHostInstall: !qemuAvailable,
    });
    if (restored.action === 'signed') {
      logOk('Enabled hardware acceleration on the bundled QEMU runtime');
    } else if (restored.action === 'copied') {
      logOk('Restored the signed QEMU runtime from the installed package');
    } else if (restored.action === 'staged') {
      logOk('Installed and staged the QEMU computer runtime');
    }
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
    rememberInstallAction('Install QEMU, then run `neoagent repair` to stage the computer runtime and guest image.');
    return false;
  }
}

async function ensureDockerComputerRuntime({ required = false, downloadImage = true } = {}) {
  try {
    const { createComputerVmManager } = require('../server/services/runtime/vm_manager');
    const readiness = await createComputerVmManager().prepareRuntime({ downloadImage });
    logOk(`Docker computer runtime is ready (${readiness.image || 'guest image builds on first start'})`);
    return true;
  } catch (err) {
    const message = `Computer runtime preparation did not complete: ${err.message}`;
    if (required) throw new Error(message);
    logWarn(message);
    rememberInstallAction('Start Docker, then run `neoagent repair` to build the guest container image.');
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

// yt-dlp lets the agent pull audio and video from links. It is optional, so a
// failed install becomes a note for later rather than an error.
function ensureYtDlpInstalled() {
  if (commandExists('yt-dlp')) return true;
  const platform = detectPlatform();
  const installers = {
    macos: [['brew', ['install', 'yt-dlp']]],
    linux: [['pipx', ['install', 'yt-dlp']], ['pip3', ['install', '--user', 'yt-dlp']]],
  }[platform] || [];
  for (const [command, args] of installers) {
    if (!commandExists(command)) continue;
    logInfo('Adding video and audio download support');
    if (runQuiet(command, args, { env: withInstallEnv() }).status === 0) return true;
  }
  rememberInstallAction(platform === 'macos'
    ? 'To let NeoAgent download video and audio, install yt-dlp: `brew install yt-dlp`.'
    : 'To let NeoAgent download video and audio, install yt-dlp: `pipx install yt-dlp`.');
  return false;
}

async function cmdInstall(args = []) {
  if (args.includes('--adopt-existing')) {
    await cmdAdoptExistingInstallation();
    return;
  }
  const options = parseSetupArguments(args);
  if (options.releaseChannel !== null) {
    const requestedChannel = parseReleaseChannel(options.releaseChannel);
    if (!requestedChannel) {
      throw new Error('Usage: neoagent install --channel stable|beta');
    }
    writeReleaseChannelToEnvFile(requestedChannel, ENV_FILE);
    process.env.NEOAGENT_RELEASE_CHANNEL = requestedChannel;
  }
  printSetupProgress(0);
  ui.title(`Welcome to ${APP_NAME}`, "Let's get it running on this computer. It takes a few minutes.");
  ui.blank();
  const profile = await resolveSetupProfile(options);
  if (!setupEventWriter) {
    setupEventWriter = new SetupEventWriter({
      profile,
      json: options.json,
    });
  }
  setupEventWriter.profile = profile;
  installActionItems.length = 0;
  let list = null;
  try {
    setupEventWriter.start('prepare', 'Checking this computer', 0.01);
    installPreflight({ runtimePackage: options.runtimePackage });
    const plan = await runSetupProfile(profile, options);

    // Optional downloads are decided before the progress list takes the screen.
    const interactiveFull = profile === 'full' && !options.nonInteractive && ui.isInteractive();
    const downloadImage = interactiveFull
      && await prompt.confirm("Download the agent's computer now? (about 1 GB; otherwise on first use)");
    const mediaSupport = interactiveFull
      && await prompt.confirm('Add video and audio download support (yt-dlp)?', { initial: false });

    printSetupProgress(2);
    ui.title(`Installing ${APP_NAME}`);
    ui.blank();
    list = createStepList([
      ["Preparing NeoAgent's files", "Prepared NeoAgent's files"],
      ['Preparing the app', 'Prepared the app'],
      ["Setting up the agent's computer", "Set up the agent's computer"],
      ['Starting NeoAgent', 'Started NeoAgent'],
      ["Checking it's answering", "It's answering"],
    ], { bar: true });

    setupEventWriter.start('dependencies', 'Preparing NeoAgent runtime', 0.2);
    await list.run(0, () => {
      if (dependenciesReady()) return;
      if (options.runtimePackage) {
        const error = new Error('The verified runtime package is missing required dependencies.');
        error.code = 'SETUP_RUNTIME_INCOMPLETE';
        throw error;
      }
      installDependencies();
    });
    await list.run(1, () => {
      if (!options.runtimePackage) {
        buildBundledWebClientIfPossible({ required: true, requireFreshBuild: true });
      } else if (!hasBundledWebClient(WEB_CLIENT_DIR)) {
        const error = new Error('The verified runtime package does not contain the web client.');
        error.code = 'SETUP_RUNTIME_INCOMPLETE';
        throw error;
      }
    });
    setupEventWriter.complete('dependencies', 'Runtime prepared', 0.45);

    await list.run(2, async () => {
      if (mediaSupport) ensureYtDlpInstalled();
      return ensureComputerRuntime({ required: false, downloadImage });
    });

    setupEventWriter.start('service', 'Starting NeoAgent in the background', 0.55);
    const port = plan.port;
    await list.run(3, async () => {
      await releasePortForSetup(port);
      getServiceAdapters().install(detectPlatform());
    });
    await list.run(4, () => waitForServerReady(port));
    closeStepList(list);
    list = null;
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

    if (!cliJsonOutput) await finishInstall({ backendUrl });
  } catch (error) {
    if (list) closeStepList(list);
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

// Anything still to do was collected as install notes along the way.
async function finishInstall({ backendUrl }) {
  const env = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());
  const publicUrl = String(env.PUBLIC_URL || '').trim();
  const notes = [...installActionItems];
  if (publicUrl && String(env.SECURE_COOKIES || '').trim().toLowerCase() !== 'true') {
    notes.unshift(`On this computer you can also use ${backendUrl}.`);
  }
  printSetupProgress(3);
  printSetupFinished({
    url: publicUrl || backendUrl,
    startsItself: managesLocalService(),
    notes: notes.map((text) => text.replace(/`([^`]+)`/g, (_, command) => ui.paint.command(command))),
  });
  ui.keys([['enter', 'open it'], ['q', 'done']]);
  if (await prompt.waitForKey(['return', 'q', 'escape']) === 'return') openInBrowser(publicUrl || backendUrl);
}

function openInBrowser(url) {
  const opener = { darwin: 'open', win32: 'explorer' }[process.platform] || 'xdg-open';
  spawnSync(opener, [url], { stdio: 'ignore' });
}

async function cmdAdoptExistingInstallation() {
  const hasExistingRuntimeData = fs.existsSync(DATABASE_FILE)
    || (fs.existsSync(AGENT_DATA_DIR) && fs.readdirSync(AGENT_DATA_DIR).length > 0);
  if (!hasExistingRuntimeData) {
    throw new Error('No existing NeoAgent runtime data was found. Run `neoagent install` instead.');
  }
  ensureRuntimeDirs();
  if (!dependenciesReady()) {
    throw new Error(`The source installation at ${APP_DIR} is missing runtime dependencies.`);
  }
  if (!hasBundledWebClient(WEB_CLIENT_DIR)) {
    throw new Error(`The source installation at ${APP_DIR} is missing the bundled web client.`);
  }
  ui.title(`Moving ${APP_NAME} to its new home`, `Your data stays where it is; NeoAgent will run from ${APP_DIR}.`);
  ui.blank();
  const port = loadEnvPort();
  await runSteps([
    [['Saving a backup of your settings and chats', 'Saved a backup of your settings and chats'], () => backupRuntimeData({ prefix: 'pre-source-migration' })],
    [['Stopping the old NeoAgent', 'Stopped the old NeoAgent'], async () => {
      stopService();
      if (!(await waitForServerExit())) {
        throw new Error('NeoAgent did not stop in time. The backup is intact and the service was not replaced.');
      }
    }],
    [['Starting NeoAgent from its new home', 'Started NeoAgent from its new home'], () => getServiceAdapters().install(detectPlatform())],
    [["Checking it's answering", "It's answering"], () => waitForServerReady(port)],
  ]);
  printRunning(`${APP_NAME} is running.`);
}

// One step list for a fixed sequence of [label, task] pairs. Returns each
// task's result in order.
async function runSteps(steps, options) {
  const list = createStepList(steps.map(([label]) => label), options);
  const results = [];
  try {
    for (const [index, [, task]] of steps.entries()) {
      results.push(await list.run(index, task));
    }
  } finally {
    closeStepList(list);
  }
  return results;
}

function printRunning(headline) {
  ui.blank();
  ui.item('ok', ui.paint.bold(headline), '');
  ui.print(`    ${ui.paint.accent(`http://localhost:${loadEnvPort()}`)}`);
}

// Runs a stop left mid-task; the server resumes them on its next start.
function countResumableRuns() {
  if (!fs.existsSync(DATABASE_FILE)) return 0;
  return require('../server/services/ai/runtime/restart_resume').countResumableRuns();
}

function printResumeNote(count, when) {
  if (count === 0) return;
  ui.note(`${count === 1 ? '1 task that was running picks' : `${count} tasks that were running pick`} up where ${count === 1 ? 'it' : 'they'} left off ${when}.`);
}

// What `neoagent status` and the home screen know about this installation.
async function collectStatusFacts({ checkForUpdate = false } = {}) {
  const port = loadEnvPort();
  const running = await isPortOpen(port);
  const handshake = running ? await fetchLocalHandshake(port) : null;
  const platform = detectPlatform();
  let serviceActive = false;
  if (platform === 'macos' && fs.existsSync(PLIST_DST)) {
    const result = runQuiet('launchctl', ['list', SERVICE_LABEL]);
    serviceActive = result.status === 0 && Boolean(result.stdout.trim());
  } else if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    const result = runQuiet('systemctl', ['--user', 'is-active', 'neoagent']);
    serviceActive = result.status === 0 && result.stdout.trim() === 'active';
  }

  let computer;
  try {
    const { createComputerBackend } = require('../server/services/runtime/backend_factory');
    const readiness = createComputerBackend().vmManager.getReadiness();
    let detail = 'Ready for tasks that need a desktop';
    if (readiness.isolated === false) detail = 'Runs directly on this computer';
    else if (!readiness.imageReady) detail = 'Ready — downloads its system on first use';
    computer = { ready: readiness.ready === true, detail };
  } catch (error) {
    computer = { ready: false, detail: error.message };
  }

  // Reading admins opens the database, so only do it once one exists.
  let admins = null;
  if (fs.existsSync(DATABASE_FILE)) {
    const { listAdmins, needsAdminGrant } = require('../server/services/access/admin');
    admins = { names: listAdmins().map((admin) => admin.username), missing: needsAdminGrant() };
  }

  const channel = currentReleaseChannel();
  const processes = listNeoAgentServerProcesses();
  const updateCheck = checkForUpdate ? findPendingUpdate(channel) : { checked: false, update: null };
  return {
    appDir: APP_DIR,
    envFile: ENV_FILE,
    port,
    url: `http://localhost:${port}`,
    running,
    version: readInstalledPackageVersion(),
    versionLabel: currentInstalledVersionLabel(),
    runningVersion: handshake?.serverVersion || null,
    channel,
    channelSummary: releaseChannelSummary(channel),
    serviceActive,
    configPresent: fs.existsSync(ENV_FILE),
    webClientPresent: hasBundledWebClient(WEB_CLIENT_DIR),
    computer,
    admins,
    pids: processes.map((proc) => proc.pid),
    processCount: processes.length,
    update: updateCheck.update,
    updateChecked: updateCheck.checked,
  };
}

function isGitCheckout() {
  return fs.existsSync(path.join(APP_DIR, '.git')) && commandExists('git');
}

function findPendingUpdate(channel) {
  if (!isGitCheckout()) return { checked: false, update: null };
  const updateGit = createUpdateGit(runQuiet);
  if (!updateGit.fetchRemote()) return { checked: false, update: null };
  return { checked: true, update: updateGit.pendingUpdate(resolvePreferredGitBranch(channel)) };
}

function homeActions(facts) {
  return [
    facts.running
      ? { label: 'Open NeoAgent in my browser', value: async () => openInBrowser(facts.url) }
      : { label: 'Start NeoAgent', value: cmdStart },
    facts.update && {
      label: 'Get the latest version',
      hint: `${facts.update.version || 'A new version'} is ready`,
      value: () => cmdUpdate(),
    },
    { label: 'Check that everything works', value: () => cmdStatus() },
    facts.running && { label: 'Restart NeoAgent', value: cmdRestart },
    { label: 'Change settings', hint: 'AI, address, integrations', value: () => cmdSetup() },
    { label: "Something's wrong — help me fix it", value: cmdDoctor },
    { label: 'More…', hint: 'every command', value: async () => printHelp() },
  ].filter(Boolean);
}

async function cmdDefault() {
  const interruptedSetup = readSetupState(SETUP_STATE_FILE);
  if (interruptedSetup && interruptedSetup.status !== 'completed') {
    ui.blank();
    ui.note('Picking up the setup you started earlier.');
    await cmdInstall(['--resume']);
    return;
  }
  if (!scanForInstalledInstance().installed) {
    if (fs.existsSync(ENV_FILE)) logInfo(`Your existing settings in ${ENV_FILE} are kept.`);
    await cmdInstall();
    return;
  }

  const facts = await collectStatusFacts({ checkForUpdate: ui.isInteractive() });
  // Running state and updates are in the header and the menu already.
  printHomeHeader(facts, statusChecks(facts)
    .filter((check) => check.id !== 'server' && check.id !== 'version' && needsAttention(check)));
  ui.blank();
  if (!ui.isInteractive()) {
    ui.print(`  ${ui.paint.faint('Every command:')} ${ui.paint.command('neoagent help')}`);
    ui.blank();
    return;
  }
  const action = await prompt.select('What would you like to do?', homeActions(facts), { cancelValue: null });
  if (action) await action();
}

// Starts whichever service manager this installation uses.
function launchService() {
  const platform = detectPlatform();
  if (platform === 'macos' && fs.existsSync(PLIST_DST)) {
    getServiceAdapters().installMacService();
  } else if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    runOrThrow('systemctl', ['--user', 'start', 'neoagent']);
    runOrThrow('systemctl', ['--user', 'is-active', '--quiet', 'neoagent']);
  } else {
    getServiceAdapters().startFallback();
  }
}

// Which program is listening on a port, when the system can tell (lsof).
function findPortOwner(port) {
  if (!commandExists('lsof')) return null;
  const result = runQuiet('lsof', ['-nP', `-iTCP:${port}`, '-sTCP:LISTEN', '-Fpc']);
  if (result.status !== 0) return null;
  const pid = Number(/^p(\d+)/m.exec(result.stdout)?.[1]);
  return pid ? { pid, command: /^c(.+)$/m.exec(result.stdout)?.[1] || 'An app' } : null;
}

// Only ever treat a listener as ours when it answers as this instance or is
// one of our server processes. Anything else is not ours to stop.
async function portHeldByOtherProgram(port) {
  if (!(await isPortOpen(port))) return false;
  if (await isOwnInstanceReachable(port)) return false;
  const owner = findPortOwner(port);
  if (owner) return !listNeoAgentServerProcesses().some((proc) => proc.pid === owner.pid);
  return !managesLocalService();
}

function portInUseError(port) {
  const error = new Error(
    `Another app on this computer is already using port ${port}, the address NeoAgent wants. `
    + 'Close that app, or give NeoAgent another port with `neoagent env set PORT <number>`.',
  );
  error.code = 'SETUP_PORT_IN_USE';
  return error;
}

// A server that cannot bind its port exits at startup, so a taken port is
// settled before starting: interactively by moving NeoAgent to a free one.
async function ensureStartPort() {
  const port = loadEnvPort();
  if (!(await portHeldByOtherProgram(port))) return port;
  if (!ui.isInteractive()) throw portInUseError(port);

  ui.blank();
  ui.print(`  ${ui.paint.error('✕')} ${ui.paint.bold("NeoAgent couldn't start")}`);
  ui.print(`    ${ui.paint.muted('Nothing is broken — your data is safe.')}`);
  ui.section('What happened');
  ui.print(`  Another app on this computer is already using the address NeoAgent wants (port ${port}).`);
  ui.blank();
  for (;;) {
    const choice = await prompt.select('What would you like to do?', [
      { value: 'move', label: 'Use a free address instead', hint: 'NeoAgent moves to the next free port' },
      { value: 'show', label: 'Show me which app is using it' },
      { value: 'cancel', label: 'Cancel' },
    ], { cancelValue: 'cancel' });
    if (choice === 'cancel') throw prompt.cancelledError();
    if (choice === 'show') {
      const owner = findPortOwner(port);
      ui.item('info', owner
        ? `${owner.command} (process ${owner.pid}) is using port ${port}.`
        : "This computer can't tell which app it is.");
      ui.blank();
      continue;
    }
    const nextPort = await findAvailablePort(port + 1);
    upsertEnvValue('PORT', String(nextPort));
    ui.item('ok', `NeoAgent will use port ${nextPort}`);
    if (String(parseEnv(readEnvFileRaw()).get('PUBLIC_URL') || '').trim()) {
      logWarn('If a proxy forwards your public address to NeoAgent, point it at the new port too.');
    }
    ui.blank();
    return nextPort;
  }
}

async function cmdStart() {
  const port = await ensureStartPort();
  // Launching only spawns the process. Callers (the desktop app included)
  // treat success as "the backend answers now", so wait for the handshake.
  await runSteps([
    [['Starting NeoAgent', 'Started NeoAgent'], launchService],
    [["Checking it's answering", "It's answering"], () => waitForServerReady(port)],
  ]);
  if (cliJsonOutput) logOk(`${APP_NAME} is reachable`);
  else printRunning(`${APP_NAME} is running.`);
}

// Asks the service manager (or the fallback process) to stop NeoAgent.
function stopService() {
  const platform = detectPlatform();
  if (platform === 'macos' && fs.existsSync(PLIST_DST)) {
    const domain = launchctlDomain();
    if (domain) {
      runQuiet('launchctl', ['bootout', domain, PLIST_DST]);
      runQuiet('launchctl', ['bootout', launchctlServiceTarget()]);
    }
    runQuiet('launchctl', ['unload', PLIST_DST]);
  } else if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    runQuiet('systemctl', ['--user', 'stop', 'neoagent']);
  } else {
    if (fs.existsSync(PID_FILE)) {
      const pid = Number(fs.readFileSync(PID_FILE, 'utf8').trim());
      if (Number.isFinite(pid) && pid > 0) {
        try {
          process.kill(pid, 'SIGTERM');
        } catch {
          // A stale PID file; the process is already gone.
        }
      }
      fs.rmSync(PID_FILE, { force: true });
    }
    killByPort(loadEnvPort());
  }
  killNeoAgentServerProcesses();
}

async function waitForServerExit(timeoutMs = 15_000) {
  const deadline = Date.now() + timeoutMs;
  while (listNeoAgentServerProcesses().length > 0 && Date.now() < deadline) {
    await abortableDelay(250);
  }
  return listNeoAgentServerProcesses().length === 0;
}

// Stops NeoAgent and returns how many cut-off tasks it will resume.
async function stopAndWait() {
  stopService();
  if (!(await waitForServerExit())) {
    throw new Error('NeoAgent did not stop in time. Try again, or restart this computer.');
  }
  return countResumableRuns();
}

async function cmdStop() {
  const [resumable] = await runSteps([[['Stopping NeoAgent', 'Stopped NeoAgent'], stopAndWait]]);
  ui.blank();
  logOk(`${APP_NAME} stopped`);
  printResumeNote(resumable, 'when NeoAgent starts again');
}

function managesLocalService() {
  const platform = detectPlatform();
  if (platform === 'macos' && fs.existsSync(PLIST_DST)) return true;
  if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) return true;
  try {
    const pid = Number(fs.readFileSync(PID_FILE, 'utf8').trim());
    if (!Number.isFinite(pid) || pid <= 0) return false;
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// Installing over a running NeoAgent starts a second server on the same port,
// so the old one has to let go of it first. The port is the portable signal:
// `ps` is unavailable on Windows, where the update crashed with EADDRINUSE.
async function releasePortForSetup(port) {
  if (!(await isPortOpen(port))) {
    return;
  }
  if (await portHeldByOtherProgram(port)) throw portInUseError(port);
  logInfo(`Stopping the NeoAgent already running on port ${port}`);
  stopService();
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    await abortableDelay(250);
    if (!(await isPortOpen(port))) {
      return;
    }
  }
  const error = new Error(
    `Port ${port} is still in use. Stop whatever is listening on it, then run the update again.`,
  );
  error.code = 'SETUP_PORT_IN_USE';
  throw error;
}

async function cmdRestart() {
  const startedAt = Date.now();
  const port = await ensureStartPort();
  const [, resumable] = await runSteps([
    [['Getting the app ready', 'Got the app ready'], () => buildBundledWebClientIfPossible()],
    [['Stopping NeoAgent', 'Stopped NeoAgent'], stopAndWait],
    [['Starting it again', 'Started it again'], launchService],
    [["Checking it's answering", "It's answering"], () => waitForServerReady(port)],
  ]);
  if (cliJsonOutput) {
    logOk(`${APP_NAME} is reachable`);
    return;
  }
  printRunning(`Back online in ${formatDuration(Date.now() - startedAt)}.`);
  printResumeNote(resumable, 'now');
  ui.blank();
}

async function cmdRebuildWeb() {
  await runSteps([[['Rebuilding the app', 'Rebuilt the app'], () => buildBundledWebClientIfPossible()]]);
}

async function cmdBackup() {
  const wasRunning = listNeoAgentServerProcesses().length > 0;
  ui.title(`Backing up ${APP_NAME}`, wasRunning ? 'NeoAgent pauses while the backup is made.' : '');
  ui.blank();
  let target;
  const steps = [
    [['Saving your settings and chats', 'Saved your settings and chats'], () => {
      target = backupRuntimeData({ prefix: 'manual' });
    }],
    [["Saving the agent's computer", "Saved the agent's computer"], () => backupComputerDisks(target)],
  ];
  if (wasRunning) {
    steps.unshift([['Pausing NeoAgent', 'Paused NeoAgent'], async () => {
      stopService();
      if (!(await waitForServerExit())) {
        throw new Error('NeoAgent did not stop in time for a consistent computer backup.');
      }
    }]);
    steps.push([['Starting NeoAgent again', 'Started NeoAgent again'], async () => {
      launchService();
      await waitForServerReady(loadEnvPort());
    }]);
  }
  try {
    await runSteps(steps);
  } catch (error) {
    // A failed backup must not leave NeoAgent switched off.
    if (wasRunning && listNeoAgentServerProcesses().length === 0) await cmdStart();
    throw error;
  }
  ui.blank();
  ui.item('ok', ui.paint.bold('Backup saved'), target);
  ui.blank();
  return target;
}

async function cmdFix(args = []) {
  const runtimePackage = args.includes('--runtime-package');
  ui.title(`Repairing ${APP_NAME}`, 'Your data is backed up first. This can take a few minutes.');
  ui.blank();
  const missingPackageFile = (what) => {
    const error = new Error(`The verified runtime package is missing ${what}.`);
    error.code = 'SETUP_RUNTIME_INCOMPLETE';
    return error;
  };
  const steps = [
    [['Stopping NeoAgent', 'Stopped NeoAgent'], async () => {
      stopService();
      if (!(await waitForServerExit())) {
        throw new Error('NeoAgent did not stop in time for a consistent repair backup.');
      }
    }],
    [['Saving a backup of your settings and chats', 'Saved a backup of your settings and chats'], () => backupRuntimeData()],
  ];
  if (isGitCheckout()) {
    steps.push([["Resetting NeoAgent's files", "Reset NeoAgent's files"], () => {
      const dirty = runQuiet('git', ['status', '--porcelain']);
      if (dirty.status === 0 && dirty.stdout.trim()) runOrThrow('git', ['checkout', '--', '.']);
    }]);
  }
  steps.push([['Reinstalling what it needs', 'Reinstalled what it needs'], () => {
    if (runtimePackage) {
      if (!dependenciesReady()) throw missingPackageFile('required dependencies');
      return;
    }
    fs.rmSync(path.join(APP_DIR, 'node_modules'), { recursive: true, force: true });
    installDependencies();
  }]);
  steps.push([['Preparing the app', 'Prepared the app'], () => {
    if (!runtimePackage) buildBundledWebClientIfPossible({ required: true });
    else if (!hasBundledWebClient(WEB_CLIENT_DIR)) throw missingPackageFile('the bundled web client');
  }]);
  steps.push([["Checking the agent's computer", "Checked the agent's computer"], async () => {
    await ensureComputerRuntime({ required: runtimePackage, downloadImage: true });
    const disks = repairComputerDisks();
    if (disks.repaired > 0) logOk(`Repaired ${disks.repaired} of ${disks.checked} computer disk(s)`);
  }]);
  steps.push([['Starting NeoAgent', 'Started NeoAgent'], () => getServiceAdapters().install(detectPlatform())]);
  await runSteps(steps, { bar: true });
  if (cliJsonOutput) return;
  printRunning('Repair complete.');
  ui.note(`Check on it any time with ${ui.paint.command('neoagent status')}.`);
  ui.blank();
}

async function cmdUninstall() {
  if (ui.isInteractive() && !(await prompt.confirm(
    "Stop NeoAgent and stop it starting with your computer? Your data stays.",
    { initial: false },
  ))) {
    return;
  }
  const platform = detectPlatform();
  if (platform === 'macos') {
    runQuiet('launchctl', ['unload', PLIST_DST]);
    fs.rmSync(PLIST_DST, { force: true });
  } else if (platform === 'linux') {
    runQuiet('systemctl', ['--user', 'stop', 'neoagent']);
    runQuiet('systemctl', ['--user', 'disable', 'neoagent']);
    fs.rmSync(SYSTEMD_UNIT, { force: true });
    runQuiet('systemctl', ['--user', 'daemon-reload']);
  } else {
    stopService();
  }
  logOk('NeoAgent no longer starts with your computer');
  ui.note(`Your settings and chats are still in ${RUNTIME_HOME}. Turn it back on with ${ui.paint.command('neoagent install')}.`);
}

async function cmdStatus(args = []) {
  const facts = await collectStatusFacts({ checkForUpdate: !cliJsonOutput && ui.isInteractive() });
  if (cliJsonOutput && setupEventWriter) {
    setupEventWriter.emit('ready', {
      stage: 'status',
      progress: 1,
      message: facts.running ? 'NeoAgent is reachable' : 'NeoAgent is not reachable',
      result: {
        running: facts.running,
        backendUrl: facts.url,
        configPresent: facts.configPresent,
        webClientPresent: facts.webClientPresent,
        version: facts.versionLabel,
        runningVersion: facts.runningVersion,
        releaseChannel: facts.channel,
        processCount: facts.processCount,
      },
    });
    return;
  }
  printStatus(facts, { details: args.includes('--details') });
}

async function cmdDoctor() {
  const port = loadEnvPort();
  const setupState = readSetupState(SETUP_STATE_FILE);
  let computerReadiness = null;
  try {
    const { createComputerBackend } = require('../server/services/runtime/backend_factory');
    computerReadiness = createComputerBackend().vmManager.getReadiness();
  } catch {}
  let runtimeWritable = true;
  try {
    fs.accessSync(RUNTIME_HOME, fs.constants.R_OK | fs.constants.W_OK);
  } catch {
    runtimeWritable = false;
  }
  const serverReachable = await isPortOpen(port);
  const setupPending = Boolean(setupState && setupState.status !== 'completed');
  const computerReady = computerReadiness?.ready === true;
  let imageMessage = 'Downloads on first use';
  if (computerReadiness?.isolated === false) imageMessage = 'Not needed — tasks run on this computer';
  else if (computerReadiness?.imageReady === true) imageMessage = 'Downloaded';
  // `action` is the command that fixes a failed check.
  const check = (id, label, ok, code, message, action) => ({
    id, label, ok, code: ok ? null : code, message: message[ok ? 0 : 1], action,
  });
  const checks = [
    check('runtime-access', "NeoAgent's data folder", runtimeWritable, 'DOCTOR_RUNTIME_NOT_WRITABLE',
      ['Can be read and changed', `NeoAgent can't write to ${RUNTIME_HOME} — check your user owns it`], null),
    check('configuration', 'Settings', fs.existsSync(ENV_FILE), 'DOCTOR_CONFIG_MISSING',
      ['Saved', 'Not set up yet'], 'neoagent setup --quick'),
    check('dependencies', "NeoAgent's files", dependenciesReady(), 'DOCTOR_RUNTIME_INCOMPLETE',
      ['All there', 'Some are missing'], 'neoagent repair'),
    check('web-client', 'App in your browser', hasBundledWebClient(WEB_CLIENT_DIR), 'DOCTOR_WEB_CLIENT_MISSING',
      ['Installed', 'Missing'], 'neoagent repair'),
    check('computer-runtime', "Agent's computer", computerReady, 'DOCTOR_COMPUTER_RUNTIME_MISSING',
      ['Ready', 'Needs to be prepared'], 'neoagent repair'),
    check('computer-image', "Computer's system", computerReady, 'DOCTOR_COMPUTER_IMAGE_UNAVAILABLE',
      [imageMessage, imageMessage], 'neoagent repair'),
    check('server', 'NeoAgent', serverReachable, 'DOCTOR_SERVER_UNREACHABLE',
      [`Running on port ${port}`, `Not running on port ${port}`], 'neoagent start'),
    check('setup-state', 'Setup', !setupPending, 'DOCTOR_SETUP_INCOMPLETE',
      ['Finished', `Stopped partway, at ${setupState?.stage}`], 'neoagent setup --resume'),
  ];

  if (cliJsonOutput && setupEventWriter) {
    const healthy = checks.every((entry) => entry.ok);
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

  ui.title(`Checking ${APP_NAME}`, 'Nothing is changed while this runs.');
  printChecks(checks.map((entry) => ({
    tone: entry.ok ? 'ok' : 'error',
    label: entry.label,
    detail: entry.message,
    fix: entry.ok ? null : entry.action,
  })));
  ui.blank();
  if (checks.every((entry) => entry.ok)) {
    ui.item('ok', ui.paint.bold('No problems found'));
    ui.blank();
  } else if (ui.isInteractive() && await prompt.confirm('Fix these for you now? Your data is backed up first.')) {
    await cmdFix();
  } else {
    ui.note(`Most problems are fixed by ${ui.paint.command('neoagent repair')}.`);
    ui.blank();
  }
}

function cmdLogs() {
  ensureLogDir();
  const log = path.join(LOG_DIR, 'neoagent.log');
  const err = path.join(LOG_DIR, 'neoagent.error.log');
  if (!fs.existsSync(log)) fs.writeFileSync(log, '');
  if (!fs.existsSync(err)) fs.writeFileSync(err, '');
  ui.title('What NeoAgent is doing', 'Press Ctrl+C to stop watching.');
  ui.blank();
  spawnSync('tail', ['-f', log, err], { stdio: 'inherit', cwd: APP_DIR });
}

function cmdChannel(args = []) {
  const requested = args[0];

  if (!requested) {
    ui.blank();
    ui.item('info', `Updates come from the ${releaseChannelSummary(currentReleaseChannel())} channel.`);
    ui.note(`Switch with ${ui.paint.command('neoagent channel stable')} or ${ui.paint.command('neoagent channel beta')}.`);
    ui.blank();
    return;
  }

  const nextChannel = parseReleaseChannel(requested);
  if (!nextChannel) {
    throw new Error('Usage: neoagent channel [stable|beta]');
  }

  writeReleaseChannelToEnvFile(nextChannel, ENV_FILE);
  process.env.NEOAGENT_RELEASE_CHANNEL = nextChannel;
  logOk(`Updates now come from the ${releaseChannelSummary(nextChannel)} channel`);
  ui.note(`Get it with ${ui.paint.command('neoagent update')}.`);
}

async function migrateLegacyPackageInstallation(releaseChannel, versionBefore) {
  heading('Migrate legacy package installation');
  for (const command of ['git', 'npm']) {
    const check = runQuiet(command, ['--version']);
    if (check.error || check.status !== 0) {
      throw new Error(
        `${command} is required to migrate this legacy installation. `
        + 'Install Git and Node.js with npm, then rerun `neoagent update`.',
      );
    }
  }

  const sourceDirectory = defaultSourceInstallDirectory();
  const prepared = prepareSourceInstallation({
    run: (command, args, options = {}) => runQuiet(command, args, options),
    releaseChannel,
    sourceDirectory,
    onInfo: (message) => logInfo(message),
  });
  logOk(`Source checkout prepared on ${prepared.targetBranch}`);

  const targetCli = path.join(sourceDirectory, 'bin', 'neoagent.js');
  const adoption = spawnSync(
    process.execPath,
    [targetCli, 'install', '--adopt-existing'],
    {
      cwd: sourceDirectory,
      env: {
        ...process.env,
        NEOAGENT_HOME: RUNTIME_HOME,
      },
      stdio: 'inherit',
    },
  );
  if (adoption.error || adoption.status !== 0) {
    throw new Error(
      `The Git checkout was prepared at ${sourceDirectory}, but the existing `
      + 'service could not be switched to it. No runtime data was removed; '
      + `rerun: ${process.execPath} ${targetCli} install --adopt-existing`,
    );
  }
  logOk(`Migrated ${versionBefore} -> ${prepared.version}`);
  logOk(`Future updates will use the Git checkout at ${sourceDirectory}`);
}

function printChanges(title, changes) {
  if (changes.length === 0) return;
  ui.section(title);
  for (const change of changes) ui.item('info', change);
}

// Puts the code from before the update back and starts it again.
async function rollBackUpdate(updateGit, before) {
  if (!updateGit.restore(before)) throw new Error('The previous version could not be restored.');
  installDependencies();
  buildBundledWebClientIfPossible({ requireFreshBuild: true });
  stopService();
  await waitForServerExit();
  launchService();
  await waitForServerReady(loadEnvPort());
}

async function cmdUpdate(args = [], { onProgress = () => {} } = {}) {
  if (isContainerImage()) {
    throw new Error('This NeoAgent runs from a container image. Update it by pulling the new image: docker compose pull && docker compose up -d');
  }
  migrateLegacyRuntime((msg) => logInfo(msg));
  ensureRuntimeDirs();
  const notesOnly = args.includes('--notes');
  const channelArg = args.find((arg) => !arg.startsWith('--'));
  const requestedChannel = channelArg ? parseReleaseChannel(channelArg) : null;
  if (channelArg && !requestedChannel) {
    throw new Error('Usage: neoagent update [stable|beta] [--notes]');
  }
  const releaseChannel = requestedChannel || currentReleaseChannel();
  if (requestedChannel && !notesOnly) {
    writeReleaseChannelToEnvFile(releaseChannel, ENV_FILE);
    process.env.NEOAGENT_RELEASE_CHANNEL = releaseChannel;
  }
  const versionBefore = readInstalledPackageVersion();
  onProgress({
    progress: 5, phase: 'checking', message: 'Checking the release channel',
    versionBefore, releaseChannel,
  });
  if (!isGitCheckout()) {
    if (notesOnly) throw new Error('Release notes need a Git installation of NeoAgent.');
    onProgress({ progress: 15, phase: 'migrating', message: 'Migrating the legacy installation to a source checkout' });
    await migrateLegacyPackageInstallation(releaseChannel, versionBefore);
    return { message: 'Legacy installation migrated successfully.', versionBefore };
  }

  const updateGit = createUpdateGit(runQuiet);
  if (!updateGit.fetchRemote()) {
    throw new Error("NeoAgent couldn't reach GitHub to look for updates. Check the internet connection and try again.");
  }
  const targetBranch = resolvePreferredGitBranch(releaseChannel);
  const pending = updateGit.pendingUpdate(targetBranch, { allowOlder: Boolean(requestedChannel) });
  const before = updateGit.head();
  if (!pending) {
    ui.blank();
    logOk(`You have the latest version (${versionBefore})`);
    ui.blank();
    return { message: `You have the latest version (${versionBefore})`, versionBefore, versionAfter: versionBefore };
  }
  const versionAfter = pending.version || 'the latest version';
  onProgress({
    progress: 10, phase: 'preparing', message: 'Preparing the update',
    versionAfter: pending.version, targetBranch,
    changelog: updateGit.changesBetween(before.sha, pending.remoteRef),
  });
  if (notesOnly) {
    ui.blank();
    ui.item('warn', ui.paint.bold(`${versionAfter} is ready`), `you have ${versionBefore}`);
    printChanges("What's new", updateGit.changesBetween(before.sha, pending.remoteRef));
    ui.blank();
    ui.note(`Get it with ${ui.paint.command('neoagent update')}.`);
    ui.blank();
    return;
  }

  ui.title(`Updating ${APP_NAME}`, `${versionBefore} → ${versionAfter} · ${releaseChannel}`);
  ui.blank();
  const list = createStepList([
    ['Saving a backup of your settings and chats', 'Saved a backup of your settings and chats'],
    ['Downloading the new version', 'Downloaded the new version'],
    ['Installing it', 'Installed it'],
    ['Restarting NeoAgent', 'Restarted NeoAgent'],
    ['Making sure it all works', 'Made sure it all works'],
  ], { bar: true });
  const phases = ['backup', 'downloading', 'installing', 'restarting', 'verifying'];
  const runUpdateStep = (index, task) => {
    onProgress({ progress: 15 + index * 16, phase: phases[index], message: list.steps[index].doing });
    return list.run(index, task);
  };
  let resumable = 0;
  let codeChanged = false;
  try {
    await runUpdateStep(0, () => backupRuntimeData());
    await runUpdateStep(1, () => {
      codeChanged = true;
      ensureGitBranchForReleaseChannel(targetBranch);
    });
    await runUpdateStep(2, async () => {
      installDependencies();
      buildBundledWebClientIfPossible({ requireFreshBuild: true });
      ensureYtDlpInstalled();
      await ensureComputerRuntime({ required: false, downloadImage: false });
    });
    resumable = await runUpdateStep(3, async () => {
      const count = await stopAndWait();
      launchService();
      return count;
    });
    await runUpdateStep(4, async () => {
      const port = loadEnvPort();
      await waitForServerReady(port);
      const serving = (await fetchLocalHandshake(port))?.serverVersion;
      if (serving && serving !== readInstalledPackageVersion()) {
        throw new Error(`NeoAgent restarted but is still running ${serving}.`);
      }
    });
  } catch (error) {
    if (!codeChanged) {
      closeStepList(list);
      throw error;
    }
    onProgress({ progress: 85, phase: 'rollback', message: `Restoring ${versionBefore} after the update failed` });
    const rollback = list.add([`Going back to ${versionBefore}`, `Went back to ${versionBefore}`]);
    let rollbackError = null;
    try {
      await list.run(rollback, () => rollBackUpdate(updateGit, before));
    } catch (restoreError) {
      rollbackError = restoreError;
    }
    closeStepList(list);
    const failure = new Error(rollbackError
      ? `${error.message}\nGoing back to ${versionBefore} also failed: ${rollbackError.message}`
      : `${error.message}\nNeoAgent is running ${versionBefore} again; nothing was lost.`);
    failure.code = rollbackError ? 'UPDATE_ROLLBACK_FAILED' : 'UPDATE_ROLLED_BACK';
    throw failure;
  }
  closeStepList(list);

  ui.blank();
  ui.item('ok', ui.paint.bold(`${APP_NAME} ${readInstalledPackageVersion()} is ready`), `http://localhost:${loadEnvPort()}`);
  printChanges("What's new", updateGit.changesBetween(before.sha, 'HEAD'));
  ui.blank();
  printResumeNote(resumable, 'now');
  ui.note('Your chats, settings and accounts were kept.');
  ui.blank();
  return {
    message: `NeoAgent ${readInstalledPackageVersion()} is ready. Your chats, settings and accounts were kept.`,
    versionBefore, versionAfter: readInstalledPackageVersion(),
  };
}

async function cmdEnv(args = []) {
  heading('Environment Variables');
  const action = (args[0] || '').trim().toLowerCase();

  if (!action) {
    console.log('Usage: neoagent env <subcommand>');
    ui.blank();
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
    const key = args[1] || await prompt.ask('Key', 'PORT');
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

async function cmdAccount(args = []) {
  if (args[0] !== 'create') {
    throw new Error('Usage: neoagent account create --username <name> --password <password>');
  }
  const options = {};
  for (let i = 1; i < args.length; i += 1) {
    const key = { '--username': 'username', '--password': 'password' }[args[i]];
    if (!key) throw new Error(`Unknown option: ${args[i]}`);
    const value = args[i + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Usage: neoagent account create ${args[i]} <value>`);
    }
    options[key] = value;
    i += 1;
  }
  const { provisionFirstAccount } = require('../server/services/account/provision');
  const account = provisionFirstAccount(options);
  if (cliJsonOutput) {
    process.stdout.write(`${JSON.stringify(account)}\n`);
  } else {
    logOk(`Created account ${account.username}`);
  }
}

// Admin is a flag on a user account, read by the server on every request, so a
// change here applies to a running server immediately.
function cmdAdmin(args = []) {
  const [sub = 'list', username] = args;
  const access = require('../server/services/access/admin');
  if (sub === 'list') {
    const admins = access.listAdmins();
    if (cliJsonOutput) {
      process.stdout.write(`${JSON.stringify({ admins })}\n`);
    } else if (admins.length > 0) {
      for (const admin of admins) logOk(admin.username);
    } else if (access.needsAdminGrant()) {
      logWarn('No account is an admin yet. Run `neoagent admin grant <username>`.');
    } else {
      logInfo('No accounts yet. The first account you create becomes the admin.');
    }
    return;
  }
  if (sub !== 'grant' && sub !== 'revoke') {
    throw new Error('Usage: neoagent admin [list | grant <username> | revoke <username>]');
  }
  if (!username) {
    throw new Error(`Usage: neoagent admin ${sub} <username>`);
  }
  const result = sub === 'grant'
    ? access.grantAdmin(username, { source: 'cli' })
    : access.revokeAdmin(username, { source: 'cli' });
  if (cliJsonOutput) {
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } else if (!result.changed) {
    logInfo(`${result.username} ${sub === 'grant' ? 'is already' : 'is not'} an admin.`);
  } else {
    logOk(`${result.username} ${sub === 'grant' ? 'is now an admin' : 'is no longer an admin'}.`);
  }
}

const EXEC_ACK_FILE = path.join(RUNTIME_HOME, 'exec-acknowledged');

// `exec` runs the agent's shell and file tools directly on this machine, not in
// the cloud VM the server uses. That is the point of the command, but it is
// worth saying out loud once before the first run.
async function confirmLocalExecution(skipPrompt) {
  if (skipPrompt || fs.existsSync(EXEC_ACK_FILE)) return;
  const warning = 'neoagent exec runs commands and edits files directly on this '
    + 'computer, with no virtual machine in between.';
  if (!ui.isInteractive()) {
    throw new Error(`${warning} Re-run with --yes to confirm.`);
  }
  logWarn(warning);
  if (!(await prompt.confirm('Continue and remember this choice?', { initial: false }))) {
    throw prompt.cancelledError();
  }
  fs.writeFileSync(EXEC_ACK_FILE, `${new Date().toISOString()}\n`);
}

function parseExecArguments(args) {
  const options = {
    instruction: null, model: null, provider: null, agent: null, cwd: null, allowAllTools: false, yes: false,
  };
  const flags = { '--model': 'model', '--provider': 'provider', '--agent': 'agent', '--cwd': 'cwd' };
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === '--json') continue;
    if (arg === '--allow-all-tools') {
      options.allowAllTools = true;
      continue;
    }
    if (arg === '--yes' || arg === '-y') {
      options.yes = true;
      continue;
    }
    const key = flags[arg];
    if (key) {
      const value = args[i + 1];
      if (!value || value.startsWith('--')) {
        throw new Error(`Usage: neoagent exec ${arg} <value> "<instruction>"`);
      }
      options[key] = value;
      i += 1;
      continue;
    }
    if (arg.startsWith('--')) {
      throw new Error(`Unknown option: ${arg}. Run "neoagent exec --help" for usage.`);
    }
    if (options.instruction !== null) {
      throw new Error('Usage: neoagent exec [options] "<instruction>"');
    }
    options.instruction = arg;
  }
  return options;
}

async function cmdExec(args = []) {
  const options = parseExecArguments(args);
  if (!options.instruction) {
    throw new Error('Usage: neoagent exec [options] "<instruction>"');
  }

  await confirmLocalExecution(options.yes);

  // Nobody is present to answer an approval prompt, so a headless run either
  // opts out of the approval gate explicitly or blocks on it. Scoped to this
  // process; the stored security mode is left untouched.
  if (options.allowAllTools) {
    process.env.NEOAGENT_TOOL_SECURITY_MODE = 'allow_all';
  }

  const { runHeadlessTask } = require('../server/services/agents/headless');
  const result = await runHeadlessTask({
    instruction: options.instruction,
    model: options.model,
    provider: options.provider,
    agent: options.agent,
    workspaceRoot: options.cwd ? path.resolve(options.cwd) : process.cwd(),
  });

  if (cliJsonOutput) {
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } else if (result?.content) {
    console.log(result.content);
  }
  if (result?.status !== 'completed') {
    throw new Error(`Run ${result?.status || 'failed'}${result?.error ? `: ${result.error}` : ''}`);
  }
}

async function runCLI(argv) {
  cliJsonOutput = argv.includes('--json');
  ui.configure({ silent: cliJsonOutput });
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
      await cmdInstall(argv.slice(1));
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
      await cmdRestart();
      break;
    case 'rebuild-web':
      await cmdRebuildWeb();
      break;
    case 'start':
      await cmdStart();
      break;
    case 'stop':
      await cmdStop();
      break;
    case 'status':
      await cmdStatus(argv.slice(1));
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
      await cmdUninstall();
      break;
    case 'migrate':
      await cmdMigrate(argv.slice(1));
      break;
    case 'login':
      await cmdLogin(argv.slice(1));
      break;
    case 'admin':
      cmdAdmin(argv.slice(1));
      break;
    case 'account':
      await cmdAccount(argv.slice(1));
      break;
    case 'exec':
      await cmdExec(argv.slice(1));
      break;
    case 'version':
    case '--version':
    case '-V':
      cmdVersion();
      break;
    case 'help':
    case '--help':
    case '-h':
      printHelp({ all: argv.includes('--all') });
      break;
    default:
      throw new Error(`"${command}" isn't a neoagent command. Run \`neoagent help\` to see what you can do.`);
  }
}

module.exports = {
  cmdUpdate,
  releasePortForSetup,
  runCLI,
  scanForInstalledInstance,
};
