'use strict';

const { SocialVideoAdapter } = require('./base');

class InstagramAdapter extends SocialVideoAdapter {
  constructor() {
    super({
      platform: 'instagram',
      hosts: ['instagram.com', 'www.instagram.com', 'm.instagram.com', 'instagr.am'],
      captionLanguages: ['en', 'en-us'],
    });
  }
}

module.exports = {
  InstagramAdapter,
};
