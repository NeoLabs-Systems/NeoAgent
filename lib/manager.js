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
  getDefaultVmBaseImageUrl,
  ensureRuntimeDirs,
  migrateLegacyRuntime
} = require('../runtime/paths');
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
  detectSourceAgents,
  cmdMigrateDryRun,
  cmdMigrateRun
} = require('./migrations');

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

function sanitizeEnvKey(key) {
  return String(key).replace(/[\r\n]/g, '');
}

function sanitizeEnvValue(value) {
  return String(value).replace(/[\r\n]/g, '');
}

function validateEnvKey(key) {
  if (!/^[A-Z][A-Z0-9_]*$/.test(key)) {
    throw new Error(`Invalid env key "${key}". Keys must be uppercase letters, digits, and underscores (e.g. PORT, ANTHROPIC_API_KEY).`);
  }
}

function upsertEnvValue(key, value) {
  const safeKey = sanitizeEnvKey(key);
  const safeValue = sanitizeEnvValue(value);
  const raw = readEnvFileRaw();
  const lines = raw ? raw.split('\n') : [];
  let replaced = false;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(`${safeKey}=`)) {
      lines[i] = `${safeKey}=${safeValue}`;
      replaced = true;
      break;
    }
  }

  if (!replaced) lines.push(`${safeKey}=${safeValue}`);
  const output = lines.filter((_, idx, arr) => idx !== arr.length - 1 || arr[idx] !== '').join('\n') + '\n';
  fs.writeFileSync(ENV_FILE, output, { mode: 0o600 });
}

