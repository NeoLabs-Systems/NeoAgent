'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const {
  choosePreferredBranchForChannel,
  getReleaseChannelBranch,
  parseReleaseChannel,
} = require('../runtime/release_channel');
const { hasBundledWebClient, withInstallEnv } = require('./install_helpers');

const SOURCE_REPOSITORY_URL = 'https://github.com/NeoLabs-Systems/NeoAgent.git';

function defaultSourceInstallDirectory(environment = process.env) {
  const configured = String(environment.NEOAGENT_SOURCE_DIR || '').trim();
  return path.resolve(configured || path.join(os.homedir(), 'NeoAgent'));
}

function normalizeRepositoryRemote(value) {
  let remote = String(value || '').trim();
  if (remote.startsWith('git@github.com:')) {
    remote = `https://github.com/${remote.slice('git@github.com:'.length)}`;
  } else if (remote.startsWith('ssh://git@github.com/')) {
    remote = `https://github.com/${remote.slice('ssh://git@github.com/'.length)}`;
  }
  return remote.replace(/\.git\/?$/i, '').replace(/\/$/, '').toLowerCase();
}

function isCanonicalSourceRemote(value) {
  return normalizeRepositoryRemote(value)
    === normalizeRepositoryRemote(SOURCE_REPOSITORY_URL);
}

function inspectSourceDirectory(sourceDirectory) {
  if (!fs.existsSync(sourceDirectory)) return 'missing';
  if (!fs.statSync(sourceDirectory).isDirectory()) return 'occupied';
  if (fs.existsSync(path.join(sourceDirectory, '.git'))) return 'git';
  return fs.readdirSync(sourceDirectory).length === 0 ? 'empty' : 'occupied';
}

function runChecked(run, command, args, options, failureMessage) {
  const result = run(command, args, options);
  if (result.error || result.status !== 0) {
    const detail = String(result.stderr || result.stdout || result.error?.message || '').trim();
    throw new Error(detail ? `${failureMessage}: ${detail}` : failureMessage);
  }
  return result;
}

function gitOutput(run, sourceDirectory, args) {
  return runChecked(
    run,
    'git',
    args,
    { cwd: sourceDirectory },
    `Git command failed: git ${args.join(' ')}`,
  ).stdout.trim();
}

function latestTag(run, sourceDirectory, pattern, { excludePrerelease = false } = {}) {
  // Globs like v[0-9]*.[0-9]*.[0-9]* also match prerelease tags
  // (v3.4.5-beta.6), so a stable lookup must filter them out explicitly.
  return gitOutput(run, sourceDirectory, [
    'tag',
    '--list',
    pattern,
    '--sort=-v:refname',
  ]).split('\n')
    .map((value) => value.trim())
    .filter(Boolean)
    .find((value) => !excludePrerelease || !value.includes('-')) || null;
}

function remoteBranchExists(run, sourceDirectory, branch) {
  const result = run('git', [
    'ls-remote',
    '--exit-code',
    '--heads',
    'origin',
    `refs/heads/${branch}`,
  ], { cwd: sourceDirectory });
  return result.status === 0;
}

function resolveTargetBranch(run, sourceDirectory, releaseChannel) {
  const channel = parseReleaseChannel(releaseChannel) || 'stable';
  if (channel === 'stable') return getReleaseChannelBranch(channel);
  const preferred = choosePreferredBranchForChannel(channel, {
    stable: latestTag(run, sourceDirectory, 'v[0-9]*.[0-9]*.[0-9]*', { excludePrerelease: true }),
    beta: latestTag(run, sourceDirectory, 'v[0-9]*.[0-9]*.[0-9]*-beta.*'),
  });
  return preferred === 'beta' && !remoteBranchExists(run, sourceDirectory, 'beta')
    ? 'main'
    : preferred;
}

function replaceSourceCheckoutWithRemote({
  run,
  sourceDirectory,
  targetBranch,
  onInfo = () => {},
}) {
  const currentBranch = gitOutput(run, sourceDirectory, [
    'rev-parse',
    '--abbrev-ref',
    'HEAD',
  ]);
  const dirty = gitOutput(run, sourceDirectory, ['status', '--porcelain']);
  if (!remoteBranchExists(run, sourceDirectory, targetBranch)) {
    throw new Error(`Release channel branch "${targetBranch}" was not found on origin.`);
  }
  if (dirty) {
    onInfo(`Discarding local source changes in ${sourceDirectory}`);
  }
  runChecked(
    run,
    'git',
    ['reset', '--hard', 'HEAD'],
    { cwd: sourceDirectory },
    'Could not discard tracked source changes',
  );
  runChecked(
    run,
    'git',
    ['clean', '-fd'],
    { cwd: sourceDirectory },
    'Could not remove untracked source files',
  );
  runChecked(
    run,
    'git',
    ['checkout', '-B', targetBranch, `origin/${targetBranch}`],
    { cwd: sourceDirectory },
    `Could not replace the checkout with origin/${targetBranch}`,
  );
  runChecked(
    run,
    'git',
    ['reset', '--hard', `origin/${targetBranch}`],
    { cwd: sourceDirectory },
    `Could not reset the checkout to origin/${targetBranch}`,
  );
  if (currentBranch && currentBranch !== targetBranch) {
    onInfo(`Switched source branch ${currentBranch} -> ${targetBranch}`);
  }
  return targetBranch;
}

