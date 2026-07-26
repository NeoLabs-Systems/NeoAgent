'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  classifyRecentTarget,
  buildBlockedSenderSuggestions,
  contextFromMessage,
  createDefaultAccessPolicy,
  evaluateAccessPolicy,
  migrateLegacyWhitelist,
  normalizeAccessPolicy,
} = require('../../../server/services/messaging/access_policy');
const { normalizeWhatsAppWhitelist } = require('../../../server/utils/whatsapp');

test('new shared-room policies default to automatic participation', () => {
  const policy = createDefaultAccessPolicy('telegram');
  policy.sharedSpaceRules = [{ scope: 'group', value: '-1001' }];
  const decision = evaluateAccessPolicy(policy, {
    senderId: 'person-1',
    chatId: '-1001',
    groupId: '-1001',
    isDirect: false,
    isShared: true,
    wasMentioned: false,
  }, 'telegram');

  assert.equal(policy.defaultAllowUntaggedInShared, true);
  assert.equal(decision.allowed, true);
  assert.equal(decision.allowUntagged, true);
  assert.equal(decision.participationHint, 'automatic');
});

test('legacy mention requirement becomes a participation hint, not admission', () => {
  const policy = {
    schemaVersion: 2,
    directPolicy: 'allowlist',
    sharedPolicy: 'allowlist',
    requireMentionInShared: true,
    sharedSpaceRules: [{ scope: 'group', value: '-1001' }],
  };
  const decision = evaluateAccessPolicy(policy, {
    senderId: 'person-1',
    chatId: '-1001',
    groupId: '-1001',
    isDirect: false,
    isShared: true,
    wasMentioned: false,
  }, 'telegram');

  assert.equal(decision.allowed, true);
  assert.equal(decision.allowUntagged, false);
  assert.equal(decision.participationHint, 'mention_only');
});

test('untagged participation is configured independently for each group', () => {
  const policy = normalizeAccessPolicy('telegram', {
    schemaVersion: 3,
    sharedPolicy: 'open',
    sharedParticipationRules: [{
      scope: 'group',
      value: '-1001',
      allowUntagged: false,
    }],
  });
  const decide = (groupId) => evaluateAccessPolicy(policy, {
    senderId: 'person-1',
    chatId: groupId,
    groupId,
    isDirect: false,
    isShared: true,
  }, 'telegram');

  assert.equal(decide('-1001').allowUntagged, false);
  assert.equal(decide('-1001').participationHint, 'mention_only');
  assert.equal(decide('-1002').allowUntagged, true);
  assert.equal(decide('-1002').participationHint, 'automatic');
});