function removeEnvValue(key) {
  const safeKey = sanitizeEnvKey(key);
  const raw = readEnvFileRaw();
  if (!raw) return false;
  const lines = raw.split('\n').filter((line) => !line.startsWith(`${safeKey}=`));
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

function backupRuntimeData() {
  const backupsDir = path.join(RUNTIME_HOME, 'backups');
  fs.mkdirSync(backupsDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/:/g, '-').replace(/\.\d{3}Z$/, 'Z');
  const target = path.join(backupsDir, `pre-update-${stamp}`);
  fs.mkdirSync(target, { recursive: true });

  if (fs.existsSync(ENV_FILE)) fs.copyFileSync(ENV_FILE, path.join(target, '.env'));
  if (fs.existsSync(DATA_DIR)) fs.cpSync(DATA_DIR, path.join(target, 'data'), { recursive: true, force: false, errorOnExist: false });
  pruneOldRuntimeBackups(backupsDir, 3);
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

async function cmdSetup() {
  heading('Environment Setup');
  ensureRuntimeDirs();

  const current = Object.fromEntries(parseEnv(readEnvFileRaw()).entries());
  const defaultVmBaseImageUrl = getDefaultVmBaseImageUrl();

  logInfo('Press Enter to keep the current value shown in brackets.');

  heading('Core');
  const portRaw = await ask('Server port', current.PORT || '3333');
  const portNum = Number(portRaw);
  if (!Number.isInteger(portNum) || portNum < 1 || portNum > 65535) {
    throw new Error(`Invalid port "${portRaw}". Must be an integer between 1 and 65535.`);
  }
  const port = String(portNum);
  const publicUrl = await ask('Public base URL', current.PUBLIC_URL || '');
  const secureCookiesDefault = current.SECURE_COOKIES ||
    (String(publicUrl || '').trim().startsWith('https://') ? 'true' : 'false');
  const secureCookies = await ask('Secure cookies (true/false)', secureCookiesDefault);
  const trustProxyDefault = current.TRUST_PROXY || secureCookiesDefault;
  const trustProxy = await ask('Trust reverse proxy headers (true/false)', trustProxyDefault);
  const sessionSecret = current.SESSION_SECRET || randomSecret();
  const deploymentMode = await ask(
    'Deployment mode (self_hosted/managed)',
    current.NEOAGENT_DEPLOYMENT_MODE || 'self_hosted'
  );
  const releaseChannel = await ask(
    'Release channel (stable/beta)',
    current.NEOAGENT_RELEASE_CHANNEL || 'stable'
  );
  const origins = await ask('Allowed CORS origins', current.ALLOWED_ORIGINS || '');
  const deploymentProfile = current.NEOAGENT_PROFILE || 'prod';
  const vmBaseImageUrl = current.NEOAGENT_VM_BASE_IMAGE_URL || defaultVmBaseImageUrl;
  const vmMemoryMb = current.NEOAGENT_VM_MEMORY_MB || '4096';
  const vmCpus = current.NEOAGENT_VM_CPUS || '2';
  const vmGuestToken = current.NEOAGENT_VM_GUEST_TOKEN || randomSecret();

  heading('AI Providers');
  const anthropic = await askSecret('Anthropic API key', current.ANTHROPIC_API_KEY || '');
  const anthropicBaseUrl = await ask('Anthropic base URL', current.ANTHROPIC_BASE_URL || '');
  const openai = await askSecret('OpenAI API key', current.OPENAI_API_KEY || '');
  const openaiBaseUrl = await ask('OpenAI base URL', current.OPENAI_BASE_URL || '');
  const xai = await askSecret('xAI API key', current.XAI_API_KEY || '');
  const xaiBaseUrl = await ask('xAI base URL', current.XAI_BASE_URL || 'https://api.x.ai/v1');
  const google = await askSecret('Google API key', current.GOOGLE_AI_KEY || '');
  const minimax = await askSecret('MiniMax Code key', current.MINIMAX_API_KEY || '');
  const brave = await askSecret('Brave Search API key', current.BRAVE_SEARCH_API_KEY || '');
  const ollama = await ask('Ollama URL', current.OLLAMA_URL || 'http://localhost:11434');

  heading('Official Integrations');
  const googleOauthClientId = await askSecret(
    'Google OAuth client ID',
    current.GOOGLE_OAUTH_CLIENT_ID || ''
  );
  const googleOauthClientSecret = await askSecret(
    'Google OAuth client secret',
    current.GOOGLE_OAUTH_CLIENT_SECRET || ''
  );
  const googleOauthRedirectUri = await ask(
    'Google OAuth redirect URI',
    current.GOOGLE_OAUTH_REDIRECT_URI || ''
  );
  const notionOauthClientId = await askSecret(
    'Notion OAuth client ID',
    current.NOTION_OAUTH_CLIENT_ID || ''
  );
  const notionOauthClientSecret = await askSecret(
    'Notion OAuth client secret',
    current.NOTION_OAUTH_CLIENT_SECRET || ''
  );
  const notionOauthRedirectUri = await ask(
    'Notion OAuth redirect URI',
    current.NOTION_OAUTH_REDIRECT_URI || ''
  );
  const microsoftOauthClientId = await askSecret(
    'Microsoft 365 OAuth client ID',
    current.MICROSOFT_OAUTH_CLIENT_ID || ''
  );
  const microsoftOauthClientSecret = await askSecret(
    'Microsoft 365 OAuth client secret',
    current.MICROSOFT_OAUTH_CLIENT_SECRET || ''
  );
  const microsoftOauthRedirectUri = await ask(
    'Microsoft 365 OAuth redirect URI',
    current.MICROSOFT_OAUTH_REDIRECT_URI || ''
  );
  const microsoftOauthTenantId = await ask(
    'Microsoft 365 OAuth tenant ID',
    current.MICROSOFT_OAUTH_TENANT_ID || 'common'
  );
  const slackOauthClientId = await askSecret(
    'Slack OAuth client ID',
    current.SLACK_OAUTH_CLIENT_ID || ''
  );
  const slackOauthClientSecret = await askSecret(
    'Slack OAuth client secret',
    current.SLACK_OAUTH_CLIENT_SECRET || ''
  );
  const slackOauthRedirectUri = await ask(
    'Slack OAuth redirect URI',
    current.SLACK_OAUTH_REDIRECT_URI || ''
  );
  const figmaOauthClientId = await askSecret(
    'Figma OAuth client ID',
    current.FIGMA_OAUTH_CLIENT_ID || ''
  );
  const figmaOauthClientSecret = await askSecret(
    'Figma OAuth client secret',
    current.FIGMA_OAUTH_CLIENT_SECRET || ''
  );
  const figmaOauthRedirectUri = await ask(
    'Figma OAuth redirect URI',
    current.FIGMA_OAUTH_REDIRECT_URI || ''
  );

  heading('Voice And Recording');
  const deepgramApiKey = await askSecret('Deepgram API key', current.DEEPGRAM_API_KEY || '');
  const deepgramBaseUrl = await ask(
    'Deepgram base URL',
    current.DEEPGRAM_BASE_URL || 'https://api.deepgram.com'
  );
  const deepgramModel = await ask('Deepgram model', current.DEEPGRAM_MODEL || 'nova-3');
  const deepgramLanguage = await ask('Deepgram language', current.DEEPGRAM_LANGUAGE || 'multi');
  const telnyxWebhookToken = await askSecret(
    'Telnyx webhook token',
    current.TELNYX_WEBHOOK_TOKEN || ''
  );
  const normalizedSecureCookies = String(secureCookies || '').trim().toLowerCase() === 'true' ? 'true' : 'false';
  const normalizedTrustProxy = String(trustProxy || '').trim().toLowerCase() === 'true' ? 'true' : 'false';
  const normalizedDeploymentMode = parseDeploymentMode(deploymentMode);
  const normalizedReleaseChannel = parseReleaseChannel(releaseChannel) || 'stable';

  const githubOauthClientId = await askSecret(
    'GitHub OAuth client ID',
    current.GITHUB_OAUTH_CLIENT_ID || ''
  );
  const githubOauthClientSecret = await askSecret(
    'GitHub OAuth client secret',
    current.GITHUB_OAUTH_CLIENT_SECRET || ''
  );
  const githubOauthRedirectUri = await ask(
    'GitHub OAuth redirect URI',
    current.GITHUB_OAUTH_REDIRECT_URI || ''
  );

  const lines = [
    `NODE_ENV=production`,
    `PORT=${port}`,
    publicUrl ? `PUBLIC_URL=${publicUrl}` : '',
    `SECURE_COOKIES=${normalizedSecureCookies}`,
    `TRUST_PROXY=${normalizedTrustProxy}`,
    `SESSION_SECRET=${sessionSecret}`,
    `NEOAGENT_PROFILE=${deploymentProfile}`,
    `NEOAGENT_DEPLOYMENT_MODE=${normalizedDeploymentMode}`,
    `NEOAGENT_RELEASE_CHANNEL=${normalizedReleaseChannel}`,
    `NEOAGENT_VM_BASE_IMAGE_URL=${vmBaseImageUrl}`,
    `NEOAGENT_VM_MEMORY_MB=${vmMemoryMb}`,
    `NEOAGENT_VM_CPUS=${vmCpus}`,
    `NEOAGENT_VM_GUEST_TOKEN=${vmGuestToken}`,
    anthropic ? `ANTHROPIC_API_KEY=${anthropic}` : '',
    anthropicBaseUrl ? `ANTHROPIC_BASE_URL=${anthropicBaseUrl}` : '',
    openai ? `OPENAI_API_KEY=${openai}` : '',
    openaiBaseUrl ? `OPENAI_BASE_URL=${openaiBaseUrl}` : '',
    xai ? `XAI_API_KEY=${xai}` : '',
    xaiBaseUrl ? `XAI_BASE_URL=${xaiBaseUrl}` : '',
    google ? `GOOGLE_AI_KEY=${google}` : '',
    minimax ? `MINIMAX_API_KEY=${minimax}` : '',
    brave ? `BRAVE_SEARCH_API_KEY=${brave}` : '',
    googleOauthClientId ? `GOOGLE_OAUTH_CLIENT_ID=${googleOauthClientId}` : '',
    googleOauthClientSecret ? `GOOGLE_OAUTH_CLIENT_SECRET=${googleOauthClientSecret}` : '',
    googleOauthRedirectUri ? `GOOGLE_OAUTH_REDIRECT_URI=${googleOauthRedirectUri}` : '',
    notionOauthClientId ? `NOTION_OAUTH_CLIENT_ID=${notionOauthClientId}` : '',
    notionOauthClientSecret ? `NOTION_OAUTH_CLIENT_SECRET=${notionOauthClientSecret}` : '',
    notionOauthRedirectUri ? `NOTION_OAUTH_REDIRECT_URI=${notionOauthRedirectUri}` : '',
    microsoftOauthClientId ? `MICROSOFT_OAUTH_CLIENT_ID=${microsoftOauthClientId}` : '',
    microsoftOauthClientSecret ? `MICROSOFT_OAUTH_CLIENT_SECRET=${microsoftOauthClientSecret}` : '',
    microsoftOauthRedirectUri ? `MICROSOFT_OAUTH_REDIRECT_URI=${microsoftOauthRedirectUri}` : '',
    microsoftOauthTenantId ? `MICROSOFT_OAUTH_TENANT_ID=${microsoftOauthTenantId}` : '',
    slackOauthClientId ? `SLACK_OAUTH_CLIENT_ID=${slackOauthClientId}` : '',
    slackOauthClientSecret ? `SLACK_OAUTH_CLIENT_SECRET=${slackOauthClientSecret}` : '',
    slackOauthRedirectUri ? `SLACK_OAUTH_REDIRECT_URI=${slackOauthRedirectUri}` : '',
    figmaOauthClientId ? `FIGMA_OAUTH_CLIENT_ID=${figmaOauthClientId}` : '',
    figmaOauthClientSecret ? `FIGMA_OAUTH_CLIENT_SECRET=${figmaOauthClientSecret}` : '',
    figmaOauthRedirectUri ? `FIGMA_OAUTH_REDIRECT_URI=${figmaOauthRedirectUri}` : '',
    githubOauthClientId ? `GITHUB_OAUTH_CLIENT_ID=${githubOauthClientId}` : '',
    githubOauthClientSecret ? `GITHUB_OAUTH_CLIENT_SECRET=${githubOauthClientSecret}` : '',
    githubOauthRedirectUri ? `GITHUB_OAUTH_REDIRECT_URI=${githubOauthRedirectUri}` : '',
    deepgramApiKey ? `DEEPGRAM_API_KEY=${deepgramApiKey}` : '',
    deepgramBaseUrl ? `DEEPGRAM_BASE_URL=${deepgramBaseUrl}` : '',
    deepgramModel ? `DEEPGRAM_MODEL=${deepgramModel}` : '',
    deepgramLanguage ? `DEEPGRAM_LANGUAGE=${deepgramLanguage}` : '',
    telnyxWebhookToken ? `TELNYX_WEBHOOK_TOKEN=${telnyxWebhookToken}` : '',
    ollama ? `OLLAMA_URL=${ollama}` : '',
    origins ? `ALLOWED_ORIGINS=${origins}` : ''
  ].filter(Boolean);

  fs.writeFileSync(ENV_FILE, `${lines.join('\n')}\n`, { mode: 0o600 });
  logOk(`Wrote ${ENV_FILE}`);
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

async function pollDeviceCode({ pollUrl, pollBody, pollHeaders = {}, intervalMs, timeoutMs, onToken }) {
  const start = Date.now();
  let currentInterval = intervalMs;
  while (Date.now() - start < timeoutMs) {
    await new Promise((r) => setTimeout(r, currentInterval));
    const res = await fetch(pollUrl, {
      method: 'POST',
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', ...pollHeaders },
      body: JSON.stringify(pollBody()),
    });
    if (res.status === 403 || res.status === 404) continue;
    if (!res.ok) {
      const text = await res.text().catch(() => 'Unknown error');
      throw new Error(`Token poll failed: HTTP ${res.status} — ${text}`);
    }
    const data = await res.json();
    const done = await onToken(data);
    if (done) return;
    if (data.error === 'authorization_pending') continue;
    if (data.error === 'slow_down') { currentInterval += 5000; continue; }
    if (data.error) throw new Error(`Authentication failed: ${data.error_description || data.error}`);
  }
  throw new Error('Authentication timed out after 15 minutes.');
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
  const SCOPES = 'user:inference user:profile org:create_api_key user:sessions:claude_code user:mcp_servers';

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
  spawnSync(openCmd, [authUrl.toString()], { stdio: 'ignore' });

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

        if (returnedState && returnedState !== state) {
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
        }
      } catch (err) {
        res.writeHead(500);
        res.end('Internal error');
      }
    });

    server.listen(redirectPort, 'localhost', () => {
      logInfo(`Waiting for OAuth callback on ${redirectUri} ...`);
    });
    server.on('error', (err) => {
      clearTimeout(timeout);
      reject(new Error(`Could not start OAuth callback server: ${err.message}`));
    });
  });

  logInfo('Exchanging authorization code for access token...');
  const tokenRes = await fetch('https://platform.claude.com/v1/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify({
      grant_type: 'authorization_code',
      code: authCode,
      redirect_uri: redirectUri,
      client_id: clientId,
      code_verifier: codeVerifier,
    }),
  });

  if (!tokenRes.ok) {
    const text = await tokenRes.text().catch(() => 'Unknown error');
    throw new Error(`Token exchange failed: HTTP ${tokenRes.status} — ${text}`);
  }

  const tokenData = await tokenRes.json();
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

