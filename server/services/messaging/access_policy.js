'use strict';

const ACCESS_MODES = Object.freeze(['allowlist', 'open', 'disabled']);
const ACCESS_POLICY_SCHEMA_VERSION = 3;
const ACCESS_MODE_SET = new Set(ACCESS_MODES);
const RULE_SCOPES = Object.freeze([
  'user',
  'dm',
  'chat',
  'group',
  'channel',
  'server',
  'room',
  'role',
  'phone_number',
]);
const RULE_SCOPE_SET = new Set(RULE_SCOPES);

const DIRECT_RULE_SCOPES = Object.freeze(['user', 'dm', 'chat', 'phone_number']);
const SHARED_SPACE_RULE_SCOPES = Object.freeze(['chat', 'group', 'channel', 'server', 'room']);
const SHARED_ACTOR_RULE_SCOPES = Object.freeze(['user', 'role', 'phone_number']);

const SHARED_RAW_ID_PLATFORMS = new Set([
  'slack',
  'google_chat',
  'teams',
  'matrix',
  'mattermost',
  'irc',
  'twitch',
  'feishu',
  'nextcloud_talk',
  'nostr',
  'synology_chat',
  'tlon',
  'zalo',
  'wechat',
  'webchat',
]);

const DIRECT_ONLY_PHONE_PLATFORMS = new Set(['telnyx']);

function capabilityTemplate(overrides = {}) {
  return Object.freeze({
    supportsDirectPolicy: true,
    supportsSharedPolicy: true,
    supportsMentionGate: false,
    supportsUntaggedGroupToggle: true,
    supportsDiscovery: false,
    directRuleScopes: DIRECT_RULE_SCOPES,
    sharedSpaceRuleScopes: SHARED_SPACE_RULE_SCOPES,
    sharedActorRuleScopes: SHARED_ACTOR_RULE_SCOPES,
    manualEntryHint: 'Add a sender, chat, channel, room, server, or role.',
    ...overrides,
  });
}