test('WhatsApp legacy allowlist keeps group JIDs as shared group rules', () => {
  const policy = migrateLegacyWhitelist('whatsapp', [
    '49123456789@s.whatsapp.net',
    'group:120363123456789012@g.us',
  ]);

  assert.deepEqual(policy.directRules, [{
    scope: 'phone_number',
    value: '49123456789',
  }]);
  assert.deepEqual(policy.sharedActorRules, [{
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

test('WhatsApp sender rules allow that sender in DMs and groups', () => {
  const policy = migrateLegacyWhitelist('whatsapp', [
    '49123456789@s.whatsapp.net',
  ]);

  const groupDecision = evaluateAccessPolicy(policy, contextFromMessage({
    platform: 'whatsapp',
    chatId: '120363123456789012@g.us',
    sender: '49123456789@s.whatsapp.net',
    isGroup: true,
  }), 'whatsapp');
  const directDecision = evaluateAccessPolicy(policy, contextFromMessage({
    platform: 'whatsapp',
    chatId: '49123456789@s.whatsapp.net',
    sender: '49123456789@s.whatsapp.net',
    isGroup: false,
  }), 'whatsapp');

  assert.equal(groupDecision.allowed, true);
  assert.equal(directDecision.allowed, true);
});

test('WhatsApp group-specific sender rules do not leak to other senders, groups, or DMs', () => {
  const groupId = '120363123456789012@g.us';
  const policy = normalizeAccessPolicy('whatsapp', {
    directPolicy: 'allowlist',
    sharedPolicy: 'allowlist',
    sharedMemberRules: [{
      scope: 'phone_number',
      value: '49123456789',
      spaceScope: 'group',
      spaceValue: groupId,
    }],
  });

  const decide = ({ chatId = groupId, sender = '49123456789@s.whatsapp.net', isGroup = true } = {}) =>
    evaluateAccessPolicy(policy, contextFromMessage({
      platform: 'whatsapp',
      chatId,
      sender,
      isGroup,
    }), 'whatsapp');

  assert.equal(decide().allowed, true);
  assert.equal(decide({ sender: '49999999999@s.whatsapp.net' }).allowed, false);
  assert.equal(decide({ chatId: '120363999999999999@g.us' }).allowed, false);
  assert.equal(decide({
    chatId: '49123456789@s.whatsapp.net',
    isGroup: false,
  }).allowed, false);
});

test('adding group access never removes an existing explicit DM rule', () => {
  const groupId = '120363123456789012@g.us';
  const directRule = {
    scope: 'phone_number',
    value: '49123456789',
    label: 'Neo',
  };
  const groupMemberPolicy = normalizeAccessPolicy('whatsapp', {
    schemaVersion: 3,
    directPolicy: 'allowlist',
    sharedPolicy: 'allowlist',
    directRules: [directRule],
    sharedMemberRules: [{
      ...directRule,
      spaceScope: 'group',
      spaceValue: groupId,
    }],
  });
  const everywherePolicy = normalizeAccessPolicy('whatsapp', {
    ...groupMemberPolicy,
    sharedActorRules: [directRule],
  });

  assert.deepEqual(groupMemberPolicy.directRules, [directRule]);
  assert.deepEqual(everywherePolicy.directRules, [directRule]);
  assert.equal(evaluateAccessPolicy(everywherePolicy, contextFromMessage({
    platform: 'whatsapp',
    chatId: '49123456789@s.whatsapp.net',
    sender: '49123456789@s.whatsapp.net',
    isGroup: false,
  }), 'whatsapp').allowed, true);
});

test('WhatsApp group rules allow every sender in only that group', () => {
  const groupId = '120363123456789012@g.us';
  const policy = normalizeAccessPolicy('whatsapp', {
    sharedPolicy: 'allowlist',
    sharedSpaceRules: [{ scope: 'group', value: groupId }],
  });

  for (const sender of [
    '49123456789@s.whatsapp.net',
    '49999999999@s.whatsapp.net',
  ]) {
    const decision = evaluateAccessPolicy(policy, contextFromMessage({
      platform: 'whatsapp',
      chatId: groupId,
      sender,
      isGroup: true,
    }), 'whatsapp');
    assert.equal(decision.allowed, true);
  }

  const otherGroupDecision = evaluateAccessPolicy(policy, contextFromMessage({
    platform: 'whatsapp',
    chatId: '120363999999999999@g.us',
    sender: '49123456789@s.whatsapp.net',
    isGroup: true,
  }), 'whatsapp');
  assert.equal(otherGroupDecision.allowed, false);
});

test('pre-v2 room and sender filters migrate to group-specific sender grants', () => {
  const groupId = '120363123456789012@g.us';
  const policy = normalizeAccessPolicy('whatsapp', {
    sharedPolicy: 'allowlist',
    sharedSpaceRules: [{ scope: 'group', value: groupId, label: 'Ops' }],
    sharedActorRules: [{ scope: 'phone_number', value: '49123456789' }],
  });

  assert.equal(policy.schemaVersion, 3);
  assert.deepEqual(policy.sharedSpaceRules, []);
  assert.deepEqual(policy.sharedActorRules, []);
  assert.deepEqual(policy.sharedMemberRules, [{
    scope: 'phone_number',
    value: '49123456789',
    spaceScope: 'group',
    spaceValue: groupId,
    spaceLabel: 'Ops',
  }]);
});

test('pre-v2 open shared policies with actor filters stay limited to those actors', () => {
  const policy = normalizeAccessPolicy('telegram', {
    directPolicy: 'allowlist',
    sharedPolicy: 'open',
    sharedActorRules: [{ scope: 'user', value: 'person-1' }],
  });

  assert.equal(policy.sharedPolicy, 'allowlist');
  assert.equal(evaluateAccessPolicy(policy, {
    senderId: 'person-1',
    chatId: '-1001',
    groupId: '-1001',
    isDirect: false,
    isShared: true,
  }, 'telegram').allowed, true);
  assert.equal(evaluateAccessPolicy(policy, {
    senderId: 'person-2',
    chatId: '-1001',
    groupId: '-1001',
    isDirect: false,
    isShared: true,
  }, 'telegram').allowed, false);
});

test('numeric Telegram sender IDs remain user rules, not phone-number rules', () => {
  const suggestions = buildBlockedSenderSuggestions('telegram', contextFromMessage({
    platform: 'telegram',
    chatId: '-1001',
    groupId: '-1001',
    sender: '123456789',
    isGroup: true,
  }));

  assert.equal(suggestions.length, 3);
  assert.deepEqual(suggestions.map((item) => item.rule.scope), [
    'user',
    'user',
    'group',
  ]);
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


test('Discord channel allowlist admits tagged messages and preserves untagged policy', () => {
  const policy = migrateLegacyWhitelist('discord', [
    'channel:123456789012345678',
  ]);
  assert.deepEqual(policy.sharedSpaceRules, [{
    scope: 'channel',
    value: '123456789012345678',
  }]);

  const tagged = evaluateAccessPolicy(policy, {
    senderId: 'user-1',
    chatId: '123456789012345678',
    channelId: '123456789012345678',
    isDirect: false,
    isShared: true,
    wasMentioned: true,
  }, 'discord');
  assert.equal(tagged.allowed, true);

  const untagged = evaluateAccessPolicy(policy, {
    senderId: 'user-1',
    chatId: '123456789012345678',
    channelId: '123456789012345678',
    isDirect: false,
    isShared: true,
    wasMentioned: false,
  }, 'discord');
  assert.equal(untagged.allowed, true);
  assert.equal(untagged.allowUntagged, true);
});