async function cmdLogin(args = []) {
  const provider = args[0];
  if (provider !== 'github-copilot' && provider !== 'openai-codex' && provider !== 'claude-code') {
    throw new Error(`Unsupported login provider: ${provider || 'none'}. Available: github-copilot, openai-codex, claude-code`);
  }

  if (provider === 'github-copilot') {
    heading('GitHub Copilot Login');
    const clientId = '01ab8ac9400c4e429b23';
    logInfo('Requesting device code from GitHub...');

    const reqRes = await fetch('https://github.com/login/device/code', {
      method: 'POST',
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: clientId, scope: 'user:email' })
    });
    if (!reqRes.ok) throw new Error(`Failed to request device code: HTTP ${reqRes.status}`);

    const { device_code, user_code, verification_uri, interval } = await reqRes.json();
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

    const reqRes = await fetch('https://auth.openai.com/api/accounts/deviceauth/usercode', {
      method: 'POST',
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: clientId, scope: 'openid profile email offline_access model.request model.read model.create' })
    });

    if (!reqRes.ok) {
      throw new Error(`Failed to request device code: HTTP ${reqRes.status}`);
    }

    const data = await reqRes.json();
    const { device_auth_id, interval } = data;
    const user_code = data.user_code || data.usercode;
    const verification_uri = 'https://auth.openai.com/codex/device';

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
    const exchangeRes = await fetch('https://auth.openai.com/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code: authorizationCode,
        redirect_uri: 'https://auth.openai.com/deviceauth/callback',
        client_id: clientId,
        code_verifier: codeVerifier,
      }),
    });

    if (!exchangeRes.ok) {
      const errorText = await exchangeRes.text().catch(() => 'Unknown error');
      throw new Error(`OpenAI token exchange failed: HTTP ${exchangeRes.status} — ${errorText}`);
    }

    const exchangeData = await exchangeRes.json();
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
  }
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
  runOrThrow('systemctl', ['--user', 'is-active', '--quiet', 'neoagent']);
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

