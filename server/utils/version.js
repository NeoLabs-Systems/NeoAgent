'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { APP_DIR } = require('../../runtime/paths');
const {
  getReleaseChannelBranch,
  getReleaseChannelDistTag,
  readConfiguredReleaseChannel,
} = require('../../runtime/release_channel');

const PACKAGE_JSON_PATH = path.join(APP_DIR, 'package.json');

function readPackageVersion() {
  try {
    const pkg = JSON.parse(fs.readFileSync(PACKAGE_JSON_PATH, 'utf8'));
    return pkg.version || null;
  } catch {
    return null;
  }
}

function getVersionInfo() {
  const packageVersion = readPackageVersion() || '0.0.0';
  const releaseChannel = readConfiguredReleaseChannel();
  let version = packageVersion;
  let gitSha = null;
  let gitVersion = null;
  let gitBranch = null;

  try {
    gitVersion =
      execSync('git describe --tags --always --dirty', {
        cwd: APP_DIR,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore']
      })
        .trim()
        .replace(/^v/, '') || null;
    gitSha = execSync('git rev-parse --short HEAD', {
      cwd: APP_DIR,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
    gitBranch = execSync('git rev-parse --abbrev-ref HEAD', {
      cwd: APP_DIR,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
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
    targetBranch: getReleaseChannelBranch(releaseChannel),
    npmDistTag: getReleaseChannelDistTag(releaseChannel),
  };
}

module.exports = { getVersionInfo };
