'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  classifyRecentTarget,
  contextFromMessage,
  evaluateAccessPolicy,
  migrateLegacyWhitelist,
} = require('../../../server/services/messaging/access_policy');
const { normalizeWhatsAppWhitelist } = require('../../../server/utils/whatsapp');

test('WhatsApp legacy allowlist keeps group JIDs as shared group rules', () => {
  const policy = migrateLegacyWhitelist('whatsapp', [
    '49123456789@s.whatsapp.net',
    'group:120363123456789012@g.us',
  ]);

  assert.deepEqual(policy.directRules, [{
    scope: 'phone_number',
    value: '49123456789',
  }]);
  assert.deepEqual(policy.sharedSpaceRules, [{
    scope: 'group',
    value: '120363123456789012@g.us',
  }]);

  const decision = evaluateAccessPolicy(policy, contextFromMessage({
    platform: 'whatsapp',
    chatId: '120363123456789012@g.us',
    sender: '49123456789@s.whatsapp.net',
    isGroup: true,
  }), 'whatsapp');

  assert.equal(decision.allowed, true);
});

test('WhatsApp group messages require an allowlisted group in allowlist mode', () => {
  const policy = migrateLegacyWhitelist('whatsapp', [
    '49123456789@s.whatsapp.net',
  ]);

  const decision = evaluateAccessPolicy(policy, contextFromMessage({
    platform: 'whatsapp',
    chatId: '120363123456789012@g.us',
    sender: '49123456789@s.whatsapp.net',
    isGroup: true,
  }), 'whatsapp');

  assert.equal(decision.allowed, false);
  assert.equal(decision.reason, 'shared_space_not_allowed');
});

test('WhatsApp whitelist normalization preserves unprefixed group JIDs', () => {
  assert.deepEqual(normalizeWhatsAppWhitelist([
    '120363123456789012@g.us',
    '49123456789@s.whatsapp.net',
  ]), [
    'group:120363123456789012@g.us',
    '49123456789',
  ]);
});

test('WhatsApp recent group targets are shared group allowlist entries', () => {
  const target = classifyRecentTarget('whatsapp', {
    platform_chat_id: '120363123456789012@g.us',
    sender: '49123456789@s.whatsapp.net',
    metadata: {
      isGroup: true,
      groupName: 'Ops',
    },
  });

  assert.deepEqual(target, {
    source: 'recent',
    bucket: 'sharedSpaceRules',
    scope: 'group',
    value: '120363123456789012@g.us',
    label: 'Ops',
    subtitle: 'Recent WhatsApp group',
  });
});