async function ensureQemuInstalled() {
  heading('Ensure QEMU Installed');
  const platform = detectPlatform();
  
  const hasSystem = commandExists('qemu-system-x86_64') || commandExists('qemu-system-aarch64');
  const hasImg = commandExists('qemu-img');

  if (hasSystem && hasImg) {
    logOk('QEMU components are already installed');
    return;
  }

  logInfo('QEMU components not found. Attempting to install...');

  if (platform === 'macos') {
    if (!commandExists('brew')) {
      throw new Error('Homebrew is required to install QEMU on macOS. Please install it first: https://brew.sh/');
    }
    logInfo('Running "brew install qemu"...');
    runOrThrow('brew', ['install', 'qemu']);
  } else if (platform === 'linux') {
    const isArm = process.arch === 'arm64' || process.arch === 'aarch64';
    if (commandExists('apt-get')) {
      const pkgs = ['qemu-utils'];
      if (isArm) {
        pkgs.push('qemu-system-arm');
      } else {
        pkgs.push('qemu-system-x86');
      }
      logInfo(`Running "sudo apt-get update && sudo apt-get install -y ${pkgs.join(' ')}"...`);
      runOrThrow('sudo', ['apt-get', 'update']);
      runOrThrow('sudo', ['apt-get', 'install', '-y', ...pkgs]);
    } else if (commandExists('dnf')) {
      logInfo('Running "sudo dnf install -y qemu-kvm qemu-img"...');
      runOrThrow('sudo', ['dnf', 'install', '-y', 'qemu-kvm', 'qemu-img']);
    } else if (commandExists('yum')) {
      logInfo('Running "sudo yum install -y qemu-kvm qemu-img"...');
      runOrThrow('sudo', ['yum', 'install', '-y', 'qemu-kvm', 'qemu-img']);
    } else {
      throw new Error('Unsupported Linux distribution. Please install qemu-system and qemu-utils manually.');
    }
  } else {
    throw new Error('Unsupported platform for automatic QEMU installation. Please install QEMU manually.');
  }

  const verifiedSystem = commandExists('qemu-system-x86_64') || commandExists('qemu-system-aarch64');
  const verifiedImg = commandExists('qemu-img');

  if (verifiedSystem && verifiedImg) {
    logOk('QEMU installed successfully');
  } else {
    throw new Error('QEMU installation failed or components not found in PATH after install.');
  }
}

