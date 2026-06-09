'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { APP_DIR } = require('../../runtime/paths');
const {
  readConfiguredReleaseChannel,
  getReleaseChannelBranchPolicy,
  getReleaseChannelNpmPolicy,
} = require('../../runtime/release_channel');
const { getDeploymentInfo } = require('./deployment');

const PACKAGE_JSON_PATH = path.join(APP_DIR, 'package.json');
const GIT_COMMAND_TIMEOUT_MS = 750;
const VERSION_CACHE_TTL_MS = 30 * 1000;

let cachedVersionInfo = null;
let cachedVersionInfoAt = 0;

function readPackageVersion() {
  try {
    const pkg = JSON.parse(fs.readFileSync(PACKAGE_JSON_PATH, 'utf8'));
    return pkg.version || null;
  } catch {
    return null;
  }
}

function readGitValue(command) {
  return execSync(command, {
    cwd: APP_DIR,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
    timeout: GIT_COMMAND_TIMEOUT_MS,
  }).trim();
}

function buildVersionInfo() {
  const packageVersion = readPackageVersion() || '0.0.0';
  const releaseChannel = readConfiguredReleaseChannel();
  const deployment = getDeploymentInfo();
  let version = packageVersion;
  let gitSha = null;
  let gitVersion = null;
  let gitBranch = null;

  try {
    gitVersion = readGitValue('git describe --tags --always --dirty').replace(/^v/, '') || null;
    gitSha = readGitValue('git rev-parse --short HEAD') || null;
    gitBranch = readGitValue('git rev-parse --abbrev-ref HEAD') || null;
  } catch {
    gitSha = process.env.GIT_SHA || null;
  }

  if (gitVersion && gitVersion !== packageVersion) {
    version = `${packageVersion} (${gitVersion})`;
  } else {
    version = packageVersion;
  }

  return {
    name: 'neoagent',
    version,
    packageVersion,
    gitVersion,
    gitBranch,
    gitSha,
    installedVersion: packageVersion,
    releaseChannel,
    targetBranch: getReleaseChannelBranchPolicy(releaseChannel),
    npmDistTag: getReleaseChannelNpmPolicy(releaseChannel),
    deploymentMode: deployment.mode,
    deploymentProfile: deployment.profile,
    managedDeployment: deployment.managed,
    allowSelfUpdate: deployment.allowSelfUpdate,
    runtimeDefaults: deployment.runtimeDefaults,
    allowHostRuntime: deployment.allowHostRuntime,
  };
}

function getVersionInfo() {
  const now = Date.now();
  if (cachedVersionInfo && now - cachedVersionInfoAt < VERSION_CACHE_TTL_MS) {
    return { ...cachedVersionInfo };
  }

  cachedVersionInfo = buildVersionInfo();
  cachedVersionInfoAt = now;
  return { ...cachedVersionInfo };
}

module.exports = { getVersionInfo };
