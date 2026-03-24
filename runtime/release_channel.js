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
  readReleaseChannelFromRaw,
  readReleaseChannelFromEnvFile,
  readConfiguredReleaseChannel,
  writeReleaseChannelToEnvFile,
};