function ensureYtDlpInstalled() {
  heading('Ensure yt-dlp Installed');
  if (commandExists('yt-dlp')) {
    const ver = runQuiet('yt-dlp', ['--version']);
    logOk(`yt-dlp ${ver.status === 0 ? ver.stdout.trim() : '(version unknown)'}`);
    return;
  }

  logInfo('yt-dlp not found. Attempting to install...');
  const platform = detectPlatform();

  if (platform === 'macos') {
    if (!commandExists('brew')) {
      logWarn('Homebrew not found — skipping yt-dlp install. Install manually: brew install yt-dlp');
      return;
    }
    try {
      runOrThrow('brew', ['install', 'yt-dlp']);
      logOk('yt-dlp installed via Homebrew');
    } catch {
      logWarn('yt-dlp install failed. Install manually: brew install yt-dlp');
    }
    return;
  }

  if (platform === 'linux') {
    if (commandExists('pipx')) {
      try {
        runOrThrow('pipx', ['install', 'yt-dlp']);
        logOk('yt-dlp installed via pipx');
        return;
      } catch {
        // fall through to pip3
      }
    }
    if (commandExists('pip3')) {
      try {
        runOrThrow('pip3', ['install', '--user', 'yt-dlp']);
        logOk('yt-dlp installed via pip3');
        return;
      } catch {
        // fall through to warn
      }
    }
    logWarn('Could not install yt-dlp automatically. Install manually: pipx install yt-dlp');
  }
}

