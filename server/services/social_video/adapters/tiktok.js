'use strict';

const { SocialVideoAdapter } = require('./base');

class TikTokAdapter extends SocialVideoAdapter {
  constructor() {
    super({
      platform: 'tiktok',
      hosts: ['tiktok.com', 'www.tiktok.com', 'm.tiktok.com', 'vm.tiktok.com', 'vt.tiktok.com'],
      captionLanguages: ['en', 'en-us'],
    });
  }
}

module.exports = {
  TikTokAdapter,
};
