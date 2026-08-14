'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { cookieHeaderForPlatform, getCookieSummary } = require('../store');
const { DEFAULT_UA, fetchJson, normalizeLimit, parseMaybeJson } = require('../utils');

function stripHtml(value) {
  return String(value || '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
}

class XueqiuChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('xueqiu'));
  }

  async check({ userId } = {}) {
    const cookies = getCookieSummary(userId, this.id);
    return {
      ...(await super.check()),
      ready: cookies.configured,
      status: cookies.configured ? 'ok' : 'warn',
      activeBackend: cookies.configured ? 'xueqiu_http_cookies' : null,
      cookie: cookies,
      message: cookies.configured
        ? 'Cookie-backed Xueqiu APIs are configured.'
        : 'Import Xueqiu cookies from the cloud computer browser before using stock and community APIs.',
    };
  }

  #headers(userId) {
    const cookie = cookieHeaderForPlatform(userId, this.id);
    return {
      'user-agent': DEFAULT_UA,
      referer: 'https://xueqiu.com/',
      ...(cookie ? { cookie } : {}),
    };
  }

  async search({ userId, query, limit, signal }) {
    const q = String(query || '').trim();
    if (!q) {
      const error = new Error('query is required.');
      error.status = 400;
      throw error;
    }
    const url = `https://xueqiu.com/stock/search.json?code=${encodeURIComponent(q)}&size=${normalizeLimit(limit, 10, 50)}`;
    const data = await fetchJson(url, { headers: this.#headers(userId), signal });
    return {
      platform: this.id,
      query: q,
      results: (data.stocks || []).map((item) => ({
        symbol: item.code || '',
        name: item.name || '',
        exchange: item.exchange || '',
      })),
      source: 'xueqiu_http_cookies',
    };
  }

  async read({ userId, symbol, limit, signal }) {
    const raw = String(symbol || '').trim().toUpperCase();
    if (raw) {
      const data = await fetchJson(
        `https://stock.xueqiu.com/v5/stock/batch/quote.json?symbol=${encodeURIComponent(raw)}`,
        { headers: this.#headers(userId), signal },
      );
      const quote = data.data?.items?.[0]?.quote || {};
      return {
        platform: this.id,
        symbol: quote.symbol || raw,
        name: quote.name || '',
        quote,
        source: 'xueqiu_http_cookies',
      };
    }
    const data = await fetchJson(
      'https://xueqiu.com/v4/statuses/public_timeline_by_category.json?since_id=-1&max_id=-1&count=20&category=-1',
      { headers: this.#headers(userId), signal },
    );
    return {
      platform: this.id,
      results: (data.list || []).slice(0, normalizeLimit(limit, 20, 50)).map((item) => {
        const post = parseMaybeJson(item.data, {});
        return {
          id: post.id || item.id || null,
          title: post.title || '',
          text: stripHtml(post.text || post.description || ''),
          author: post.user?.screen_name || '',
          likes: post.like_count || null,
          url: post.target ? `https://xueqiu.com${post.target}` : '',
        };
      }),
      source: 'xueqiu_http_cookies',
    };
  }
}

module.exports = {
  XueqiuChannel,
};
