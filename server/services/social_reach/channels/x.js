'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { assertHttpUrl, compactText, fetchJson } = require('../utils');

function extractStatusId(url) {
  const parsed = assertHttpUrl(url);
  const host = parsed.hostname.toLowerCase().replace(/^www\./, '');
  if (host !== 'x.com' && host !== 'twitter.com') return null;
  const match = parsed.pathname.match(/\/status(?:es)?\/(\d+)/i);
  return match ? match[1] : null;
}

class XChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('x'));
  }

  canHandleUrl(url) {
    return Boolean(extractStatusId(url));
  }

  async check() {
    return {
      ...(await super.check()),
      activeBackend: 'x_syndication_public',
      message: 'Reads public X post links when X allows anonymous access.',
    };
  }

  async read({ url }) {
    const id = extractStatusId(url);
    if (!id) {
      const error = new Error('A public X post URL is required.');
      error.status = 400;
      throw error;
    }

    const data = await fetchJson(`https://cdn.syndication.twimg.com/tweet-result?id=${encodeURIComponent(id)}&lang=en`);
    return {
      platform: this.id,
      id,
      title: compactText(data.text || '', 120),
      text: compactText(data.text || '', 4000),
      author: data.user ? {
        name: data.user.name || '',
        screenName: data.user.screen_name || '',
        profileImageUrl: data.user.profile_image_url_https || null,
      } : null,
      createdAt: data.created_at || null,
      photos: (data.photos || []).map((photo) => ({
        url: photo.url || photo.expandedUrl || '',
        width: photo.width || null,
        height: photo.height || null,
      })),
      videos: (data.video?.variants || []).map((video) => ({
        url: video.src || video.url || '',
        contentType: video.type || video.content_type || '',
        bitrate: video.bitrate || null,
      })),
      url: `https://x.com/i/web/status/${id}`,
      source: 'x_syndication_public',
    };
  }
}

module.exports = {
  XChannel,
};
