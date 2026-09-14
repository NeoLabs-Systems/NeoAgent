'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { after, describe, test } = require('node:test');

const {
  GUEST_PAYLOAD_PROFILES,
  stageGuestPayload,
} = require('../../../server/services/runtime/guest_bootstrap');

// Regression coverage: guest_agent.js gained a top-level require on
// server/utils/security.js, which no payload profile staged. Nothing in the
// host test suite exercises the guest payload, so the gap only showed up as a
// crash-looping guest agent after the VM had already booted.
//
// Some requires are deliberately evaluated only when GUEST_PROFILE enables that
// capability, so they are allowed to be absent from profiles that lack it.
const CAPABILITY_MODULES = {
  './services/cli/executor': ['cli', 'browser_cli', 'android'],
  './services/browser/controller': ['browser', 'browser_cli'],
  './services/android/controller': ['android'],
};

function stagedJsFiles(root) {
  const files = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const absolute = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(absolute);
      else if (entry.name.endsWith('.js')) files.push(absolute);
    }
  };
  walk(root);
  return files;
}

function resolvesWithin(root, fromFile, request) {
  const base = path.resolve(path.dirname(fromFile), request);
  return [base, `${base}.js`, path.join(base, 'index.js')].some(
    (candidate) => candidate.startsWith(root) && fs.existsSync(candidate),
  );
}

describe('guest payload dependency closure', () => {
  const stagingRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-payload-'));

  after(() => fs.rmSync(stagingRoot, { recursive: true, force: true }));

  for (const profile of Object.keys(GUEST_PAYLOAD_PROFILES)) {
    test(`the ${profile} payload can resolve every module it loads`, () => {
      const root = stageGuestPayload(path.join(stagingRoot, profile), profile);
      const unresolved = [];

      for (const file of stagedJsFiles(root)) {
        const source = fs.readFileSync(file, 'utf8');
        for (const match of source.matchAll(/require\(\s*'(\.[^']*)'\s*\)/g)) {
          const request = match[1];
          if (resolvesWithin(root, file, request)) continue;
          // A capability module may be absent from a profile that never loads it.
          const enabledFor = CAPABILITY_MODULES[request];
          if (enabledFor && !enabledFor.includes(profile)) continue;
          unresolved.push(`${path.relative(root, file)} -> ${request}`);
        }
      }

      assert.deepEqual(
        unresolved,
        [],
        `${profile} payload is missing modules it requires at load time`,
      );
    });
  }

  test('every profile stages the guest agent and its constant-time comparison', () => {
    for (const profile of Object.keys(GUEST_PAYLOAD_PROFILES)) {
      const targets = GUEST_PAYLOAD_PROFILES[profile].map((entry) => entry.target);
      assert.ok(targets.includes('server/guest_agent.js'), `${profile} stages the guest agent`);
      assert.ok(
        targets.includes('server/utils/security.js'),
        `${profile} stages server/utils/security.js, which guest_agent.js requires at load`,
      );
    }
  });
});
