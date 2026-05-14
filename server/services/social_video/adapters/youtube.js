'use strict';

const { SocialVideoAdapter } = require('./base');

class YouTubeAdapter extends SocialVideoAdapter {
  constructor() {
    super({
      platform: 'youtube',
      hosts: ['youtube.com', 'www.youtube.com', 'youtu.be'],
      captionLanguages: ['en', 'en-us', 'en-gb'],
    });
  }
}

module.exports = {
  YouTubeAdapter,
};
