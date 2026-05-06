'use strict';

const { execSync } = require('child_process');

function readGitSha() {
  try {
    return execSync('git rev-parse --short HEAD', {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return 'nogit';
  }
}

const explicit = process.env.NEOAGENT_WEB_BUILD_ID?.trim();
if (explicit) {
  process.stdout.write(explicit);
  process.exit(0);
}

const buildId = `${Date.now().toString(36)}-${readGitSha()}`;
process.stdout.write(buildId);
