const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createDefaultAccessPolicy,
  migrateLegacyWhitelist,
  normalizeAccessPolicy,
  parseStoredAccessPolicy,
  evaluateAccessPolicy,
} = require('./access_policy');
const { BasePlatform } = require('./base');

test('discord defaults require allowlists and shared mentions', () => {
  const policy = createDefaultAccessPolicy('discord');
  assert.equal(policy.directPolicy, 'allowlist');
  assert.equal(policy.sharedPolicy, 'allowlist');
  assert.equal(policy.requireMentionInShared, true);
});

test('discord legacy whitelist migrates into canonical buckets', () => {
  const policy = migrateLegacyWhitelist('discord', [
    'user:123',
    'guild:456',
    'channel:789',
    'role:999',
  ]);

  assert.deepEqual(
    policy.directRules.map((rule) => `${rule.scope}:${rule.value}`),
    ['user:123'],
  );
  assert.deepEqual(
    policy.sharedSpaceRules.map((rule) => `${rule.scope}:${rule.value}`),
    ['server:456', 'channel:789'],
  );
  assert.deepEqual(
    policy.sharedActorRules.map((rule) => `${rule.scope}:${rule.value}`),
    ['user:123', 'role:999'],
  );
});

test('telegram legacy raw ids split users and groups', () => {
  const policy = migrateLegacyWhitelist('telegram', ['123', '-100555']);
  assert.deepEqual(
    policy.directRules.map((rule) => `${rule.scope}:${rule.value}`),
    ['user:123'],
  );
  assert.deepEqual(
    policy.sharedSpaceRules.map((rule) => `${rule.scope}:${rule.value}`),
    ['group:-100555'],
  );
  assert.deepEqual(
    policy.sharedActorRules.map((rule) => `${rule.scope}:${rule.value}`),
    ['user:123'],
  );
});

test('telnyx legacy numbers become direct phone rules', () => {
  const policy = migrateLegacyWhitelist('telnyx', ['+1 (555) 1200']);
  assert.equal(policy.sharedPolicy, 'disabled');
  assert.deepEqual(policy.directRules, [
    { scope: 'phone_number', value: '+15551200' },
  ]);
});

test('shared access requires both space allowlist and mention when configured', () => {
  const policy = normalizeAccessPolicy('discord', {
    sharedPolicy: 'allowlist',
    requireMentionInShared: true,
    sharedSpaceRules: [{ scope: 'server', value: 'guild-1' }],
    sharedActorRules: [{ scope: 'role', value: 'role-1' }],
  });

  const deniedByMention = evaluateAccessPolicy(policy, {
    senderId: 'user-1',
    chatId: 'chan-1',
    isDirect: false,
    isShared: true,
    groupId: 'chan-1',
    channelId: 'chan-1',
    serverId: 'guild-1',
    roleIds: ['role-1'],
    wasMentioned: false,
  }, 'discord');
  assert.equal(deniedByMention.allowed, false);
  assert.equal(deniedByMention.reason, 'mention_required');

  const allowed = evaluateAccessPolicy(policy, {
    senderId: 'user-1',
    chatId: 'chan-1',
    isDirect: false,
    isShared: true,
    groupId: 'chan-1',
    channelId: 'chan-1',
    serverId: 'guild-1',
    roleIds: ['role-1'],
    wasMentioned: true,
  }, 'discord');
  assert.equal(allowed.allowed, true);
});

test('direct allowlist requires a matching direct rule', () => {
  const policy = normalizeAccessPolicy('telegram', {
    directPolicy: 'allowlist',
    directRules: [{ scope: 'user', value: '42' }],
  });

  assert.equal(
    evaluateAccessPolicy(policy, {
      senderId: '42',
      chatId: 'dm_42',
      isDirect: true,
      isShared: false,
      wasMentioned: false,
    }, 'telegram').allowed,
    true,
  );

  assert.equal(
    evaluateAccessPolicy(policy, {
      senderId: '99',
      chatId: 'dm_99',
      isDirect: true,
      isShared: false,
      wasMentioned: false,
    }, 'telegram').allowed,
    false,
  );
});

test('shared actor role rules gate allowed spaces', () => {
  const policy = normalizeAccessPolicy('discord', {
    sharedPolicy: 'open',
    requireMentionInShared: false,
    sharedActorRules: [{ scope: 'role', value: 'ops' }],
  });

  assert.equal(
    evaluateAccessPolicy(policy, {
      senderId: 'user-1',
      chatId: 'chan',
      isDirect: false,
      isShared: true,
      channelId: 'chan',
      serverId: 'guild',
      roleIds: ['ops'],
      wasMentioned: true,
    }, 'discord').allowed,
    true,
  );

  const denied = evaluateAccessPolicy(policy, {
    senderId: 'user-2',
    chatId: 'chan',
    isDirect: false,
    isShared: true,
    channelId: 'chan',
    serverId: 'guild',
    roleIds: ['guest'],
    wasMentioned: true,
  }, 'discord');
  assert.equal(denied.allowed, false);
  assert.equal(denied.reason, 'shared_actor_not_allowed');
});

test('parseStoredAccessPolicy prefers canonical JSON and falls back to legacy JSON', () => {
  const canonical = parseStoredAccessPolicy(
    'discord',
    JSON.stringify({
      directPolicy: 'open',
      sharedPolicy: 'disabled',
      requireMentionInShared: false,
    }),
    JSON.stringify(['user:123']),
  );
  assert.equal(canonical.directPolicy, 'open');
  assert.equal(canonical.sharedPolicy, 'disabled');

  const legacy = parseStoredAccessPolicy(
    'discord',
    null,
    JSON.stringify(['user:123']),
  );
  assert.deepEqual(
    legacy.directRules.map((rule) => `${rule.scope}:${rule.value}`),
    ['user:123'],
  );
});

test('live platforms can hot-update policy without reconnecting', () => {
  class FakePlatform extends BasePlatform {
    constructor() {
      super('discord', {});
    }
  }

  const platform = new FakePlatform();
  platform.setAccessPolicy({
    directPolicy: 'disabled',
    sharedPolicy: 'disabled',
  });
  assert.equal(
    platform.evaluateAccess({
      senderId: 'user-1',
      chatId: 'dm_user-1',
      isDirect: true,
      isShared: false,
      wasMentioned: false,
    }).allowed,
    false,
  );

  platform.setAccessPolicy({
    directPolicy: 'allowlist',
    directRules: [{ scope: 'user', value: 'user-1' }],
    sharedPolicy: 'disabled',
  });
  assert.equal(
    platform.evaluateAccess({
      senderId: 'user-1',
      chatId: 'dm_user-1',
      isDirect: true,
      isShared: false,
      wasMentioned: false,
    }).allowed,
    true,
  );
});
