'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { assertHttpUrl, compactText, fetchJson, fetchText } = require('../utils');

class YoutubeChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('youtube'));
  }

  async check() {
    return {
      ...(await super.check()),
      activeBackend: 'youtube_oembed_jina',
      message: 'Node-only mode supports public metadata and readable page text. Caption extraction is not available without non-Node tooling.',
    };
  }

  async read({ url }) {
    const parsed = assertHttpUrl(url);
    const [oembed, page] = await Promise.all([
      fetchJson(`https://www.youtube.com/oembed?url=${encodeURIComponent(parsed.toString())}&format=json`).catch(() => null),
      fetchText(`https://r.jina.ai/${parsed.toString()}`, { headers: { accept: 'text/plain' } }).catch(() => ''),
    ]);
    return {
      platform: this.id,
      url: parsed.toString(),
      title: oembed?.title || null,
      author: oembed?.author_name || null,
      thumbnailUrl: oembed?.thumbnail_url || null,
      content: compactText(page, 12000),
      transcript: null,
      source: 'youtube_oembed_jina',
      limitation: 'Transcript extraction is unavailable in Node-only mode.',
    };
  }
}

module.exports = {
  YoutubeChannel,
};
