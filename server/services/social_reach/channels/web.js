'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { assertHttpUrl, compactText, fetchText } = require('../utils');

class WebChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('web'));
  }

  canHandleUrl() {
    return true;
  }

  async check() {
    return {
      ...(await super.check()),
      activeBackend: 'jina_reader',
      message: 'Reads public web pages through Jina Reader.',
    };
  }

  async read({ url }) {
    const parsed = assertHttpUrl(url);
    const target = `https://r.jina.ai/${parsed.toString()}`;
    const text = await fetchText(target, { headers: { accept: 'text/plain' } });
    return {
      platform: this.id,
      url: parsed.toString(),
      title: null,
      content: compactText(text, 20000),
      source: 'jina_reader',
    };
  }
}

module.exports = {
  WebChannel,
};
