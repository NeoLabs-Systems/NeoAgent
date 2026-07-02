'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { assertHttpUrl, compactText, fetchText } = require('../utils');

class LinkedinChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('linkedin'));
  }

  async check() {
    return {
      ...(await super.check()),
      activeBackend: 'jina_reader_public',
      message: 'Public LinkedIn pages can be read through Jina Reader. Logged-in profile/job automation is unavailable in Node-only mode.',
    };
  }

  async read({ url }) {
    const parsed = assertHttpUrl(url);
    const text = await fetchText(`https://r.jina.ai/${parsed.toString()}`, { headers: { accept: 'text/plain' } });
    return {
      platform: this.id,
      url: parsed.toString(),
      content: compactText(text, 16000),
      source: 'jina_reader_public',
    };
  }
}

module.exports = {
  LinkedinChannel,
};
