'use strict';

const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');

const DISCOVERABLE_PLATFORMS = Object.freeze([
  'whatsapp',
  'discord',
  'telegram',
  'slack',
]);

const SOURCE_RANK = Object.freeze({
  discovered: 0,
  live: 0,
  default: 1,
  recent: 2,
  manual: 3,
});

const PLATFORM_LABELS = Object.freeze({
  whatsapp: 'WhatsApp',
  discord: 'Discord',
  telegram: 'Telegram',
  slack: 'Slack',
});

const MAX_TARGETS = 80;

function normalizeText(value) {
  return String(value || '').trim();
}

function platformLabel(platform) {
  return PLATFORM_LABELS[platform] || platform.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
}

function normalizeSource(source) {
  const normalized = normalizeText(source).toLowerCase();
  if (normalized === 'live') return 'discovered';
  if (SOURCE_RANK[normalized] != null) return normalized;
  return 'discovered';
}

function normalizeTarget(input = {}, fallback = {}) {
  const platform = normalizeText(input.platform || fallback.platform).toLowerCase();
  const to = normalizeText(input.to || input.value || fallback.to);
  if (!platform || !to) return null;
  const label = normalizeText(input.label) || to;
  const source = normalizeSource(input.source || fallback.source);
  return {
    platform,
    platformLabel: platformLabel(platform),
    to,
    label,
    subtitle: normalizeText(input.subtitle) || platformLabel(platform),
    source,
    connected: input.connected !== false,
    supportsDelivery: input.supportsDelivery !== false,
  };
}

function metadataFromRow(row) {
  try {
    return row?.metadata ? JSON.parse(row.metadata) : {};
  } catch {
    return {};
  }
}

function parseSettingValue(value) {
  try {
    const parsed = JSON.parse(value || '""');
    return normalizeText(parsed);
  } catch {
    return normalizeText(value);
  }
}

function labelFromMetadata(platform, row) {
  const metadata = metadataFromRow(row);
  return normalizeText(
    metadata.groupName
      || metadata.group_name
      || metadata.channelName
      || metadata.channel_name
      || metadata.guildName
      || metadata.guild_name
      || metadata.senderName
      || metadata.sender_name
      || row.platform_chat_id
      || '',
  ) || normalizeText(row.platform_chat_id);
}

class TaskDeliveryTargetService {
  constructor(options = {}) {
    this.app = options.app || null;
    this.db = options.db || db;
  }

  async listTargets(userId, options = {}) {
    const agentId = resolveAgentId(userId, options.agentId || options.agent_id || null);
    const platformFilter = normalizeText(options.platform).toLowerCase();
    const query = normalizeText(options.q || options.query).toLowerCase();
    const discovered = await this._discoverTargets(userId, agentId, platformFilter);
    const defaults = this._defaultTargets(userId, agentId, platformFilter);
    const recent = this._recentTargets(userId, agentId, platformFilter);
    return this._filterAndSort([...discovered, ...defaults, ...recent], query);
  }

  async _discoverTargets(userId, agentId, platformFilter) {
    const platforms = platformFilter ? [platformFilter] : DISCOVERABLE_PLATFORMS;
    const results = [];
    for (const platform of platforms) {
      if (!DISCOVERABLE_PLATFORMS.includes(platform)) continue;
      if (platform === 'slack') {
        results.push(...await this._discoverSlackTargets(userId, agentId));
      } else {
        results.push(...await this._discoverMessagingPlatformTargets(userId, agentId, platform));
      }
    }
    return results;
  }

  async _discoverMessagingPlatformTargets(userId, agentId, platform) {
    const manager = this.app?.locals?.messagingManager || null;
    if (!manager || typeof manager.listAccessTargets !== 'function') return [];
    let rawTargets = [];
    try {
      rawTargets = await manager.listAccessTargets(userId, platform, { agentId });
    } catch {
      rawTargets = [];
    }
    return (Array.isArray(rawTargets) ? rawTargets : [])
      .map((target) => normalizeTarget({
        ...target,
        platform,
        to: target.to || target.value,
        source: 'discovered',
      }))
      .filter(Boolean);
  }

