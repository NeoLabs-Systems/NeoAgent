'use strict';

const PLATFORM_DEFINITIONS = Object.freeze({
  rss: {
    id: 'rss',
    label: 'RSS / Atom',
    tier: 0,
    setupKind: 'none',
    hosts: [],
    domains: [],
  },
  v2ex: {
    id: 'v2ex',
    label: 'V2EX',
    tier: 0,
    setupKind: 'none',
    hosts: ['v2ex.com', 'www.v2ex.com'],
    domains: ['v2ex.com'],
  },
  github: {
    id: 'github',
    label: 'GitHub',
    tier: 0,
    setupKind: 'optional_auth',
    hosts: ['github.com', 'www.github.com'],
    domains: ['github.com'],
  },
  social_video: {
    id: 'social_video',
    label: 'Social video links',
    tier: 0,
    setupKind: 'none',
    hosts: [
      'youtube.com',
      'www.youtube.com',
      'youtu.be',
      'tiktok.com',
      'www.tiktok.com',
      'instagram.com',
      'www.instagram.com',
      'instagr.am',
      'x.com',
      'www.x.com',
      'twitter.com',
      'www.twitter.com',
    ],
    domains: ['youtube.com', 'youtu.be', 'tiktok.com', 'instagram.com', 'x.com', 'twitter.com'],
  },
  xueqiu: {
    id: 'xueqiu',
    label: 'Xueqiu',
    tier: 1,
    setupKind: 'cookies',
    hosts: ['xueqiu.com', 'www.xueqiu.com', 'stock.xueqiu.com'],
    domains: ['xueqiu.com'],
  },
  x: {
    id: 'x',
    label: 'X / Twitter',
    tier: 2,
    setupKind: 'cookies',
    hosts: ['x.com', 'twitter.com', 'www.x.com', 'www.twitter.com'],
    domains: ['x.com', 'twitter.com'],
  },
  reddit: {
    id: 'reddit',
    label: 'Reddit',
    tier: 2,
    setupKind: 'none',
    hosts: ['reddit.com', 'www.reddit.com', 'old.reddit.com'],
    domains: ['reddit.com'],
  },
});

function normalizePlatformId(value) {
  const id = String(value || '').trim().toLowerCase().replace(/[^a-z0-9_]+/g, '_');
  if (id === 'twitter') return 'x';
  if (id === 'youtube' || id === 'tiktok' || id === 'instagram' || id === 'reels') return 'social_video';
  return id;
}

function getPlatformDefinition(platform) {
  return PLATFORM_DEFINITIONS[normalizePlatformId(platform)] || null;
}

function listPlatformDefinitions() {
  return Object.values(PLATFORM_DEFINITIONS);
}

function hostMatchesPlatform(hostname, platform) {
  const definition = getPlatformDefinition(platform);
  if (!definition) return false;
  const host = String(hostname || '').toLowerCase().replace(/^www\./, '');
  return definition.hosts.some((candidate) => {
    const normalized = candidate.toLowerCase().replace(/^www\./, '');
    return host === normalized || host.endsWith(`.${normalized}`);
  });
}

function domainsForPlatform(platform) {
  const definition = getPlatformDefinition(platform);
  return definition ? [...definition.domains] : [];
}

module.exports = {
  PLATFORM_DEFINITIONS,
  domainsForPlatform,
  getPlatformDefinition,
  hostMatchesPlatform,
  listPlatformDefinitions,
  normalizePlatformId,
};
