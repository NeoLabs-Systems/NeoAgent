'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { assertHttpUrl, compactText, fetchJson, normalizeLimit } = require('../utils');

function normalizeRedditHost(hostname) {
  return String(hostname || '').toLowerCase().replace(/^www\./, '').replace(/^old\./, '');
}

function postUrlForJson(input) {
  const parsed = assertHttpUrl(input);
  if (normalizeRedditHost(parsed.hostname) !== 'reddit.com') {
    const error = new Error('A Reddit URL is required.');
    error.status = 400;
    throw error;
  }
  if (!/\/comments\/[a-z0-9]+/i.test(parsed.pathname)) {
    const error = new Error('A Reddit post URL is required.');
    error.status = 400;
    throw error;
  }
  parsed.hostname = 'www.reddit.com';
  parsed.pathname = `${parsed.pathname.replace(/\/+$/, '')}.json`;
  parsed.search = '';
  parsed.searchParams.set('raw_json', '1');
  return parsed.toString();
}

function shapePost(raw = {}) {
  const data = raw.data || raw;
  return {
    id: data.id || null,
    title: data.title || '',
    subreddit: data.subreddit || '',
    author: data.author || '',
    text: compactText(data.selftext || data.selftext_html || '', 4000),
    url: data.permalink ? `https://www.reddit.com${data.permalink}` : data.url || '',
    outboundUrl: data.url_overridden_by_dest || null,
    score: data.score ?? null,
    comments: data.num_comments ?? null,
    createdAt: data.created_utc ? new Date(Number(data.created_utc) * 1000).toISOString() : null,
  };
}

function shapeComment(raw = {}) {
  const data = raw.data || raw;
  return {
    id: data.id || null,
    author: data.author || '',
    text: compactText(data.body || data.body_html || '', 2000),
    score: data.score ?? null,
    createdAt: data.created_utc ? new Date(Number(data.created_utc) * 1000).toISOString() : null,
  };
}

class RedditChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('reddit'));
  }

  async check() {
    return {
      ...(await super.check()),
      activeBackend: 'reddit_public_json',
      message: 'Reads and searches public Reddit posts when Reddit allows anonymous JSON access.',
    };
  }

  async read({ url, limit, signal }) {
    const data = await fetchJson(postUrlForJson(url), { signal });
    const post = shapePost(data?.[0]?.data?.children?.[0]);
    const comments = (data?.[1]?.data?.children || [])
      .filter((item) => item?.kind === 't1')
      .slice(0, normalizeLimit(limit, 20, 100))
      .map(shapeComment);
    return {
      platform: this.id,
      post,
      comments,
      source: 'reddit_public_json',
    };
  }

  async search({ query, limit, signal }) {
    const q = String(query || '').trim();
    if (!q) {
      const error = new Error('query is required.');
      error.status = 400;
      throw error;
    }
    const url = `https://www.reddit.com/search.json?q=${encodeURIComponent(q)}&limit=${normalizeLimit(limit, 10, 50)}&raw_json=1`;
    const data = await fetchJson(url, { signal });
    return {
      platform: this.id,
      query: q,
      results: (data?.data?.children || []).map(shapePost),
      source: 'reddit_public_json',
    };
  }
}

module.exports = {
  RedditChannel,
};