  async _discoverSlackTargets(userId, agentId) {
    const integrationManager = this.app?.locals?.integrationManager || null;
    if (!integrationManager || typeof integrationManager.executeTool !== 'function') return [];
    let response;
    try {
      response = await integrationManager.executeTool(
        userId,
        'slack_list_conversations',
        {
          types: 'public_channel,private_channel,im,mpim',
          limit: 200,
        },
        agentId,
      );
    } catch {
      return [];
    }
    if (response?.error) return [];
    const channels = response?.result?.channels || response?.result?.response_metadata?.channels || [];
    if (!Array.isArray(channels)) return [];
    return channels
      .map((channel) => {
        const id = normalizeText(channel.id);
        if (!id) return null;
        const isDirect = channel.is_im === true;
        const isPrivate = channel.is_private === true;
        const name = normalizeText(channel.name || channel.user || id);
        return normalizeTarget({
          platform: 'slack',
          to: id,
          label: isDirect ? name : `#${name}`,
          subtitle: isDirect
            ? 'Slack direct message'
            : (isPrivate ? 'Private Slack channel' : 'Slack channel'),
          source: 'discovered',
        });
      })
      .filter(Boolean);
  }

  _defaultTargets(userId, agentId, platformFilter) {
    const rows = this.db.prepare(
      `SELECT key, value
       FROM agent_settings
       WHERE user_id = ? AND agent_id = ? AND key IN ('last_platform', 'last_chat_id')`
    ).all(userId, agentId);
    const values = Object.fromEntries(rows.map((row) => [row.key, parseSettingValue(row.value)]));
    const platform = normalizeText(values.last_platform).toLowerCase();
    const to = normalizeText(values.last_chat_id);
    if (!platform || !to || (platformFilter && platform !== platformFilter)) return [];
    return [normalizeTarget({
      platform,
      to,
      label: to,
      subtitle: 'Current default channel',
      source: 'default',
    })].filter(Boolean);
  }

  _recentTargets(userId, agentId, platformFilter) {
    const params = [userId, agentId];
    let platformClause = '';
    if (platformFilter) {
      platformClause = 'AND platform = ?';
      params.push(platformFilter);
    }
    params.push(80);
    const rows = this.db.prepare(
      `SELECT platform, platform_chat_id, metadata
       FROM messages
       WHERE user_id = ?
         AND agent_id = ?
         AND platform IS NOT NULL
         AND platform_chat_id IS NOT NULL
         ${platformClause}
       ORDER BY id DESC
       LIMIT ?`
    ).all(...params);
    return rows
      .map((row) => normalizeTarget({
        platform: row.platform,
        to: row.platform_chat_id,
        label: labelFromMetadata(row.platform, row),
        subtitle: 'Recent conversation',
        source: 'recent',
      }))
      .filter(Boolean);
  }

  _filterAndSort(targets, query) {
    const seen = new Set();
    const unique = [];
    for (const target of targets) {
      const key = `${target.platform}:${target.to}`;
      if (seen.has(key)) continue;
      seen.add(key);
      if (query) {
        const haystack = `${target.platformLabel} ${target.label} ${target.subtitle} ${target.to}`.toLowerCase();
        if (!haystack.includes(query)) continue;
      }
      unique.push(target);
    }
    return unique.sort((left, right) => {
      const leftRank = SOURCE_RANK[left.source] ?? 9;
      const rightRank = SOURCE_RANK[right.source] ?? 9;
      if (leftRank !== rightRank) return leftRank - rightRank;
      if (left.platformLabel !== right.platformLabel) return left.platformLabel.localeCompare(right.platformLabel);
      return left.label.localeCompare(right.label);
    }).slice(0, MAX_TARGETS);
  }
}

module.exports = {
  TaskDeliveryTargetService,
  normalizeTarget,
};
