#!/usr/bin/env node

const path = require('path');
const { spawnSync } = require('child_process');
const {
  buildBundledWebClientIfPossible: buildWebClient,
  commandExists: sharedCommandExists,
  hasBundledWebClient,
  withInstallEnv,
} = require('../lib/install_helpers');
const {
  APP_DIR,
  UPDATE_STATUS_FILE: STATUS_FILE,
  migrateLegacyRuntime,
  ensureRuntimeDirs
} = require('../runtime/paths');
const {
  getReleaseChannelBranch,
  getReleaseChannelDistTag,
  getReleaseChannelLabel,
  readConfiguredReleaseChannel,
  choosePreferredBranchForChannel,
  choosePreferredNpmTagForChannel,
  getReleaseChannelBranchPolicy,
  getReleaseChannelNpmPolicy,
} = require('../runtime/release_channel');
const {
  readUpdateStatus,
  writeUpdateStatusFile: writeStatus,
} = require('../server/utils/update_status');

const MAX_LOG_LINES = 220;
const FLUTTER_APP_DIR = path.join(APP_DIR, 'flutter_app');
const WEB_CLIENT_DIR = path.join(APP_DIR, 'server', 'public');

function nowIso() {
  return new Date().toISOString();
}

function appendLog(line) {
  const status = readUpdateStatus(STATUS_FILE);
  const logs = Array.isArray(status.logs) ? status.logs : [];
  logs.push(`[${new Date().toLocaleTimeString('en-US', { hour12: false })}] ${line}`);
  if (logs.length > MAX_LOG_LINES) {
    logs.splice(0, logs.length - MAX_LOG_LINES);
  }
  writeStatus({
    state: status.state,
    progress: status.progress,
    phase: status.phase,
    message: status.message,
    startedAt: status.startedAt,
    completedAt: status.completedAt,
    versionBefore: status.versionBefore,
    versionAfter: status.versionAfter,
    runnerPid: status.runnerPid,
    releaseChannel: status.releaseChannel,
    releaseChannelLabel: status.releaseChannelLabel,
    targetBranch: status.targetBranch,
    npmDistTag: status.npmDistTag,
    changelog: status.changelog,
    logs,
  }, STATUS_FILE);
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
  return sharedCommandExists((command, args) => run(command, args), cmd);
}

function latestGitTagVersion(pattern) {
  const res = run('git', ['tag', '--list', pattern, '--sort=-v:refname']);
  if (res.status !== 0) return null;
  const tag = (res.stdout || '')
    .split('\n')
    .map((value) => value.trim())
    .find(Boolean);
  return tag ? tag.replace(/^v/, '') : null;
}

function gitWorkingTreeDirty() {
  const res = run('git', ['status', '--porcelain']);
  return res.status === 0 && Boolean((res.stdout || '').trim());
}

function gitLocalBranchExists(branch) {
  return run('git', ['show-ref', '--verify', '--quiet', `refs/heads/${branch}`]).status === 0;
}

function gitRemoteBranchExists(branch) {
  return run('git', ['ls-remote', '--exit-code', '--heads', 'origin', branch]).status === 0;
}

function resolvePreferredGitBranch(channel) {
  if (channel === 'stable') {
    return getReleaseChannelBranch(channel);
  }

  const preferred = choosePreferredBranchForChannel(channel, {
    stable: latestGitTagVersion('v[0-9]*.[0-9]*.[0-9]*'),
    beta: latestGitTagVersion('v[0-9]*.[0-9]*.[0-9]*-beta.*'),
  });

  if (preferred === 'beta' && !gitRemoteBranchExists('beta')) {
    return 'main';
  }
  return preferred;
}

function resolvePreferredNpmTag(channel) {
  if (channel === 'stable') {
    return getReleaseChannelDistTag(channel);
  }

  const tagsRes = run('npm', ['view', 'neoagent', 'dist-tags', '--json'], {
    env: withInstallEnv(),
  });
  let distTags = {};
  if (tagsRes.status === 0) {
    try {
      distTags = JSON.parse(tagsRes.stdout || '{}') || {};
    } catch {
      distTags = {};
    }
  }

  return choosePreferredNpmTagForChannel(channel, {
    latest: distTags.latest,
    beta: distTags.beta,
  });
}

