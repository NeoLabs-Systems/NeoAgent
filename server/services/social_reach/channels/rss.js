'use strict';

const cheerio = require('cheerio');
const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { assertHttpUrl, compactText, fetchText, normalizeLimit } = require('../utils');

function firstText($, item, names) {
  for (const name of names) {
    const value = $(item).find(name).first().text().trim();
    if (value) return value;
  }
  return '';
}

class RssChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('rss'));
  }

  canHandleUrl(url) {
    const text = String(url || '').toLowerCase();
    return /(?:\/feed\b|\/rss\b|\.xml\b|atom)/.test(text);
  }

  async check() {
    return {
      ...(await super.check()),
      activeBackend: 'node_xml',
      message: 'Reads RSS and Atom feeds with the built-in Node parser.',
    };
  }

  async read({ url, limit, signal }) {
    const parsed = assertHttpUrl(url);
    const xml = await fetchText(parsed.toString(), { publicOnly: true, signal });
    const $ = cheerio.load(xml, { xmlMode: true });
    const entries = $('item, entry').toArray().slice(0, normalizeLimit(limit, 20, 100));
    const title = $('channel > title, feed > title').first().text().trim() || null;
    return {
      platform: this.id,
      url: parsed.toString(),
      title,
      items: entries.map((item) => ({
        title: firstText($, item, ['title']),
        url: firstText($, item, ['link']) || $(item).find('link').first().attr('href') || '',
        summary: compactText(firstText($, item, ['description', 'summary', 'content']), 1200),
        author: firstText($, item, ['author name', 'author', 'dc\\:creator']),
        publishedAt: firstText($, item, ['pubDate', 'published', 'updated']),
      })),
      source: 'rss',
    };
  }
}

module.exports = {
  RssChannel,
};
