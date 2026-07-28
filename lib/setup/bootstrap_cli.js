'use strict';

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const readline = require('readline');
const { spawnSync } = require('child_process');
const AdmZip = require('adm-zip');
const { writeAtomicFile } = require('./atomic_file');
const { SETUP_CONTRACT } = require('./contract');
const { verifyRuntimeManifest } = require('./runtime_manifest');

const GITHUB_OWNER = 'NeoLabs-Systems';
const GITHUB_REPOSITORY = 'NeoAgent';

function runtimeHome(environment = process.env) {
  if (environment.NEOAGENT_HOME) {
    return path.resolve(environment.NEOAGENT_HOME);
  }
  if (process.platform === 'win32') {
    const base = environment.LOCALAPPDATA || environment.APPDATA;
    if (base) return path.join(base, 'NeoAgent');
  }
  return path.join(os.homedir(), '.neoagent');
}

function platformName() {
  const platform = {
    darwin: 'macos',
    win32: 'windows',
    linux: 'linux',
  }[process.platform];
  if (platform && SETUP_CONTRACT.runtimeTargets[platform]) return platform;
  const error = new Error('NeoAgent is not available for this operating system.');
  error.code = 'SETUP_PLATFORM_UNSUPPORTED';
  throw error;
}

function architectureName() {
  const architecture = ['arm64', 'x64'].includes(process.arch)
    ? process.arch
    : null;
  const supported = SETUP_CONTRACT.runtimeTargets[platformName()] || [];
  if (architecture && supported.includes(architecture)) return architecture;
  const error = new Error('NeoAgent is not available for this processor architecture.');
  error.code = 'SETUP_ARCHITECTURE_UNSUPPORTED';
  throw error;
}

function configuredPublicKey() {
  const environmentKey = String(
    process.env.NEOAGENT_RUNTIME_PUBLIC_KEY || '',
  ).trim();
  if (environmentKey) return environmentKey;
  return typeof RUNTIME_SIGNING_PUBLIC_KEY === 'undefined'
    ? ''
    : String(RUNTIME_SIGNING_PUBLIC_KEY).trim();
}

function currentRuntime(root = runtimeHome()) {
  try {
    const marker = JSON.parse(
      fs.readFileSync(path.join(root, 'app', 'current.json'), 'utf8'),
    );
    const version = String(marker.version || '').trim();
    if (!/^[0-9A-Za-z.+_-]+$/.test(version)) return null;
    const directory = path.join(root, 'app', 'versions', version);
    const node = process.platform === 'win32'
      ? path.join(directory, 'node', 'node.exe')
      : path.join(directory, 'node', 'bin', 'node');
    const cli = path.join(directory, 'app', 'bin', 'neoagent.js');
    if (!fs.existsSync(node) || !fs.existsSync(cli)) return null;
    return { version, directory, node, cli };
  } catch {
    return null;
  }
}

function emit(json, state, options = {}) {
  if (json) {
    process.stdout.write(`${JSON.stringify({
      schemaVersion: SETUP_CONTRACT.schemaVersion,
      runId: options.runId,
      profile: options.profile,
      stage: options.stage,
      state,
      ...(Number.isFinite(options.progress)
        ? { progress: options.progress }
        : {}),
      ...(options.message ? { message: options.message } : {}),
      ...(options.error ? { error: options.error } : {}),
    })}\n`);
    return;
  }
  if (options.message) process.stdout.write(`${options.message}\n`);
}

async function fetchBytes(url) {
  const response = await fetch(url, {
    headers: {
      Accept: 'application/vnd.github+json',
      'User-Agent': 'NeoAgent CLI Bootstrap',
    },
    redirect: 'error',
  });
  if (!response.ok) {
    const error = new Error(`Download failed with HTTP ${response.status}.`);
    error.code = 'SETUP_DOWNLOAD_FAILED';
    throw error;
  }
  return Buffer.from(await response.arrayBuffer());
}

