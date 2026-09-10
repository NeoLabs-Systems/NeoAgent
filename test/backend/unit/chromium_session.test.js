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
} = require('../../../server/services/browser/chromium_session');

test('desktop Chromium restores the last session and exposes a local debugger', () => {
  const command = chromiumDesktopCommand();
  assert.match(command, /--restore-last-session/);
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

test('a missing Chromium singleton lock means the profile is free', () => {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-chromium-free-'));
  try {
    assert.equal(isChromiumProfileInUse(profileDir), false);
  } finally {
    fs.rmSync(profileDir, { recursive: true, force: true });
  }
});
