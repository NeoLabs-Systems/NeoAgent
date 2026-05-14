'use strict';

const { SocialVideoAdapter } = require('./base');

class XAdapter extends SocialVideoAdapter {
  constructor() {
    super({
      platform: 'x',
      hosts: ['x.com', 'twitter.com'],
      captionLanguages: ['en', 'en-us'],
    });
  }
}

module.exports = {
  XAdapter,
};