function verifyManifest(manifestBytes, signatureText, publicKeyBase64) {
  try {
    if (verifyRuntimeManifest(
      manifestBytes,
      signatureText,
      publicKeyBase64,
    )) {
      return;
    }
    const error = new Error(
      'The NeoAgent runtime manifest did not pass signature verification.',
    );
    error.code = 'SETUP_MANIFEST_SIGNATURE_INVALID';
    throw error;
  } catch (error) {
    if (error.code === 'SETUP_MANIFEST_SIGNATURE_INVALID') throw error;
    const wrapped = new Error(
      'The embedded runtime verification key is invalid.',
    );
    wrapped.code = 'SETUP_TRUST_NOT_CONFIGURED';
    throw wrapped;
  }
}

function selectArtifact(manifest) {
  if (
    Number(manifest?.schemaVersion) !== SETUP_CONTRACT.schemaVersion
    || !Array.isArray(manifest.artifacts)
  ) {
    const error = new Error('The NeoAgent runtime manifest is invalid.');
    error.code = 'SETUP_MANIFEST_INVALID';
    throw error;
  }
  const artifact = manifest.artifacts.find(
    (candidate) => candidate.platform === platformName()
      && candidate.architecture === architectureName(),
  );
  if (!artifact) {
    const error = new Error(
      'No NeoAgent runtime is available for this computer.',
    );
    error.code = 'SETUP_PLATFORM_UNSUPPORTED';
    throw error;
  }
  if (
    !/^[a-f0-9]{64}$/.test(String(artifact.sha256 || ''))
    || !Number.isSafeInteger(Number(artifact.sizeBytes))
    || Number(artifact.sizeBytes) <= 0
  ) {
    const error = new Error('The NeoAgent runtime artifact metadata is invalid.');
    error.code = 'SETUP_MANIFEST_INVALID';
    throw error;
  }
  return artifact;
}

async function resolveRelease(channel = 'stable') {
  const releases = JSON.parse((await fetchBytes(
    `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/releases?per_page=20`,
  )).toString('utf8'));
  for (const release of Array.isArray(releases) ? releases : []) {
    if (release?.draft) continue;
    if (channel !== 'beta' && release?.prerelease) continue;
    const assets = new Map(
      Array.from(release?.assets || [], (asset) => [
        String(asset?.name || ''),
        String(asset?.browser_download_url || ''),
      ]),
    );
    const manifestName = Array.from(assets.keys()).find(
      (name) => name.startsWith('neoagent-runtime-manifest-')
        && name.endsWith('.json'),
    );
    if (!manifestName || !assets.has(`${manifestName}.sig`)) continue;
    return {
      manifestUrl: assets.get(manifestName),
      signatureUrl: assets.get(`${manifestName}.sig`),
      assets,
    };
  }
  const error = new Error(
    `No verified NeoAgent ${channel} runtime is published yet.`,
  );
  error.code = 'SETUP_RUNTIME_NOT_PUBLISHED';
  throw error;
}

function assertSafeArchiveEntry(entryName, destination) {
  const root = path.resolve(destination);
  const target = path.resolve(root, String(entryName || ''));
  if (target !== root && !target.startsWith(`${root}${path.sep}`)) {
    const error = new Error('The runtime archive contains an unsafe path.');
    error.code = 'SETUP_RUNTIME_ARCHIVE_INVALID';
    throw error;
  }
}

function safeExtract(archivePath, destination) {
  const archive = new AdmZip(archivePath);
  for (const entry of archive.getEntries()) {
    assertSafeArchiveEntry(entry.entryName, destination);
  }
  archive.extractAllTo(path.resolve(destination), true);
}

function writeCurrentVersion(root, version) {
  const appDirectory = path.join(root, 'app');
  fs.mkdirSync(appDirectory, { recursive: true, mode: 0o700 });
  const marker = path.join(appDirectory, 'current.json');
  writeAtomicFile(
    marker,
    `${JSON.stringify({
      schemaVersion: SETUP_CONTRACT.schemaVersion,
      version,
      activatedAt: new Date().toISOString(),
    })}\n`,
    { mode: 0o600 },
  );
}

