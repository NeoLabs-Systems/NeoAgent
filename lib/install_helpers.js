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
      env: process.env,
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
  withInstallEnv,
};
