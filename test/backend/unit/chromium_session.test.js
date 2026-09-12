'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  CHROMIUM_CDP_PORT,
  chromiumDesktopCommand,
  isChromiumProfileInUse,
  markChromiumSessionClean,
} = require('../../../server/services/browser/chromium_session');

test('desktop Chromium restores the last session without the crash restore dialog', () => {
  const command = chromiumDesktopCommand();
  assert.match(command, /--restore-last-session/);
  assert.match(command, /--hide-crash-restore-bubble/);
  assert.match(command, /--disable-session-crashed-bubble/);
  assert.equal(command.includes(`--remote-debugging-port=${CHROMIUM_CDP_PORT}`), true);
  assert.equal(command.includes('--remote-debugging-address=127.0.0.1'), true);
  assert.equal(command.includes('about:blank'), false);
});

test('a live Chromium singleton lock is not treated as stale', () => {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-chromium-lock-'));
  fs.symlinkSync(`testhost-${process.pid}`, path.join(profileDir, 'SingletonLock'));
  try {
    assert.equal(isChromiumProfileInUse(profileDir), true);
  } finally {
    fs.rmSync(profileDir, { recursive: true, force: true });
  }
});

test('a crashed Chromium profile is marked clean before the next launch', () => {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-chromium-crashed-'));
  const preferencesPath = path.join(profileDir, 'Default', 'Preferences');
  fs.mkdirSync(path.dirname(preferencesPath), { recursive: true });
  fs.writeFileSync(preferencesPath, JSON.stringify({
    profile: { exit_type: 'Crashed', exited_cleanly: false },
    session: { restore_on_startup: 1 },
  }));
  try {
    assert.equal(markChromiumSessionClean(profileDir), true);
    assert.deepEqual(JSON.parse(fs.readFileSync(preferencesPath, 'utf8')).profile, {
      exit_type: 'Normal',
      exited_cleanly: true,
    });
    assert.equal(markChromiumSessionClean(profileDir), false);
  } finally {
    fs.rmSync(profileDir, { recursive: true, force: true });
  }
});

test('a live Chromium profile is not rewritten while the restore dialog could still be owned by the process', () => {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-chromium-live-'));
  const preferencesPath = path.join(profileDir, 'Default', 'Preferences');
  fs.mkdirSync(path.dirname(preferencesPath), { recursive: true });
  fs.writeFileSync(preferencesPath, JSON.stringify({
    profile: { exit_type: 'Crashed', exited_cleanly: false },
  }));
  fs.symlinkSync(`testhost-${process.pid}`, path.join(profileDir, 'SingletonLock'));
  try {
    assert.equal(markChromiumSessionClean(profileDir), false);
    assert.equal(JSON.parse(fs.readFileSync(preferencesPath, 'utf8')).profile.exit_type, 'Crashed');
  } finally {
    fs.rmSync(profileDir, { recursive: true, force: true });
  }
});

test('a missing Chromium singleton lock means the profile is free', () => {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-chromium-free-'));
  try {
    assert.equal(isChromiumProfileInUse(profileDir), false);
  } finally {
    fs.rmSync(profileDir, { recursive: true, force: true });
  }
});
