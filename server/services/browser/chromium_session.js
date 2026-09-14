'use strict';

const fs = require('fs');
const path = require('path');

const CHROMIUM_CDP_PORT = 9222;
const CHROMIUM_CDP_ENDPOINT = `http://127.0.0.1:${CHROMIUM_CDP_PORT}`;
const GUEST_CHROMIUM_USER_DATA_DIR = '/home/neo/.neoagent/data/browser-profiles/default';

function chromiumDesktopArgs(userDataDir = GUEST_CHROMIUM_USER_DATA_DIR) {
  return [
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--restore-last-session',
    '--hide-crash-restore-bubble',
    '--disable-session-crashed-bubble',
    '--remote-debugging-address=127.0.0.1',
    `--remote-debugging-port=${CHROMIUM_CDP_PORT}`,
    '--remote-allow-origins=*',
  ];
}

function chromiumDesktopCommand(binary = 'chromium') {
  return [binary, ...chromiumDesktopArgs()].join(' ');
}

function readJsonObject(filePath) {
  try {
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    return parsed;
  } catch {
    return null;
  }
}

function withCleanSessionExit(preferences) {
  const profile = preferences.profile && typeof preferences.profile === 'object'
    ? preferences.profile
    : {};
  if (profile.exit_type === 'Normal' && profile.exited_cleanly === true) return null;
  return {
    ...preferences,
    profile: {
      ...profile,
      exit_type: 'Normal',
      exited_cleanly: true,
    },
  };
}

function markChromiumSessionClean(profileDir) {
  if (isChromiumProfileInUse(profileDir)) return false;
  const candidates = [
    path.join(String(profileDir || ''), 'Default', 'Preferences'),
    path.join(String(profileDir || ''), 'Preferences'),
  ];
  let updated = false;
  for (const filePath of candidates) {
    if (!fs.existsSync(filePath)) continue;
    const parsed = readJsonObject(filePath);
    if (!parsed) continue;
    const next = withCleanSessionExit(parsed);
    if (!next) continue;
    fs.writeFileSync(filePath, JSON.stringify(next));
    updated = true;
  }
  return updated;
}

function isChromiumProfileInUse(profileDir) {
  const lockPath = path.join(String(profileDir || ''), 'SingletonLock');
  let target = '';
  try {
    target = fs.readlinkSync(lockPath);
  } catch (error) {
    if (error?.code === 'ENOENT') return false;
    return fs.existsSync(lockPath);
  }
  const pid = Number(String(target).split('-').pop());
  if (!Number.isInteger(pid) || pid <= 0) return true;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

module.exports = {
  CHROMIUM_CDP_ENDPOINT,
  CHROMIUM_CDP_PORT,
  GUEST_CHROMIUM_USER_DATA_DIR,
  chromiumDesktopArgs,
  chromiumDesktopCommand,
  isChromiumProfileInUse,
  markChromiumSessionClean,
};
