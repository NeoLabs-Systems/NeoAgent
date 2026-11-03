const fs = require('fs');
const path = require('path');
const { compareVersions } = require('../runtime/release_channel');

// Kept out of the pubspec: `neoagent update` runs the previous CLI, which builds
// the new sources with whatever Flutter is installed and can't upgrade it first.
const REQUIRED_FLUTTER_VERSION = '3.47.9';

function withInstallEnv(extraEnv = {}) {
  return {
    ...process.env,
    PUPPETEER_SKIP_DOWNLOAD: process.env.PUPPETEER_SKIP_DOWNLOAD || 'true',
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD: process.env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD || '1',
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

function installedFlutterVersion(runCommand) {
  const result = runCommand('flutter', ['--version', '--machine'], { env: withInstallEnv() });
  // First runs can print banners before the JSON.
  const start = String(result.stdout || '').indexOf('{');
  if (result.status !== 0 || start < 0) return null;
  try {
    return JSON.parse(result.stdout.slice(start)).frameworkVersion || null;
  } catch {
    return null;
  }
}

// Upgrades an older Flutter; false when it is still too old. A version that
// can't be read is left for the build to judge.
function ensureRequiredFlutter({ runCommand, onFlutterUpgradeStart }) {
  const installed = installedFlutterVersion(runCommand);
  if (!installed || compareVersions(installed, REQUIRED_FLUTTER_VERSION) >= 0) return true;

  onFlutterUpgradeStart?.(REQUIRED_FLUTTER_VERSION);
  runCommand('flutter', ['upgrade'], { env: withInstallEnv() });
  const upgraded = installedFlutterVersion(runCommand);
  return Boolean(upgraded) && compareVersions(upgraded, REQUIRED_FLUTTER_VERSION) >= 0;
}

function buildBundledWebClientIfPossible({
  flutterAppDir,
  webClientDir,
  runCommand,
  commandExistsFn,
  onMissingSources,
  onUsingBundledClient,
  onMissingFlutter,
  onFlutterUpgradeStart,
  onBuildStart,
  onBuildSuccess,
  onBuildFailed,
  fail,
  required = false,
  requireFreshBuild = false,
  bundledIsCurrent = null,
}) {
  if (!fs.existsSync(flutterAppDir)) {
    if (hasBundledWebClient(webClientDir) && !requireFreshBuild) {
      onUsingBundledClient?.();
      return false;
    }
    if (required || requireFreshBuild) {
      fail(`Missing Flutter app sources at ${flutterAppDir}`);
    }
    onMissingSources?.();
    return false;
  }

  if (!commandExistsFn('flutter')) {
    // Without Flutter a fresh build is impossible; the bundled client still
    // counts when it was built from the current app sources.
    if (hasBundledWebClient(webClientDir) && (!requireFreshBuild || bundledIsCurrent?.())) {
      onMissingFlutter?.();
      return false;
    }
    fail(
      requireFreshBuild
        ? 'Flutter SDK is required to rebuild the web client: the bundled copy is older than the app sources. Install Flutter (https://docs.flutter.dev/get-started/install) or wait a few minutes for the rebuilt client and update again.'
        : 'Flutter SDK is required to build the web client because no bundled client was found.',
    );
  }

  if (!ensureRequiredFlutter({ runCommand, onFlutterUpgradeStart })) {
    if (hasBundledWebClient(webClientDir) && (!requireFreshBuild || bundledIsCurrent?.())) {
      onMissingFlutter?.();
      return false;
    }
    fail(`Flutter could not be updated to ${REQUIRED_FLUTTER_VERSION}, which the web client needs. Run \`flutter upgrade\` and try again.`);
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
      '--no-wasm-dry-run',
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
    if (hasBundledWebClient(webClientDir) && !requireFreshBuild) {
      onBuildFailed?.();
      return false;
    }
    fail(
      requireFreshBuild
        ? 'Flutter web build failed. This command requires a successful rebuild and will not fall back to a stale bundled copy.'
        : 'Flutter web build failed and no bundled web client is available.',
    );
  }

  onBuildSuccess?.();
  return true;
}

module.exports = {
  REQUIRED_FLUTTER_VERSION,
  buildBundledWebClientIfPossible,
  commandExists,
  hasBundledWebClient,
  repairPubCacheOwnershipIfNeeded,
  withInstallEnv,
};
