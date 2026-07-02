'use strict';

const { GithubChannel } = require('./github');
const { RedditChannel } = require('./reddit');
const { RssChannel } = require('./rss');
const { SocialVideoReachChannel } = require('./social_video');
const { V2exChannel } = require('./v2ex');
const { XChannel } = require('./x');
const { XueqiuChannel } = require('./xueqiu');

function createChannels(options = {}) {
  return [
    new GithubChannel(),
    new XChannel(),
    new SocialVideoReachChannel({ socialVideoService: options.socialVideoService }),
    new RedditChannel(),
    new RssChannel(),
    new V2exChannel(),
    new XueqiuChannel(),
  ];
}

module.exports = {
  createChannels,
};