function validateSourceCheckout(sourceDirectory) {
  for (const relativePath of [
    path.join('bin', 'neoagent.js'),
    'package.json',
    'com.neoagent.plist',
  ]) {
    if (!fs.existsSync(path.join(sourceDirectory, relativePath))) {
      throw new Error(`The source checkout is incomplete: missing ${relativePath}.`);
    }
  }
  if (!hasBundledWebClient(path.join(sourceDirectory, 'server', 'public'))) {
    throw new Error('The source checkout does not contain the bundled web client.');
  }
}

function prepareSourceInstallation({
  run,
  releaseChannel,
  sourceDirectory = defaultSourceInstallDirectory(),
  onInfo = () => {},
}) {
  const sourceState = inspectSourceDirectory(sourceDirectory);
  if (sourceState === 'occupied') {
    throw new Error(
      `${sourceDirectory} already exists and is not a NeoAgent Git checkout. `
      + 'Move it or set NEOAGENT_SOURCE_DIR to an empty installation directory, then retry.',
    );
  }

  let createdCheckout = false;
  if (sourceState === 'missing' || sourceState === 'empty') {
    fs.mkdirSync(path.dirname(sourceDirectory), { recursive: true });
    onInfo(`Cloning the NeoAgent source checkout into ${sourceDirectory}`);
    try {
      runChecked(
        run,
        'git',
        ['clone', SOURCE_REPOSITORY_URL, sourceDirectory],
        { cwd: path.dirname(sourceDirectory) },
        'Could not clone the NeoAgent source checkout',
      );
      createdCheckout = true;
    } catch (error) {
      if (!fs.existsSync(path.join(sourceDirectory, '.git'))) {
        fs.rmSync(sourceDirectory, { recursive: true, force: true });
      }
      throw error;
    }
  }

  const origin = gitOutput(run, sourceDirectory, ['remote', 'get-url', 'origin']);
  if (!isCanonicalSourceRemote(origin)) {
    throw new Error(
      `${sourceDirectory} uses an unexpected Git origin (${origin}). `
      + 'Set NEOAGENT_SOURCE_DIR to an empty installation directory, then retry.',
    );
  }
  onInfo('Fetching NeoAgent branches and release tags');
  runChecked(
    run,
    'git',
    ['fetch', 'origin', '--tags'],
    { cwd: sourceDirectory },
    'Could not fetch the NeoAgent source checkout',
  );
  const targetBranch = resolveTargetBranch(run, sourceDirectory, releaseChannel);
  replaceSourceCheckoutWithRemote({
    run,
    sourceDirectory,
    targetBranch,
    onInfo,
  });

  onInfo('Installing source runtime dependencies');
  runChecked(
    run,
    'npm',
    ['install', '--omit=dev', '--no-audit', '--no-fund'],
    { cwd: sourceDirectory, env: withInstallEnv() },
    'Could not install NeoAgent dependencies',
  );
  validateSourceCheckout(sourceDirectory);

  onInfo('Linking the global neoagent command to the source checkout');
  runChecked(
    run,
    'npm',
    ['link', '--ignore-scripts', '--no-audit', '--no-fund'],
    { cwd: sourceDirectory, env: withInstallEnv() },
    'Could not link the global neoagent command',
  );

  const packageJson = JSON.parse(
    fs.readFileSync(path.join(sourceDirectory, 'package.json'), 'utf8'),
  );
  return {
    createdCheckout,
    sourceDirectory,
    targetBranch,
    version: String(packageJson.version || 'unknown'),
  };
}

module.exports = {
  SOURCE_REPOSITORY_URL,
  defaultSourceInstallDirectory,
  inspectSourceDirectory,
  isCanonicalSourceRemote,
  normalizeRepositoryRemote,
  prepareSourceInstallation,
  replaceSourceCheckoutWithRemote,
};