function ensureGitBranchForReleaseChannel(targetBranch) {
  const branchRes = run('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  const currentBranch = (branchRes.stdout || '').trim();
  if (currentBranch === targetBranch) {
    return currentBranch;
  }

  if (!gitRemoteBranchExists(targetBranch)) {
    fail(`Release channel branch "${targetBranch}" was not found on origin.`);
  }

  if (gitWorkingTreeDirty()) {
    fail(
      `Cannot switch to ${targetBranch} while the git worktree has local changes. Commit or stash them first, then retry the update.`,
    );
  }

  const checkout = gitLocalBranchExists(targetBranch)
    ? run('git', ['checkout', targetBranch])
    : run('git', ['checkout', '-b', targetBranch, '--track', `origin/${targetBranch}`]);

  if (checkout.status !== 0) {
    fail(`git checkout ${targetBranch} failed`);
  }

  appendLog(
    currentBranch
      ? `Switched git branch ${currentBranch} -> ${targetBranch}`
      : `Checked out git branch ${targetBranch}`,
  );
  return targetBranch;
}

function buildBundledWebClientIfPossible({ required = false } = {}) {
  return buildWebClient({
    flutterAppDir: FLUTTER_APP_DIR,
    webClientDir: WEB_CLIENT_DIR,
    runCommand: run,
    commandExistsFn: commandExists,
    onMissingSources: () =>
      appendLog('Flutter app sources not found and no bundled web client was detected.'),
    onUsingBundledClient: () =>
      appendLog('Flutter app sources not found. Keeping existing bundled web client.'),
    onMissingFlutter: () =>
      appendLog('Flutter SDK not found. Keeping existing bundled web client.'),
    onBuildStart: () =>
      info(82, 'building', 'Building bundled Flutter web client'),
    onBuildSuccess: () => appendLog('Bundled Flutter web client updated.'),
    onBuildFailed: () =>
      appendLog('Flutter build failed, but an existing bundled web client is still present.'),
    fail,
    required,
  });
}

function fail(message) {
  writeStatus({
    state: 'failed',
    progress: 100,
    phase: 'failed',
    message,
    completedAt: nowIso(),
    runnerPid: null,
  }, STATUS_FILE);
  appendLog(`FAILED: ${message}`);
  process.exit(1);
}

function info(progress, phase, message) {
  writeStatus({ state: 'running', progress, phase, message, runnerPid: process.pid }, STATUS_FILE);
  appendLog(message);
}

function main() {
  migrateLegacyRuntime();
  ensureRuntimeDirs();
  const startedAt = nowIso();
  const releaseChannel = readConfiguredReleaseChannel();
  writeStatus({
    state: 'running',
    progress: 2,
    phase: 'starting',
    message: 'Preparing update job',
    startedAt,
    completedAt: null,
    releaseChannel,
    releaseChannelLabel: getReleaseChannelLabel(releaseChannel),
    targetBranch: getReleaseChannelBranchPolicy(releaseChannel),
    npmDistTag: getReleaseChannelNpmPolicy(releaseChannel),
    versionBefore: null,
    versionAfter: null,
    runnerPid: process.pid,
    changelog: [],
    logs: []
  }, STATUS_FILE);

  const gitDir = path.join(APP_DIR, '.git');
  const hasGit = fs.existsSync(gitDir) && commandExists('git');

  if (!hasGit) {
    info(20, 'checking', 'No git repository detected. Trying package-based update.');
    if (!commandExists('npm')) {
      fail('Update unavailable: no git repository detected and npm is not installed.');
    }

    const resolvedNpmTag = resolvePreferredNpmTag(releaseChannel);
    writeStatus({ npmDistTag: resolvedNpmTag, runnerPid: process.pid }, STATUS_FILE);
    info(45, 'updating', `Installing NeoAgent from the ${resolvedNpmTag} channel`);
    const npmUpdate = run('npm', ['install', '-g', `neoagent@${resolvedNpmTag}`], {
      env: withInstallEnv()
    });
    if (npmUpdate.status !== 0) {
      fail('npm global update failed');
    }

    if (!hasBundledWebClient(WEB_CLIENT_DIR)) {
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
      completedAt: nowIso(),
      runnerPid: null,
    }, STATUS_FILE);
    return;
  }

  info(8, 'checking', `Preparing ${releaseChannel} channel update`);
  const currentRes = run('git', ['rev-parse', '--short', 'HEAD']);
  const current = (currentRes.stdout || '').trim() || null;
  writeStatus({ versionBefore: current, runnerPid: process.pid }, STATUS_FILE);

  info(20, 'fetching', 'Fetching latest commits and tags from origin');
  const fetch = run('git', ['fetch', 'origin', '--tags']);
  if (fetch.status !== 0) fail('git fetch failed');

  const resolvedBranch = resolvePreferredGitBranch(releaseChannel);
  writeStatus({ targetBranch: resolvedBranch, runnerPid: process.pid }, STATUS_FILE);
  appendLog(`Using git branch ${resolvedBranch} for the ${releaseChannel} channel.`);

  ensureGitBranchForReleaseChannel(resolvedBranch);

  info(35, 'pulling', `Rebasing with origin/${resolvedBranch}`);
  const pull = run('git', ['pull', '--rebase', '--autostash', 'origin', resolvedBranch]);
  if (pull.status !== 0) fail('git pull --rebase failed');

  const nextRes = run('git', ['rev-parse', '--short', 'HEAD']);
  const next = (nextRes.stdout || '').trim() || null;
  writeStatus({ versionAfter: next, runnerPid: process.pid }, STATUS_FILE);

  const changed = current && next && current !== next;

  if (changed) {
    info(55, 'changelog', `Collecting changelog (${current} -> ${next})`);
    const log = run('git', ['log', '--oneline', `${current}..${next}`]);
    const changelog = (log.stdout || '')
      .split('\n')
      .map((v) => v.trim())
      .filter(Boolean)
      .slice(0, 25);
    writeStatus({ changelog, runnerPid: process.pid }, STATUS_FILE);

    info(70, 'dependencies', 'Installing updated dependencies');
    const npmInstall = run('npm', ['install', '--omit=dev', '--no-audit', '--no-fund'], {
      env: withInstallEnv()
    });
    if (npmInstall.status !== 0) fail('Dependency installation failed');
  } else {
    info(68, 'changelog', 'Already up to date. No new commits to apply.');
    writeStatus({ changelog: [], runnerPid: process.pid }, STATUS_FILE);
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
    completedAt: nowIso(),
    runnerPid: null,
  }, STATUS_FILE);
}

try {
  main();
} catch (err) {
  fail(err.message || 'Unexpected update runner error');
}
