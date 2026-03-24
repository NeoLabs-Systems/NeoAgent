'use strict';

const fs = require('fs');
const path = require('path');
const { ENV_FILE } = require('./paths');

const DEFAULT_RELEASE_CHANNEL = 'stable';
const RELEASE_CHANNEL_ENV_KEY = 'NEOAGENT_RELEASE_CHANNEL';
const RELEASE_CHANNEL_BRANCHES = Object.freeze({
  stable: 'main',
  beta: 'beta',
});
const RELEASE_CHANNEL_DIST_TAGS = Object.freeze({
  stable: 'latest',
  beta: 'beta',
});
const RELEASE_CHANNEL_BRANCH_POLICIES = Object.freeze({
  stable: 'main only',
  beta: 'newest of beta or main',
});
const RELEASE_CHANNEL_NPM_POLICIES = Object.freeze({
  stable: 'latest only',
  beta: 'newest of beta or latest',
});

function parseEnv(raw) {
  const map = new Map();
  for (const line of String(raw || '').split('\n')) {
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const idx = line.indexOf('=');
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1);
    if (key) map.set(key, value);
  }
  return map;
}

function parseReleaseChannel(value) {
  const normalized = String(value || '').trim().toLowerCase();
  switch (normalized) {
    case 'stable':
    case 'normal':
    case 'default':
    case 'latest':
    case 'main':
      return 'stable';
    case 'beta':
    case 'preview':
    case 'prerelease':
    case 'pre-release':
      return 'beta';
    default:
      return null;
  }
}

function normalizeReleaseChannel(value) {
  return parseReleaseChannel(value) || DEFAULT_RELEASE_CHANNEL;
}

function getReleaseChannelBranch(channel) {
  return RELEASE_CHANNEL_BRANCHES[normalizeReleaseChannel(channel)];
}

function getReleaseChannelDistTag(channel) {
  return RELEASE_CHANNEL_DIST_TAGS[normalizeReleaseChannel(channel)];
}

function getReleaseChannelLabel(channel) {
  return normalizeReleaseChannel(channel) === 'beta' ? 'Beta' : 'Stable';
}

function parseSemver(version) {
  const match = String(version || '')
    .trim()
    .replace(/^v/, '')
    .match(/^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/);
  if (!match) {
    return null;
  }

  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
    prerelease: match[4] ? match[4].split('.') : [],
    raw: match[0],
  };
}

function comparePrereleasePart(left, right) {
  const leftNumeric = /^\d+$/.test(left);
  const rightNumeric = /^\d+$/.test(right);

  if (leftNumeric && rightNumeric) {
    return Number(left) - Number(right);
  }
  if (leftNumeric) return -1;
  if (rightNumeric) return 1;
  return left.localeCompare(right);
}

function compareVersions(leftVersion, rightVersion) {
  const left = parseSemver(leftVersion);
  const right = parseSemver(rightVersion);

  if (!left && !right) return 0;
  if (!left) return -1;
  if (!right) return 1;

  for (const key of ['major', 'minor', 'patch']) {
    if (left[key] !== right[key]) {
      return left[key] - right[key];
    }
  }

  const leftPre = left.prerelease;
  const rightPre = right.prerelease;
  if (leftPre.length === 0 && rightPre.length === 0) return 0;
  if (leftPre.length === 0) return 1;
  if (rightPre.length === 0) return -1;

  const length = Math.max(leftPre.length, rightPre.length);
  for (let i = 0; i < length; i++) {
    const leftPart = leftPre[i];
    const rightPart = rightPre[i];
    if (leftPart == null) return -1;
    if (rightPart == null) return 1;
    const diff = comparePrereleasePart(leftPart, rightPart);
    if (diff !== 0) {
      return diff;
    }
  }

  return 0;
}

function maxVersion(leftVersion, rightVersion) {
  return compareVersions(leftVersion, rightVersion) >= 0 ? leftVersion : rightVersion;
}

