'use strict';

const { execSync } = require('child_process');
const { APP_DIR } = require('../../runtime/paths');
const packageJson = require('../../package.json');

function getVersionInfo() {
  let version = packageJson.version;
  let gitSha = null;

  try {
    version =
      execSync('git describe --tags --always --dirty', {
        cwd: APP_DIR,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore']
      })
        .trim()
        .replace(/^v/, '') || packageJson.version;
    gitSha = execSync('git rev-parse --short HEAD', {
      cwd: APP_DIR,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
  } catch {
    gitSha = process.env.GIT_SHA || null;
  }

  return {
    name: packageJson.name,
    version,
    packageVersion: packageJson.version,
    gitSha
  };
}

module.exports = { getVersionInfo };
