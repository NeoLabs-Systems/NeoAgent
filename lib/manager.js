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

function backupRuntimeData() {
  const backupsDir = path.join(RUNTIME_HOME, 'backups');
  fs.mkdirSync(backupsDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/:/g, '-').replace(/\.\d{3}Z$/, 'Z');
  const target = path.join(backupsDir, `pre-update-${stamp}`);
  fs.mkdirSync(target, { recursive: true });

  if (fs.existsSync(ENV_FILE)) fs.copyFileSync(ENV_FILE, path.join(target, '.env'));
  if (fs.existsSync(DATA_DIR)) fs.cpSync(DATA_DIR, path.join(target, 'data'), { recursive: true, force: false, errorOnExist: false });
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
    .filter((entry) =>
      entry.pid !== process.pid &&
      /(^|\s)node(\s|$)/.test(entry.command) &&
      (
        appIndexPattern.test(String(entry.command || '').replace(/\\/g, '/')) ||
        genericNeoAgentPattern.test(String(entry.command || '').replace(/\\/g, '/')) ||
        repoNamePattern.test(String(entry.command || ''))
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

  logInfo('Press Enter to keep the current value shown in brackets.');

  heading('Core');
  const port = await ask('Server port', current.PORT || '3333');
  const publicUrl = await ask('Public base URL', current.PUBLIC_URL || '');
  const secureCookiesDefault = current.SECURE_COOKIES ||
    (String(publicUrl || '').trim().startsWith('https://') ? 'true' : 'false');
  const secureCookies = await ask('Secure cookies (true/false)', secureCookiesDefault);
  const trustProxyDefault = current.TRUST_PROXY || secureCookiesDefault;
  const trustProxy = await ask('Trust reverse proxy headers (true/false)', trustProxyDefault);
  const sessionSecret = await askSecret('Session secret', current.SESSION_SECRET || randomSecret());
  const deploymentMode = await ask(
    'Deployment mode (self_hosted/managed)',
    current.NEOAGENT_DEPLOYMENT_MODE || 'self_hosted'
  );
  const releaseChannel = await ask(
    'Release channel (stable/beta)',
    current.NEOAGENT_RELEASE_CHANNEL || 'stable'
  );
  const origins = await ask('Allowed CORS origins', current.ALLOWED_ORIGINS || '');

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

  const lines = [
    `NODE_ENV=production`,
    `PORT=${port}`,
    publicUrl ? `PUBLIC_URL=${publicUrl}` : '',
    `SECURE_COOKIES=${normalizedSecureCookies}`,
    `TRUST_PROXY=${normalizedTrustProxy}`,
    `SESSION_SECRET=${sessionSecret}`,
    `NEOAGENT_DEPLOYMENT_MODE=${normalizedDeploymentMode}`,
    `NEOAGENT_RELEASE_CHANNEL=${normalizedReleaseChannel}`,
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

async function cmdLogin(args = []) {
  const provider = args[0];
  if (provider !== 'github-copilot' && provider !== 'openai-codex') {
    throw new Error(`Unsupported login provider: ${provider || 'none'}. Available: github-copilot, openai-codex`);
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

    if (!reqRes.ok) {
      throw new Error(`Failed to request device code: HTTP ${reqRes.status}`);
    }

    const { device_code, user_code, verification_uri, interval } = await reqRes.json();

    console.log(`\n  ${COLORS.cyan}Please visit:${COLORS.reset} ${verification_uri}`);
    console.log(`  ${COLORS.cyan}And enter the code:${COLORS.reset} ${COLORS.bold}${user_code}${COLORS.reset}\n`);
    
    logInfo('Waiting for authorization (timeout in 15m)...');
    const startTime = Date.now();
    const timeoutMs = 15 * 60 * 1000;
    let currentPollInterval = (interval || 5) * 1000;

    while (Date.now() - startTime < timeoutMs) {
      await new Promise((r) => setTimeout(r, currentPollInterval));
      const tokenRes = await fetch('https://github.com/login/oauth/access_token', {
        method: 'POST',
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_id: clientId,
          device_code,
          grant_type: 'urn:ietf:params:oauth:grant-type:device_code'
        })
      });

      if (!tokenRes.ok) {
        const errorText = await tokenRes.text().catch(() => 'Unknown error');
        throw new Error(`GitHub token request failed: HTTP ${tokenRes.status} - ${errorText}`);
      }

      const data = await tokenRes.json();
      if (data.access_token) {
        upsertEnvValue('GITHUB_COPILOT_ACCESS_TOKEN', data.access_token);
        logOk('Successfully authenticated and saved GitHub Copilot access token to .env');
        logInfo('Applying updated provider credentials by restarting NeoAgent...');
        cmdRestart();
        return;
      } else if (data.error === 'authorization_pending') {
        // Continue polling
      } else if (data.error === 'slow_down') {
        currentPollInterval += 5000;
      } else if (data.error) {
        throw new Error(`Authentication failed: ${data.error_description || data.error}`);
      }
    }
    throw new Error('GitHub authentication timed out after 15 minutes.');
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
    console.log(`  ${COLORS.cyan}And enter the code:${COLORS.reset} ${COLORS.bold}${user_code}${COLORS.reset}\n`);

    logInfo('Waiting for authorization (timeout in 15m)...');
    const startTime = Date.now();
    const timeoutMs = 15 * 60 * 1000;
    let currentPollInterval = (interval || 5) * 1000;
    let authorizationCode = null;
    let codeVerifier = null;

    while (Date.now() - startTime < timeoutMs) {
      await new Promise((r) => setTimeout(r, currentPollInterval));
      const tokenRes = await fetch('https://auth.openai.com/api/accounts/deviceauth/token', {
        method: 'POST',
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({
          device_auth_id: device_auth_id,
          user_code: user_code
        })
      });

      if (tokenRes.status === 403 || tokenRes.status === 404) {
        // These statuses are returned by OpenAI while authorization is pending
        continue;
      }

      if (!tokenRes.ok) {
        const errorText = await tokenRes.text().catch(() => 'Unknown error');
        throw new Error(`OpenAI token request failed: HTTP ${tokenRes.status} - ${errorText}`);
      }

      const pollData = await tokenRes.json();
      if (pollData.authorization_code && pollData.code_verifier) {
        authorizationCode = pollData.authorization_code;
        codeVerifier = pollData.code_verifier;
        break;
      } else if (pollData.error === 'authorization_pending') {
        // Continue polling
      } else if (pollData.error === 'slow_down') {
        currentPollInterval += 5000;
      } else if (pollData.error) {
        throw new Error(`Authentication failed: ${pollData.error_description || pollData.error}`);
      }
    }

    if (!authorizationCode || !codeVerifier) {
      throw new Error('OpenAI authentication timed out after 15 minutes.');
    }

    logInfo('Exchanging authorization code for access token...');
    const exchangeRes = await fetch('https://auth.openai.com/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code: authorizationCode,
        redirect_uri: 'https://auth.openai.com/deviceauth/callback',
        client_id: clientId,
        code_verifier: codeVerifier
      })
    });

    if (!exchangeRes.ok) {
      const errorText = await exchangeRes.text().catch(() => 'Unknown error');
      throw new Error(`OpenAI token exchange failed: HTTP ${exchangeRes.status} - ${errorText}`);
    }

    const exchangeData = await exchangeRes.json();
    if (exchangeData.access_token) {
      upsertEnvValue('OPENAI_CODEX_ACCESS_TOKEN', exchangeData.access_token);
      if (exchangeData.refresh_token) {
        upsertEnvValue('OPENAI_CODEX_REFRESH_TOKEN', exchangeData.refresh_token);
      }
      logOk('Successfully authenticated and saved OpenAI Codex tokens to .env');
      logInfo('Applying updated provider credentials by restarting NeoAgent...');
      cmdRestart();
    } else {
      throw new Error('OpenAI token exchange succeeded but did not return an access token.');
    }
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
  const releaseChannel = currentReleaseChannel();

  if (running) {
    logOk(`running on http://localhost:${port}`);
  } else {
    logWarn(`not reachable on port ${port}`);
  }

  console.log(`  install root ${APP_DIR}`);
  console.log(`  version ${currentInstalledVersionLabel()}`);
  console.log(`  release channel ${releaseChannelSummary(releaseChannel)}`);

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
  console.log('Commands: install | setup | env | channel | update | restart | start | stop | status | logs | uninstall | migrate | login');
  console.log('Login usage: neoagent login github-copilot | neoagent login openai-codex');
  console.log('Channel usage: neoagent channel | neoagent channel stable | neoagent channel beta');
  console.log('Update usage: neoagent update | neoagent update stable | neoagent update beta');
  console.log('Env usage: neoagent env list | neoagent env get PORT | neoagent env set PORT 3333 | neoagent env unset PORT');
  console.log('Migrate usage: neoagent migrate | neoagent migrate dry-run | neoagent migrate status');
  console.log('               neoagent migrate openclaw-only | neoagent migrate hermes-only');
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
