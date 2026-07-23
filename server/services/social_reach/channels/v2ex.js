'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { assertHttpUrl, fetchJson, normalizeLimit } = require('../utils');
const { createAbortError } = require('../../../utils/abort');

function shapeTopic(item = {}) {
  const node = item.node || {};
  const member = item.member || {};
  return {
    id: item.id || null,
    title: item.title || '',
    url: item.url || (item.id ? `https://www.v2ex.com/t/${item.id}` : ''),
    content: item.content || '',
    replies: item.replies || 0,
    nodeName: node.name || '',
    nodeTitle: node.title || '',
    author: member.username || '',
    createdAt: item.created || null,
  };
}

class V2exChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('v2ex'));
  }

  async check() {
    return {
      ...(await super.check()),
      activeBackend: 'v2ex_public_api',
      message: 'Public API supports hot topics, node topics, topic details, and users.',
    };
  }

  async read({ url, limit, signal }) {
    const parsed = assertHttpUrl(url);
    const match = parsed.pathname.match(/^\/t\/(\d+)/);
    if (!match) {
      return this.search({ query: parsed.searchParams.get('q') || 'hot', limit, signal });
    }
    const topicId = match[1];
    const topicData = await fetchJson(
      `https://www.v2ex.com/api/topics/show.json?id=${encodeURIComponent(topicId)}`,
      { signal },
    );
    const topic = Array.isArray(topicData) ? topicData[0] || {} : topicData || {};
    const replies = await fetchJson(
      `https://www.v2ex.com/api/replies/show.json?topic_id=${encodeURIComponent(topicId)}&page=1`,
      { signal },
    )
      .catch((error) => {
        if (signal?.aborted) throw createAbortError(signal);
        return [];
      });
    return {
      platform: this.id,
      ...shapeTopic(topic),
      repliesList: (Array.isArray(replies) ? replies : [])
        .slice(0, normalizeLimit(limit, 50, 100))
        .map((reply) => ({
          author: reply.member?.username || '',
          content: reply.content || '',
          createdAt: reply.created || null,
        })),
      source: 'v2ex_public_api',
    };
  }

  async search({ query, limit, signal }) {
    const normalized = String(query || '').trim().toLowerCase();
    const capped = normalizeLimit(limit, 20, 100);
    if (normalized && normalized !== 'hot') {
      const data = await fetchJson(
        `https://www.v2ex.com/api/topics/show.json?node_name=${encodeURIComponent(normalized)}&page=1`,
        { signal },
      );
      return {
        platform: this.id,
        query: normalized,
        results: (Array.isArray(data) ? data : []).slice(0, capped).map(shapeTopic),
        source: 'v2ex_public_api',
      };
    }
    const data = await fetchJson('https://www.v2ex.com/api/topics/hot.json', { signal });
    return {
      platform: this.id,
      query: 'hot',
      results: (Array.isArray(data) ? data : []).slice(0, capped).map(shapeTopic),
      source: 'v2ex_public_api',
    };
  }
}

module.exports = {
  V2exChannel,
};