async function installRuntime(options = {}) {
  const root = runtimeHome();
  const release = await resolveRelease(
    String(process.env.NEOAGENT_RELEASE_CHANNEL || '').toLowerCase() === 'beta'
      ? 'beta'
      : 'stable',
  );
  const manifestBytes = await fetchBytes(release.manifestUrl);
  const signature = (await fetchBytes(release.signatureUrl)).toString('utf8');
  verifyManifest(manifestBytes, signature, configuredPublicKey());
  const manifest = JSON.parse(manifestBytes.toString('utf8'));
  const artifact = selectArtifact(manifest);
  const assetUrl = release.assets.get(artifact.assetName);
  if (!assetUrl) {
    const error = new Error('The selected NeoAgent runtime asset is missing.');
    error.code = 'SETUP_RUNTIME_ASSET_MISSING';
    throw error;
  }

  const versions = path.join(root, 'app', 'versions');
  fs.mkdirSync(versions, { recursive: true, mode: 0o700 });
  const staging = fs.mkdtempSync(path.join(versions, '.staging-'));
  const archivePath = path.join(staging, artifact.assetName);
  try {
    const archive = await fetchBytes(assetUrl);
    if (archive.length !== Number(artifact.sizeBytes)) {
      const error = new Error('The NeoAgent runtime download was incomplete.');
      error.code = 'SETUP_DOWNLOAD_INCOMPLETE';
      throw error;
    }
    const digest = crypto.createHash('sha256').update(archive).digest('hex');
    if (digest !== artifact.sha256) {
      const error = new Error(
        'The NeoAgent runtime did not pass checksum verification.',
      );
      error.code = 'SETUP_RUNTIME_HASH_MISMATCH';
      throw error;
    }
    fs.writeFileSync(archivePath, archive, { mode: 0o600 });
    const extracted = path.join(staging, 'extracted');
    fs.mkdirSync(extracted, { recursive: true });
    safeExtract(archivePath, extracted);
    const version = String(manifest.version || '').trim();
    const destination = path.join(versions, version);
    if (!version) {
      const error = new Error('The NeoAgent runtime version is missing.');
      error.code = 'SETUP_MANIFEST_INVALID';
      throw error;
    }
    if (options.force && fs.existsSync(destination)) {
      fs.rmSync(destination, { recursive: true, force: true });
    }
    if (!fs.existsSync(destination)) fs.renameSync(extracted, destination);
    writeCurrentVersion(root, version);
    const installed = currentRuntime(root);
    if (!installed) {
      const error = new Error('The installed NeoAgent runtime is incomplete.');
      error.code = 'SETUP_RUNTIME_INCOMPLETE';
      throw error;
    }
    return installed;
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

function delegate(runtime, args) {
  const result = spawnSync(runtime.node, [runtime.cli, ...args], {
    cwd: path.dirname(path.dirname(runtime.cli)),
    env: {
      ...process.env,
      NEOAGENT_HOME: runtimeHome(),
    },
    stdio: 'inherit',
  });
  if (result.error) throw result.error;
  return Number.isInteger(result.status) ? result.status : 1;
}

async function chooseProfile() {
  if (!process.stdin.isTTY) {
    const error = new Error(
      'Choose --quick or --full when setup runs without an interactive terminal.',
    );
    error.code = 'SETUP_PROFILE_REQUIRED';
    throw error;
  }
  process.stdout.write(
    '\nSet up NeoAgent\n'
      + '  1. Quickstart (recommended) — safe defaults, ready fastest\n'
      + '  2. Full setup — configure every section\n\n',
  );
  const prompt = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  const answer = await new Promise((resolve) => {
    prompt.question('Choose 1 or 2 [1]: ', resolve);
  });
  prompt.close();
  return String(answer).trim() === '2' ? 'full' : 'quick';
}

async function runBootstrap(args = process.argv.slice(2)) {
  const json = args.includes('--json');
  const runId = crypto.randomUUID();
  if (['help', '--help', '-h'].includes(args[0])) {
    process.stdout.write(
      'NeoAgent standalone CLI\n\n'
        + '  neoagent                 Start Quickstart or full setup\n'
        + '  neoagent setup --quick   Install with safe defaults\n'
        + '  neoagent setup --full    Open the complete setup\n'
        + '  neoagent status          Show installation health\n'
        + '  neoagent doctor          Run read-only diagnostics\n'
        + '  neoagent repair          Reinstall verified runtime files\n',
    );
    return 0;
  }
  if (['version', '--version', '-V'].includes(args[0])) {
    const version = typeof BOOTSTRAP_VERSION === 'undefined'
      ? 'development'
      : BOOTSTRAP_VERSION;
    process.stdout.write(`${version}\n`);
    return 0;
  }
  let runtime = currentRuntime();
  const repairRequested = args[0] === 'repair' || args[0] === 'fix';
  const updateRequested = args[0] === 'update';
  if (runtime && updateRequested) {
    const requestedChannel = String(args[1] || '').trim().toLowerCase();
    if (requestedChannel === 'stable' || requestedChannel === 'beta') {
      process.env.NEOAGENT_RELEASE_CHANNEL = requestedChannel;
    }
    const previousRuntime = runtime;
    const updatedRuntime = await installRuntime();
    const status = delegate(updatedRuntime, ['repair', '--runtime-package']);
    if (status === 0) return 0;
    writeCurrentVersion(runtimeHome(), previousRuntime.version);
    delegate(previousRuntime, ['repair', '--runtime-package']);
    return status;
  }
  if (runtime && !repairRequested) return delegate(runtime, args);
  const setupRequested = args.length === 0
    || args[0] === 'install'
    || args[0] === 'setup'
    || repairRequested;
  if (!setupRequested) {
    const error = new Error(
      'NeoAgent is not installed. Run `neoagent` to start setup.',
    );
    error.code = 'SETUP_NOT_INSTALLED';
    throw error;
  }

  let profile = args.includes('--full')
    ? 'full'
    : args.includes('--quick')
      ? 'quick'
      : null;
  if (args.includes('--quick') && args.includes('--full')) {
    const error = new Error('Choose either --quick or --full, not both.');
    error.code = 'SETUP_PROFILE_CONFLICT';
    throw error;
  }
  if (!profile && !repairRequested && !args.includes('--resume')) {
    profile = await chooseProfile();
  }
  profile ||= 'quick';
  emit(json, 'started', {
    runId,
    profile,
    stage: 'download',
    progress: 0.05,
    message: 'Downloading the verified NeoAgent runtime',
  });
  runtime = await installRuntime({ force: repairRequested });
  emit(json, 'completed', {
    runId,
    profile,
    stage: 'download',
    progress: 0.25,
    message: 'Verified NeoAgent runtime installed',
  });
  if (repairRequested) {
    return delegate(runtime, [
      'repair',
      ...args.slice(1),
      ...(args.includes('--runtime-package') ? [] : ['--runtime-package']),
    ]);
  }
  const delegatedArgs = args.length === 0
    ? ['install', `--${profile}`, '--runtime-package']
    : [
        args[0] === 'setup' ? 'install' : args[0],
        ...args.slice(1),
        ...(args.includes('--resume') || args.includes('--quick') || args.includes('--full')
          ? []
          : [`--${profile}`]),
        ...(args.includes('--runtime-package') ? [] : ['--runtime-package']),
      ];
  return delegate(runtime, delegatedArgs);
}

function runMain() {
  runBootstrap().then(
    (status) => {
      process.exitCode = status;
    },
    (error) => {
      const json = process.argv.includes('--json');
      emit(json, 'failed', {
        runId: crypto.randomUUID(),
        profile: process.argv.includes('--full') ? 'full' : 'quick',
        stage: 'prepare',
        message: json ? undefined : `NeoAgent setup failed: ${error.message}`,
        error: {
          code: error.code || 'SETUP_BOOTSTRAP_FAILED',
          retryable: error.code !== 'SETUP_PLATFORM_UNSUPPORTED',
          action: 'retry',
          detail: error.message,
        },
      });
      process.exitCode = 1;
    },
  );
}

if (require.main === module) runMain();

module.exports = {
  architectureName,
  assertSafeArchiveEntry,
  currentRuntime,
  runtimeHome,
  runMain,
  safeExtract,
  selectArtifact,
  verifyManifest,
};
