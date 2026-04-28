const fs = require('fs');
const path = require('path');

function withInstallEnv(extraEnv = {}) {
  return {
    ...process.env,
    PUPPETEER_SKIP_DOWNLOAD: process.env.PUPPETEER_SKIP_DOWNLOAD || 'true',
    ...extraEnv,
  };
}

function commandExists(runCommand, cmd) {
  const result = runCommand('bash', ['-lc', `command -v ${cmd}`]);
  return result.status === 0;
}

function hasBundledWebClient(webClientDir) {
  return fs.existsSync(path.join(webClientDir, 'index.html'));
}

function repairPubCacheOwnershipIfNeeded(flutterAppDir, runCommand) {
  const repairScript = path.join(path.resolve(flutterAppDir, '..'), 'scripts', 'repair_pub_cache.sh');
  if (!fs.existsSync(repairScript)) {
    return;
  }

  const repair = runCommand('bash', [repairScript], {
    cwd: path.dirname(repairScript),
  });

  if (repair.status !== 0) {
    fail('Failed to repair Flutter pub cache ownership before web rebuild.');
  }
}

function buildBundledWebClientIfPossible({
  flutterAppDir,
  webClientDir,
  runCommand,
  commandExistsFn,
  onMissingSources,
  onUsingBundledClient,
  onMissingFlutter,
  onBuildStart,
  onBuildSuccess,
  onBuildFailed,
  fail,
  required = false,
}) {
  if (!fs.existsSync(flutterAppDir)) {
    if (hasBundledWebClient(webClientDir)) {
      onUsingBundledClient?.();
      return false;
    }
    if (required) {
      fail(`Missing Flutter app sources at ${flutterAppDir}`);
    }
    onMissingSources?.();
    return false;
  }

  if (!commandExistsFn('flutter')) {
    if (hasBundledWebClient(webClientDir)) {
      onMissingFlutter?.();
      return false;
    }
    fail(
      'Flutter SDK is required to build the web client because no bundled client was found.',
    );
  }

  repairPubCacheOwnershipIfNeeded(flutterAppDir, runCommand);

  const pubGet = runCommand(
    'flutter',
    ['pub', 'get'],
    {
      cwd: flutterAppDir,
      env: withInstallEnv(),
    },
  );

  if (pubGet.status !== 0) {
    fail('Flutter pub get failed before web rebuild.');
  }

  onBuildStart?.();
  const build = runCommand(
    'flutter',
    [
      'build',
      'web',
      '--output',
      '../server/public',
      `--dart-define=NEOAGENT_BACKEND_URL=${
        process.env.NEOAGENT_BACKEND_URL || ''
      }`,
    ],
    {
      cwd: flutterAppDir,
      env: withInstallEnv(),
    },
  );

  if (build.status !== 0) {
    if (hasBundledWebClient(webClientDir)) {
      onBuildFailed?.();
      return false;
    }
    fail('Flutter web build failed and no bundled web client is available.');
  }

  onBuildSuccess?.();
  return true;
}

module.exports = {
  buildBundledWebClientIfPossible,
  commandExists,
  hasBundledWebClient,
  repairPubCacheOwnershipIfNeeded,
  withInstallEnv,
};