function describeReleaseChannelPolicy(channel) {
  const normalized = normalizeReleaseChannel(channel);
  return `${getReleaseChannelLabel(normalized)} (git ${RELEASE_CHANNEL_BRANCH_POLICIES[normalized]}, npm ${RELEASE_CHANNEL_NPM_POLICIES[normalized]})`;
}

function getReleaseChannelBranchPolicy(channel) {
  return RELEASE_CHANNEL_BRANCH_POLICIES[normalizeReleaseChannel(channel)];
}

function getReleaseChannelNpmPolicy(channel) {
  return RELEASE_CHANNEL_NPM_POLICIES[normalizeReleaseChannel(channel)];
}

function choosePreferredBranchForChannel(channel, versions = {}) {
  const normalized = normalizeReleaseChannel(channel);
  if (normalized === 'stable') {
    return 'main';
  }

  const stableVersion = versions.stable;
  const betaVersion = versions.beta;
  if (compareVersions(betaVersion, stableVersion) > 0) {
    return 'beta';
  }
  return 'main';
}

function choosePreferredNpmTagForChannel(channel, versions = {}) {
  const normalized = normalizeReleaseChannel(channel);
  if (normalized === 'stable') {
    return 'latest';
  }

  const stableVersion = versions.latest;
  const betaVersion = versions.beta;
  if (compareVersions(betaVersion, stableVersion) > 0) {
    return 'beta';
  }
  return 'latest';
}

function readReleaseChannelFromRaw(raw) {
  const env = parseEnv(raw);
  return normalizeReleaseChannel(env.get(RELEASE_CHANNEL_ENV_KEY));
}

function readReleaseChannelFromEnvFile(envFile = ENV_FILE) {
  try {
    return readReleaseChannelFromRaw(fs.readFileSync(envFile, 'utf8'));
  } catch {
    return DEFAULT_RELEASE_CHANNEL;
  }
}

function readConfiguredReleaseChannel({ env = process.env, envFile = ENV_FILE } = {}) {
  return normalizeReleaseChannel(env[RELEASE_CHANNEL_ENV_KEY] || readReleaseChannelFromEnvFile(envFile));
}

function writeReleaseChannelToEnvFile(channel, envFile = ENV_FILE) {
  const normalized = parseReleaseChannel(channel);
  if (!normalized) {
    throw new Error('Release channel must be "stable" or "beta".');
  }

  const raw = fs.existsSync(envFile) ? fs.readFileSync(envFile, 'utf8') : '';
  const lines = raw ? raw.split('\n') : [];
  let replaced = false;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(`${RELEASE_CHANNEL_ENV_KEY}=`)) {
      lines[i] = `${RELEASE_CHANNEL_ENV_KEY}=${normalized}`;
      replaced = true;
      break;
    }
  }

  if (!replaced) {
    lines.push(`${RELEASE_CHANNEL_ENV_KEY}=${normalized}`);
  }

  const output =
    lines.filter((_, idx, arr) => idx !== arr.length - 1 || arr[idx] !== '').join('\n') + '\n';
  fs.mkdirSync(path.dirname(envFile), { recursive: true });
  fs.writeFileSync(envFile, output, { mode: 0o600 });
  return normalized;
}

module.exports = {
  DEFAULT_RELEASE_CHANNEL,
  RELEASE_CHANNEL_ENV_KEY,
  parseReleaseChannel,
  normalizeReleaseChannel,
  getReleaseChannelBranch,
  getReleaseChannelDistTag,
  getReleaseChannelLabel,
  parseSemver,
  compareVersions,
  maxVersion,
  describeReleaseChannelPolicy,
  getReleaseChannelBranchPolicy,
  getReleaseChannelNpmPolicy,
  choosePreferredBranchForChannel,
  choosePreferredNpmTagForChannel,
  readReleaseChannelFromRaw,
  readReleaseChannelFromEnvFile,
  readConfiguredReleaseChannel,
  writeReleaseChannelToEnvFile,
};
