'use strict';

const { GithubChannel } = require('./github');
const { LinkedinChannel } = require('./linkedin');
const { RssChannel } = require('./rss');
const { UnsupportedChannel } = require('./unsupported');
const { V2exChannel } = require('./v2ex');
const { WebChannel } = require('./web');
const { XueqiuChannel } = require('./xueqiu');
const { YoutubeChannel } = require('./youtube');

function createChannels() {
  return [
    new GithubChannel(),
    new YoutubeChannel(),
    new RssChannel(),
    new V2exChannel(),
    new XueqiuChannel(),
    new LinkedinChannel(),
    new UnsupportedChannel('twitter'),
    new UnsupportedChannel('reddit'),
    new UnsupportedChannel('facebook'),
    new UnsupportedChannel('instagram'),
    new UnsupportedChannel('bilibili'),
    new UnsupportedChannel('xiaohongshu'),
    new UnsupportedChannel('xiaoyuzhou'),
    new UnsupportedChannel('exa_search'),
    new WebChannel(),
  ];
}

module.exports = {
  createChannels,
};
