'use strict';

const { YouTubeAdapter } = require('./youtube');
const { TikTokAdapter } = require('./tiktok');
const { InstagramAdapter } = require('./instagram');
const { XAdapter } = require('./x');

const ADAPTERS = [
  new YouTubeAdapter(),
  new TikTokAdapter(),
  new InstagramAdapter(),
  new XAdapter(),
];

function getAdapterForPlatform(platform) {
  const normalized = String(platform || '').trim().toLowerCase();
  return ADAPTERS.find((adapter) => adapter.platform === normalized) || null;
}

function getSupportedAdapters() {
  return [...ADAPTERS];
}

module.exports = {
  getAdapterForPlatform,
  getSupportedAdapters,
};
