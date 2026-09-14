'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { BasePlatform } = require('../../../server/services/messaging/base');

function captureWarnings(t) {
  const lines = [];
  const original = console.warn;
  console.warn = (...args) => lines.push(args.join(' '));
  t.after(() => {
    console.warn = original;
  });
  return lines;
}

const DIRECT_CONTEXT = Object.freeze({
  senderId: '491701234567',
  phoneNumber: '491701234567',
  chatId: '491701234567@s.whatsapp.net',
  isDirect: true,
  isShared: false,
});

test('a refused message says why, so it is not a silent drop', (t) => {
  const warnings = captureWarnings(t);
  const platform = new BasePlatform('whatsapp', {});

  const result = platform._checkInboundAccess(DIRECT_CONTEXT, {
    senderName: 'Friend',
  });

  assert.equal(result.allowed, false);
  assert.equal(result.reason, 'direct_not_allowed');
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /not on the direct-message allowlist/);
  assert.match(warnings[0], /Messaging access/);
});

test('the log identifies the contact without printing the number', (t) => {
  const warnings = captureWarnings(t);
  const platform = new BasePlatform('whatsapp', {});

  platform._checkInboundAccess(DIRECT_CONTEXT, { senderName: 'Friend' });

  assert.match(warnings[0], /49\*\*\*67/);
  assert.ok(!warnings[0].includes('491701234567'));
});

test('an allowed message is not reported as a problem', (t) => {
  const warnings = captureWarnings(t);
  const platform = new BasePlatform('whatsapp', {
    accessPolicy: {
      schemaVersion: 3,
      directPolicy: 'open',
    },
  });

  const result = platform._checkInboundAccess(DIRECT_CONTEXT, {
    senderName: 'Friend',
  });

  assert.equal(result.allowed, true);
  assert.deepEqual(warnings, []);
});