const PLATFORM_CAPABILITIES = Object.freeze({
  whatsapp: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: true,
    directRuleScopes: Object.freeze(['phone_number', 'user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['group', 'chat']),
    sharedActorRuleScopes: Object.freeze(['phone_number', 'user']),
    manualEntryHint: 'Add a phone number or WhatsApp group id.',
  }),
  telnyx: capabilityTemplate({
    supportsSharedPolicy: false,
    supportsMentionGate: false,
    supportsUntaggedGroupToggle: false,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['phone_number']),
    sharedSpaceRuleScopes: Object.freeze([]),
    sharedActorRuleScopes: Object.freeze([]),
    manualEntryHint: 'Add a caller phone number.',
  }),
  discord: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: true,
    directRuleScopes: Object.freeze(['user', 'dm']),
    sharedSpaceRuleScopes: Object.freeze(['channel', 'server']),
    sharedActorRuleScopes: Object.freeze(['user', 'role']),
    manualEntryHint: 'Add a user, channel, server, or role id.',
  }),
  telegram: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: true,
    directRuleScopes: Object.freeze(['user', 'dm']),
    sharedSpaceRuleScopes: Object.freeze(['group', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
    manualEntryHint: 'Add a Telegram user or group chat id.',
  }),
  slack: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['channel', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
    manualEntryHint: 'Add a Slack user or channel id.',
  }),
  google_chat: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['room', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  teams: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['channel', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  matrix: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['room', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  signal: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['phone_number', 'user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['group', 'chat']),
    sharedActorRuleScopes: Object.freeze(['phone_number', 'user']),
  }),
  imessage: capabilityTemplate({
    supportsMentionGate: false,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  bluebubbles: capabilityTemplate({
    supportsMentionGate: false,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  irc: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['channel', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  twitch: capabilityTemplate({
    supportsMentionGate: true,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['channel', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  line: capabilityTemplate({
    supportsMentionGate: false,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['group', 'room', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  mattermost: capabilityTemplate({
    supportsMentionGate: false,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['channel', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
  }),
  meshtastic: capabilityTemplate({
    supportsDirectPolicy: false,
    supportsSharedPolicy: true,
    supportsMentionGate: false,
    supportsDiscovery: false,
    directRuleScopes: Object.freeze([]),
    sharedSpaceRuleScopes: Object.freeze(['channel', 'chat']),
    sharedActorRuleScopes: Object.freeze(['user']),
    manualEntryHint: 'Add a Meshtastic node number or channel id.',
  }),
  feishu: capabilityTemplate({ supportsDiscovery: false }),
  nextcloud_talk: capabilityTemplate({ supportsDiscovery: false }),
  nostr: capabilityTemplate({ supportsDiscovery: false }),
  synology_chat: capabilityTemplate({ supportsDiscovery: false }),
  tlon: capabilityTemplate({ supportsDiscovery: false }),
  zalo: capabilityTemplate({ supportsDiscovery: false }),
  zalo_personal: capabilityTemplate({
    supportsDiscovery: false,
    directRuleScopes: Object.freeze(['user', 'chat']),
    sharedSpaceRuleScopes: Object.freeze(['chat']),
  }),
  wechat: capabilityTemplate({ supportsDiscovery: false }),
  webchat: capabilityTemplate({ supportsDiscovery: false }),
});

function accessPolicyKey(platform) {
  return `platform_access_policy_${String(platform || '').trim()}`;
}

function legacyWhitelistKey(platform) {
  return `platform_whitelist_${String(platform || '').trim()}`;
}

function getPlatformAccessCapabilities(platform) {
  return PLATFORM_CAPABILITIES[String(platform || '').trim()] || capabilityTemplate();
}

function sanitizeValue(scope, value) {
  if (scope === 'phone_number') {
    return String(value || '').replace(/[^0-9+]/g, '').trim();
  }
  return String(value || '')
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .trim();
}

function normalizeScope(scope) {
  const normalized = String(scope || '').trim().toLowerCase();
  if (normalized === 'guild') return 'server';
  if (normalized === 'phone') return 'phone_number';
  return normalized;
}

function normalizeMode(value, fallback) {
  const normalized = String(value || '').trim().toLowerCase();
  return ACCESS_MODE_SET.has(normalized) ? normalized : fallback;
}

function defaultSharedPolicyForPlatform(platform) {
  return getPlatformAccessCapabilities(platform).supportsSharedPolicy ? 'allowlist' : 'disabled';
}

function createDefaultAccessPolicy(platform) {
  const capabilities = getPlatformAccessCapabilities(platform);
  return {
    schemaVersion: ACCESS_POLICY_SCHEMA_VERSION,
    directPolicy: 'allowlist',
    sharedPolicy: capabilities.supportsSharedPolicy ? 'allowlist' : 'disabled',
    defaultAllowUntaggedInShared: true,
    directRules: [],
    sharedSpaceRules: [],
    sharedActorRules: [],
    sharedMemberRules: [],
    sharedParticipationRules: [],
  };
}

function normalizeRule(rule, allowedScopes) {
  if (!rule || typeof rule !== 'object') return null;
  const scope = normalizeScope(rule.scope);
  if (!RULE_SCOPE_SET.has(scope) || !allowedScopes.has(scope)) return null;
  const value = sanitizeValue(scope, rule.value);
  if (!value) return null;
  const label = String(rule.label || '').trim();
  return label ? { scope, value, label } : { scope, value };
}

function dedupeRules(rules) {
  const seen = new Set();
  const result = [];
  for (const rule of rules) {
    const key = [
      rule.scope,
      rule.value,
      rule.spaceScope || '',
      rule.spaceValue || '',
    ].join(':');
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(rule);
  }
  return result;
}

function normalizeSharedMemberRule(rule, actorScopes, spaceScopes) {
  const actorRule = normalizeRule(rule, actorScopes);
  if (!actorRule) return null;
  const spaceScope = normalizeScope(rule.spaceScope);
  if (!RULE_SCOPE_SET.has(spaceScope) || !spaceScopes.has(spaceScope)) return null;
  const spaceValue = sanitizeValue(spaceScope, rule.spaceValue);
  if (!spaceValue) return null;
  const spaceLabel = String(rule.spaceLabel || '').trim();
  return {
    ...actorRule,
    spaceScope,
    spaceValue,
    ...(spaceLabel ? { spaceLabel } : {}),
  };
}

function normalizeSharedParticipationRule(rule, spaceScopes) {
  const normalized = normalizeRule(rule, spaceScopes);
  if (!normalized) return null;
  return {
    ...normalized,
    allowUntagged: rule.allowUntagged === true,
  };
}

function normalizeAccessPolicy(platform, value) {
  const capabilities = getPlatformAccessCapabilities(platform);
  const defaults = createDefaultAccessPolicy(platform);
  const directScopes = new Set(capabilities.directRuleScopes);
  const sharedSpaceScopes = new Set(capabilities.sharedSpaceRuleScopes);
  const sharedActorScopes = new Set(capabilities.sharedActorRuleScopes);
  const raw = value && typeof value === 'object' ? value : {};
  let rawSharedSpaceRules = Array.isArray(raw.sharedSpaceRules) ? raw.sharedSpaceRules : [];
  let rawSharedActorRules = Array.isArray(raw.sharedActorRules) ? raw.sharedActorRules : [];
  let rawSharedMemberRules = Array.isArray(raw.sharedMemberRules) ? raw.sharedMemberRules : [];
  const rawSharedParticipationRules = Array.isArray(raw.sharedParticipationRules)
    ? raw.sharedParticipationRules
    : [];
  let rawSharedPolicy = raw.sharedPolicy;
  const isLegacyParticipationPolicy = Number(raw.schemaVersion || 0) < 3;

  if (
    Number(raw.schemaVersion || 0) < 2
    && rawSharedMemberRules.length === 0
    && rawSharedActorRules.length > 0
  ) {
    if (normalizeMode(rawSharedPolicy, defaults.sharedPolicy) === 'open') {
      rawSharedPolicy = 'allowlist';
      rawSharedSpaceRules = [];
    } else if (rawSharedSpaceRules.length > 0) {
      rawSharedMemberRules = rawSharedActorRules.flatMap((actorRule) =>
        rawSharedSpaceRules.map((spaceRule) => ({
          ...actorRule,
          spaceScope: spaceRule.scope,
          spaceValue: spaceRule.value,
          spaceLabel: spaceRule.label,
        })));
      rawSharedSpaceRules = [];
      rawSharedActorRules = [];
    }
  }

  const normalized = {
    schemaVersion: ACCESS_POLICY_SCHEMA_VERSION,
    directPolicy: normalizeMode(raw.directPolicy, defaults.directPolicy),
    sharedPolicy: normalizeMode(rawSharedPolicy, defaults.sharedPolicy),
    defaultAllowUntaggedInShared: capabilities.supportsUntaggedGroupToggle
      ? (isLegacyParticipationPolicy
        ? raw.requireMentionInShared !== true
        : raw.defaultAllowUntaggedInShared !== false)
      : true,
    directRules: dedupeRules((Array.isArray(raw.directRules) ? raw.directRules : [])
      .map((rule) => normalizeRule(rule, directScopes))
      .filter(Boolean)),
    sharedSpaceRules: dedupeRules(rawSharedSpaceRules
      .map((rule) => normalizeRule(rule, sharedSpaceScopes))
      .filter(Boolean)),
    sharedActorRules: dedupeRules(rawSharedActorRules
      .map((rule) => normalizeRule(rule, sharedActorScopes))
      .filter(Boolean)),
    sharedMemberRules: dedupeRules(rawSharedMemberRules
      .map((rule) => normalizeSharedMemberRule(rule, sharedActorScopes, sharedSpaceScopes))
      .filter(Boolean)),
    sharedParticipationRules: dedupeRules(rawSharedParticipationRules
      .map((rule) => normalizeSharedParticipationRule(rule, sharedSpaceScopes))
      .filter(Boolean)),
  };
  if (!capabilities.supportsSharedPolicy) {
    normalized.sharedPolicy = 'disabled';
    normalized.defaultAllowUntaggedInShared = true;
    normalized.sharedSpaceRules = [];
    normalized.sharedActorRules = [];
    normalized.sharedMemberRules = [];
    normalized.sharedParticipationRules = [];
  }

  return normalized;
}

function addRule(bucket, rule, state) {
  if (!rule) return;
  state[bucket].push(rule);
}

function isWhatsAppGroupId(value) {
  return String(value || '').trim().toLowerCase().split(':')[0].endsWith('@g.us');
}

function normalizeWhatsAppDirectId(value) {
  const raw = String(value || '').trim().toLowerCase();
  const base = raw.includes('@') ? raw.split('@')[0] : raw;
  const primary = base.includes(':') ? base.split(':')[0] : base;
  return primary.replace(/\D/g, '') || primary;
}

function migrateLegacyWhitelist(platform, entries) {
  const capabilities = getPlatformAccessCapabilities(platform);
  const policy = createDefaultAccessPolicy(platform);
  const state = {
    directRules: [],
    sharedSpaceRules: [],
    sharedActorRules: [],
    sharedMemberRules: [],
    sharedParticipationRules: [],
  };
  const list = Array.isArray(entries)
    ? entries.map((item) => String(item || '').trim()).filter(Boolean)
    : [];

  if (list.some((entry) => entry === '*')) {
    policy.directPolicy = 'open';
    if (capabilities.supportsSharedPolicy) {
      policy.sharedPolicy = 'open';
    }
  }

  for (const entry of list) {
    if (entry === '*') continue;
    const prefixed = entry.match(/^([a-z_]+):(.*)$/i);
    const rawScope = prefixed ? prefixed[1] : '';
    const rawValue = prefixed ? prefixed[2] : entry;
    const scope = normalizeScope(rawScope);
    const value = sanitizeValue(scope || 'chat', rawValue);
    if (!value) continue;

    if (platform === 'whatsapp') {
      if (scope === 'group' || isWhatsAppGroupId(value)) {
        addRule('sharedSpaceRules', normalizeRule({ scope: 'group', value }, new Set(capabilities.sharedSpaceRuleScopes)), state);
        continue;
      }
      const directValue = scope === 'chat' ? value : normalizeWhatsAppDirectId(value);
      if (!directValue) continue;
      if (scope === 'chat') {
        addRule('directRules', normalizeRule({ scope: 'chat', value: directValue }, new Set(capabilities.directRuleScopes)), state);
      } else {
        addRule('directRules', normalizeRule({ scope: 'phone_number', value: directValue }, new Set(capabilities.directRuleScopes)), state);
        addRule('sharedActorRules', normalizeRule({ scope: 'phone_number', value: directValue }, new Set(capabilities.sharedActorRuleScopes)), state);
      }
      continue;
    }

    if (DIRECT_ONLY_PHONE_PLATFORMS.has(platform)) {
      addRule('directRules', normalizeRule({ scope: 'phone_number', value }, new Set(capabilities.directRuleScopes)), state);
      continue;
    }

    if (platform === 'telegram' && !prefixed) {
      if (value.startsWith('-')) {
        addRule('sharedSpaceRules', normalizeRule({ scope: 'group', value }, new Set(capabilities.sharedSpaceRuleScopes)), state);
      } else {
        const directRule = normalizeRule({ scope: 'user', value }, new Set(capabilities.directRuleScopes));
        const actorRule = normalizeRule({ scope: 'user', value }, new Set(capabilities.sharedActorRuleScopes));
        addRule('directRules', directRule, state);
        addRule('sharedActorRules', actorRule, state);
      }
      continue;
    }

    if (platform === 'discord' && !prefixed) {
      const directRule = normalizeRule({ scope: 'user', value }, new Set(capabilities.directRuleScopes));
      const actorRule = normalizeRule({ scope: 'user', value }, new Set(capabilities.sharedActorRuleScopes));
      addRule('directRules', directRule, state);
      addRule('sharedActorRules', actorRule, state);
      continue;
    }

    switch (scope) {
      case 'user': {
        const directRule = normalizeRule({ scope: 'user', value }, new Set(capabilities.directRuleScopes));
        const actorRule = normalizeRule({ scope: 'user', value }, new Set(capabilities.sharedActorRuleScopes));
        addRule('directRules', directRule, state);
        addRule('sharedActorRules', actorRule, state);
        break;
      }
      case 'role':
        addRule('sharedActorRules', normalizeRule({ scope: 'role', value }, new Set(capabilities.sharedActorRuleScopes)), state);
        break;
      case 'group':
      case 'channel':
      case 'server':
      case 'room':
      case 'chat':
        addRule('sharedSpaceRules', normalizeRule({ scope, value }, new Set(capabilities.sharedSpaceRuleScopes)), state);
        break;
      case 'phone_number':
        addRule('directRules', normalizeRule({ scope: 'phone_number', value }, new Set(capabilities.directRuleScopes)), state);
        addRule('sharedActorRules', normalizeRule({ scope: 'phone_number', value }, new Set(capabilities.sharedActorRuleScopes)), state);
        break;
      default: {
        if (SHARED_RAW_ID_PLATFORMS.has(platform)) {
          addRule('sharedSpaceRules', normalizeRule({ scope: 'chat', value: sanitizeValue('chat', entry) }, new Set(capabilities.sharedSpaceRuleScopes)), state);
          break;
        }
        const directRule = normalizeRule({ scope: 'chat', value: sanitizeValue('chat', entry) }, new Set(capabilities.directRuleScopes));
        const sharedRule = normalizeRule({ scope: 'chat', value: sanitizeValue('chat', entry) }, new Set(capabilities.sharedSpaceRuleScopes));
        addRule('directRules', directRule, state);
        addRule('sharedSpaceRules', sharedRule, state);
        break;
      }
    }
  }

  return normalizeAccessPolicy(platform, {
    ...policy,
    directRules: state.directRules,
    sharedSpaceRules: state.sharedSpaceRules,
    sharedActorRules: state.sharedActorRules,
    sharedMemberRules: state.sharedMemberRules,
    sharedParticipationRules: state.sharedParticipationRules,
  });
}

function parseStoredAccessPolicy(platform, policyValue, legacyValue) {
  if (policyValue != null) {
    try {
      const parsed = typeof policyValue === 'string' ? JSON.parse(policyValue) : policyValue;
      return normalizeAccessPolicy(platform, parsed);
    } catch {
      return createDefaultAccessPolicy(platform);
    }
  }
  if (legacyValue != null) {
    try {
      const parsed = typeof legacyValue === 'string' ? JSON.parse(legacyValue) : legacyValue;
      return migrateLegacyWhitelist(platform, parsed);
    } catch {
      return createDefaultAccessPolicy(platform);
    }
  }
  return createDefaultAccessPolicy(platform);
}

function normalizePhone(value) {
  return String(value || '').replace(/[^0-9+]/g, '');
}

function contextMatchesRule(rule, context) {
  const value = String(rule.value || '');
  switch (rule.scope) {
    case 'user':
      return value && String(context.senderId || '') === value;
    case 'dm':
      return Boolean(context.isDirect) && value && String(context.chatId || '') === value;
    case 'chat':
      return value && String(context.chatId || '') === value;
    case 'group':
      return Boolean(context.isShared) && value && String(context.groupId || context.chatId || '') === value;
    case 'channel':
      return Boolean(context.isShared) && value && String(context.channelId || context.chatId || '') === value;
    case 'server':
      return Boolean(context.isShared) && value && String(context.serverId || '') === value;
    case 'room':
      return Boolean(context.isShared) && value && String(context.roomId || context.chatId || '') === value;
    case 'role':
      return Array.isArray(context.roleIds) && context.roleIds.map(String).includes(value);
    case 'phone_number':
      return normalizePhone(context.phoneNumber || context.senderId) === normalizePhone(value);
    default:
      return false;
  }
}

function contextMatchesSharedMemberRule(rule, context) {
  if (!contextMatchesRule(rule, context)) return false;
  return contextMatchesRule({
    scope: rule.spaceScope,
    value: rule.spaceValue,
  }, context);
}

function allowUntaggedForContext(policy, context) {
  const scopePriority = {
    group: 4,
    channel: 4,
    room: 4,
    chat: 3,
    server: 2,
  };
  const rule = policy.sharedParticipationRules
    .filter((item) => contextMatchesRule(item, context))
    .sort((left, right) =>
      (scopePriority[right.scope] || 0) - (scopePriority[left.scope] || 0))[0];
  return rule ? rule.allowUntagged : policy.defaultAllowUntaggedInShared;
}

function evaluateAccessPolicy(policyInput, context, platform) {
  const capabilities = getPlatformAccessCapabilities(platform);
  const policy = normalizeAccessPolicy(platform, policyInput);
  const isDirect = context?.isDirect === true;
  const isShared = context?.isShared === true;

  if (isDirect) {
    if (policy.directPolicy === 'disabled') {
      return { allowed: false, reason: 'direct_disabled', policy };
    }
    if (policy.directPolicy === 'allowlist') {
      const directMatch = policy.directRules.some((rule) => contextMatchesRule(rule, context))
        || policy.sharedActorRules.some((rule) => contextMatchesRule(rule, context));
      if (!directMatch) {
        return { allowed: false, reason: 'direct_not_allowed', policy };
      }
    }
    return { allowed: true, reason: 'allowed', policy };
  }

  if (isShared) {
    if (!capabilities.supportsSharedPolicy || policy.sharedPolicy === 'disabled') {
      return { allowed: false, reason: 'shared_disabled', policy };
    }
    if (policy.sharedPolicy === 'allowlist') {
      const sharedSpaceMatch = policy.sharedSpaceRules.some((rule) => contextMatchesRule(rule, context));
      const sharedActorMatch = policy.sharedActorRules.some((rule) => contextMatchesRule(rule, context));
      const sharedMemberMatch = policy.sharedMemberRules.some(
        (rule) => contextMatchesSharedMemberRule(rule, context),
      );
      if (!sharedSpaceMatch && !sharedActorMatch && !sharedMemberMatch) {
        return { allowed: false, reason: 'shared_not_allowed', policy };
      }
    }
    const allowUntagged = allowUntaggedForContext(policy, context);
    return {
      allowed: true,
      reason: 'allowed',
      policy,
      allowUntagged,
      participationHint: allowUntagged ? 'automatic' : 'mention_only',
    };
  }

  return { allowed: false, reason: 'unsupported_context', policy };
}

function labelForScope(scope) {
  switch (scope) {
    case 'phone_number':
      return 'number';
    case 'server':
      return 'server';
    default:
      return scope;
  }
}

function makeSuggestion({
  scope,
  value,
  label,
  bucket,
  spaceScope = null,
  spaceValue = null,
  spaceLabel = null,
}) {
  if (!scope || !value || !bucket) return null;
  const rule = {
    scope,
    value,
    ...(spaceScope && spaceValue ? { spaceScope, spaceValue } : {}),
    ...(spaceLabel ? { spaceLabel } : {}),
  };
  return {
    label: label || `Allow ${labelForScope(scope)} ${value}`,
    prefixedId: scope === 'phone_number' ? value : `${scope}:${value}`,
    bucket,
    rule,
  };
}

function sharedSpaceFromContext(context, options = {}, allowedScopes = []) {
  const scopes = new Set(allowedScopes);
  if (context.channelId && scopes.has('channel')) {
    return {
      scope: 'channel',
      value: context.channelId,
      label: options.channelLabel || context.channelId,
    };
  }
  if (context.roomId && scopes.has('room')) {
    return {
      scope: 'room',
      value: context.roomId,
      label: options.roomLabel || context.roomId,
    };
  }
  if (context.groupId && scopes.has('group')) {
    return {
      scope: 'group',
      value: context.groupId,
      label: options.groupLabel || context.groupId,
    };
  }
  if (context.chatId && scopes.has('chat')) {
    return {
      scope: 'chat',
      value: context.chatId,
      label: context.chatId,
    };
  }
  return null;
}

function buildBlockedSenderSuggestions(platform, context, options = {}) {
  const suggestions = [];
  const senderLabel = String(options.senderName || context.senderId || '').trim();
  const chatId = String(context.chatId || '').trim();
  const capabilities = getPlatformAccessCapabilities(platform);
  const actorScope = context.phoneNumber ? 'phone_number' : 'user';
  const actorValue = String(context.phoneNumber || context.senderId || '').trim();
  const canUseSharedActor = capabilities.sharedActorRuleScopes.includes(actorScope);

  if (context.isDirect) {
    if (actorValue && canUseSharedActor) {
      suggestions.push(makeSuggestion({
        scope: actorScope,
        value: actorValue,
        label: `Allow sender everywhere (${senderLabel || actorValue})`,
        bucket: 'sharedActorRules',
      }));
    } else if (context.phoneNumber) {
      suggestions.push(makeSuggestion({
        scope: 'phone_number',
        value: context.phoneNumber,
        label: `Allow sender (${senderLabel || context.phoneNumber})`,
        bucket: 'directRules',
      }));
    } else if (context.senderId) {
      suggestions.push(makeSuggestion({
        scope: 'user',
        value: context.senderId,
        label: `Allow sender (${senderLabel || context.senderId})`,
        bucket: 'directRules',
      }));
    }
    if (chatId && !String(context.senderId || '').trim()) {
      suggestions.push(makeSuggestion({
        scope: 'chat',
        value: chatId,
        label: `Allow chat (${chatId})`,
        bucket: 'directRules',
      }));
    }
  } else if (context.isShared) {
    const sharedSpace = sharedSpaceFromContext(
      context,
      options,
      capabilities.sharedSpaceRuleScopes,
    );
    if (actorValue && canUseSharedActor && sharedSpace) {
      suggestions.push(makeSuggestion({
        scope: actorScope,
        value: actorValue,
        label: `Allow sender in this ${labelForScope(sharedSpace.scope)} only (${senderLabel || actorValue})`,
        bucket: 'sharedMemberRules',
        spaceScope: sharedSpace.scope,
        spaceValue: sharedSpace.value,
        spaceLabel: sharedSpace.label,
      }));
      suggestions.push(makeSuggestion({
        scope: actorScope,
        value: actorValue,
        label: `Allow sender everywhere (${senderLabel || actorValue})`,
        bucket: 'sharedActorRules',
      }));
    }
    if (sharedSpace) {
      suggestions.push(makeSuggestion({
        scope: sharedSpace.scope,
        value: sharedSpace.value,
        label: `Allow everyone in this ${labelForScope(sharedSpace.scope)} (${sharedSpace.label})`,
        bucket: 'sharedSpaceRules',
      }));
    }
  }

  return suggestions.filter(Boolean).filter((item, index, list) => {
    const key = [
      item.bucket,
      item.rule.scope,
      item.rule.value,
      item.rule.spaceScope || '',
      item.rule.spaceValue || '',
    ].join(':');
    return list.findIndex((entry) => [
      entry.bucket,
      entry.rule.scope,
      entry.rule.value,
      entry.rule.spaceScope || '',
      entry.rule.spaceValue || '',
    ].join(':') === key) === index;
  });
}

function buildBlockedSenderPayload(platform, context, options = {}) {
  return {
    sender: context.senderId || context.phoneNumber || null,
    chatId: context.chatId || null,
    senderName: options.senderName || null,
    meta: options.meta || '',
    suggestions: buildBlockedSenderSuggestions(platform, context, options),
  };
}

function describeRules(rules) {
  if (!Array.isArray(rules) || rules.length === 0) return 'none';
  return rules
    .slice(0, 3)
    .map((rule) => `${labelForScope(rule.scope)}:${rule.value}`)
    .join(', ');
}

function summarizeAccessPolicy(platform, policyInput) {
  const capabilities = getPlatformAccessCapabilities(platform);
  const policy = normalizeAccessPolicy(platform, policyInput);
  const parts = [
    `DMs ${policy.directPolicy}`,
  ];
  if (capabilities.supportsSharedPolicy) {
    parts.push(`shared spaces ${policy.sharedPolicy}`);
    if (capabilities.supportsUntaggedGroupToggle) {
      const mentionOnlyCount = policy.sharedParticipationRules
        .filter((rule) => !rule.allowUntagged).length;
      if (!policy.defaultAllowUntaggedInShared) {
        parts.push('untagged responses off by default');
      } else {
        parts.push(mentionOnlyCount > 0
          ? `${mentionOnlyCount} tagged-only shared space${mentionOnlyCount === 1 ? '' : 's'}`
          : 'social intelligence for untagged messages');
      }
    }
  }
  const ruleCount = policy.directRules.length
    + policy.sharedSpaceRules.length
    + policy.sharedActorRules.length
    + policy.sharedMemberRules.length;
  if (ruleCount > 0) {
    parts.push(`${ruleCount} rule${ruleCount == 1 ? '' : 's'}`);
  }
  return parts.join(' • ');
}

function classifyRecentTarget(platform, row) {
  const chatId = String(row.platform_chat_id || '').trim();
  const metadata = row.metadata && typeof row.metadata === 'object' ? row.metadata : {};
  const sender = String(
    row.sender
    || row.sender_id
    || metadata.sender
    || metadata.senderId
    || metadata.sender_id
    || '',
  ).trim();
  const senderName = String(metadata.senderName || metadata.sender_name || row.sender_name || '').trim();
  const groupName = String(
    metadata.groupName
    || metadata.group_name
    || metadata.channelName
    || metadata.channel_name
    || metadata.roomName
    || metadata.room_name
    || metadata.serverName
    || metadata.server_name
    || metadata.guildName
    || metadata.guild_name
    || '',
  ).trim();
  if (!chatId && !sender) return null;

  const isDirect = !String(metadata.isGroup || '').match(/^(true|1)$/i) && (!chatId || chatId === sender || chatId === `dm_${sender}`);
  if (platform === 'whatsapp' && !isDirect && chatId) {
    return {
      source: 'recent',
      bucket: 'sharedSpaceRules',
      scope: 'group',
      value: chatId,
      label: groupName || chatId,
      subtitle: 'Recent WhatsApp group',
    };
  }
  if (DIRECT_ONLY_PHONE_PLATFORMS.has(platform) || platform === 'whatsapp') {
    const value = normalizePhone(sender || chatId);
    if (!value) return null;
    return {
      source: 'recent',
      bucket: 'directRules',
      scope: 'phone_number',
      value,
      label: senderName || value,
      subtitle: 'Recent caller',
    };
  }
  if (isDirect && sender) {
    return {
      source: 'recent',
      bucket: 'directRules',
      scope: 'user',
      value: sender,
      label: senderName || sender,
      subtitle: 'Recent direct sender',
    };
  }
  return {
    source: 'recent',
    bucket: 'sharedSpaceRules',
    scope: platform === 'matrix' ? 'room' : platform === 'discord' ? 'channel' : platform === 'telegram' ? 'group' : 'chat',
    value: chatId,
    label: groupName || chatId,
    subtitle: 'Recent conversation',
  };
}

function contextFromMessage(msg) {
  const chatId = String(msg.chatId || '').trim();
  const senderId = String(msg.sender || '').trim();
  const normalizedChatId = chatId.startsWith('dm_') ? chatId.slice(3) : chatId;
  const capabilities = getPlatformAccessCapabilities(msg.platform);
  const phoneNumber = capabilities.directRuleScopes.includes('phone_number')
    ? normalizePhone(msg.phoneNumber || senderId)
    : '';
  return {
    platform: msg.platform,
    senderId,
    chatId,
    isDirect: !msg.isGroup,
    isShared: Boolean(msg.isGroup),
    groupId: msg.isGroup ? String(msg.groupId || msg.chatId || '').trim() : '',
    channelId: msg.isGroup ? String(msg.channelId || msg.chatId || '').trim() : '',
    serverId: String(msg.guildId || msg.serverId || '').trim(),
    roomId: String(msg.roomId || '').trim(),
    roleIds: Array.isArray(msg.roleIds) ? msg.roleIds.map(String) : [],
    phoneNumber,
    wasMentioned: msg.wasMentioned === true,
    normalizedChatId,
  };
}

module.exports = {
  ACCESS_MODES,
  RULE_SCOPES,
  accessPolicyKey,
  legacyWhitelistKey,
  getPlatformAccessCapabilities,
  createDefaultAccessPolicy,
  normalizeAccessPolicy,
  migrateLegacyWhitelist,
  parseStoredAccessPolicy,
  evaluateAccessPolicy,
  buildBlockedSenderSuggestions,
  buildBlockedSenderPayload,
  summarizeAccessPolicy,
  classifyRecentTarget,
  contextFromMessage,
};