async function cmdInstall() {
  heading(`Install ${APP_NAME}`);
  if (!fs.existsSync(ENV_FILE)) {
    logWarn('.env not found; starting setup');
    await cmdSetup();
  }

  installDependencies();
  await ensureQemuInstalled();
  ensureYtDlpInstalled();
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
    runOrThrow('systemctl', ['--user', 'is-active', '--quiet', 'neoagent']);
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
  const releaseChannel = currentReleaseChannel();
  const platform = detectPlatform();

  if (running) {
    logOk(`server   http://localhost:${port}`);
  } else {
    logWarn(`server   not reachable on port ${port}`);
  }

  if (platform === 'macos' && fs.existsSync(PLIST_DST)) {
    const svcRes = runQuiet('launchctl', ['list', SERVICE_LABEL]);
    if (svcRes.status === 0 && svcRes.stdout.trim()) {
      logOk(`service  launchd (${SERVICE_LABEL})`);
    } else {
      logWarn(`service  launchd unit not loaded — run: neoagent install`);
    }
  } else if (platform === 'linux' && fs.existsSync(SYSTEMD_UNIT)) {
    const svcRes = runQuiet('systemctl', ['--user', 'is-active', 'neoagent']);
    if (svcRes.status === 0 && svcRes.stdout.trim() === 'active') {
      logOk('service  systemd (neoagent)');
    } else {
      logWarn('service  systemd unit not active — run: neoagent install');
    }
  }

  if (fs.existsSync(ENV_FILE)) {
    logOk(`config   ${ENV_FILE}`);
  } else {
    logWarn(`config   .env not found — run: neoagent setup`);
  }

  if (hasBundledWebClient(WEB_CLIENT_DIR)) {
    logOk('web      bundled Flutter client present');
  } else {
    logWarn('web      no bundled client — run: neoagent rebuild-web');
  }

  console.log('');
  console.log(`  install  ${APP_DIR}`);
  console.log(`  version  ${currentInstalledVersionLabel()}`);
  console.log(`  channel  ${releaseChannelSummary(releaseChannel)}`);

  const processes = listNeoAgentServerProcesses();
  if (processes.length > 0) {
    console.log(`  pids     ${processes.map((proc) => proc.pid).join(', ')}`);
    if (processes.length > 1) {
      logWarn(`multiple NeoAgent processes detected (${processes.length})`);
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

function cmdUpdate(args = []) {
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
      buildBundledWebClientIfPossible();
    } else {
      logOk('Already up to date');
      buildBundledWebClientIfPossible();
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

function printHelp() {
  const c = COLORS;
  const W = 38;

  function row(cmd, desc) {
    const padded = `  neoagent ${cmd}`.padEnd(W);
    console.log(`${padded}${c.dim}${desc}${c.reset}`);
  }

  console.log(`\n${c.bold}neoagent${c.reset}  —  manage your NeoAgent server\n`);
  console.log(`${c.bold}Usage${c.reset}  neoagent <command> [args]\n`);

  console.log(`${c.bold}Lifecycle${c.reset}`);
  row('install',              'First-time install and service setup');
  row('start',               'Start the server');
  row('stop',                'Stop the server');
  row('restart',             'Stop, then start');
  row('status',              'Health overview (server, service, config)');
  row('logs',                'Tail server logs');
  row('uninstall',           'Remove the system service');
  console.log('');

  console.log(`${c.bold}Configuration${c.reset}`);
  row('setup',               'Interactive configuration wizard');
  row('env list',            'List all variables (secrets masked)');
  row('env get KEY',         'Print a single variable');
  row('env set KEY VALUE',   'Set a variable');
  row('env unset KEY',       'Remove a variable');
  row('channel',             'Show current release channel');
  row('channel stable|beta', 'Switch release channel');
  console.log('');

  console.log(`${c.bold}Updates & Auth${c.reset}`);
  row('update',              'Update to latest on current channel');
  row('update stable|beta',  'Update and switch channel');
  row('login github-copilot','Authenticate GitHub Copilot');
  row('login openai-codex',  'Authenticate OpenAI Codex');
  row('login claude-code',   'Authenticate Claude Code');
  console.log('');

  console.log(`${c.bold}Maintenance${c.reset}`);
  row('migrate',             'Migrate from another agent installation');
  row('migrate dry-run',     'Preview what would be migrated');
  row('rebuild-web',         'Rebuild the bundled Flutter web client');
  row('version',             'Print installed version');
  console.log('');
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
    case 'channel':
      cmdChannel(argv.slice(1));
      break;
    case 'update':
      cmdUpdate(argv.slice(1));
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
    case 'logs':
      cmdLogs();
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

module.exports = { runCLI };
