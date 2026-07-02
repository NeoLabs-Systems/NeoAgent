'use strict';

const PLATFORM_DEFINITIONS = Object.freeze({
  web: {
    id: 'web',
    label: 'Web',
    tier: 0,
    setupKind: 'none',
    hosts: [],
    domains: [],
  },
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
  youtube: {
    id: 'youtube',
    label: 'YouTube',
    tier: 0,
    setupKind: 'none',
    hosts: ['youtube.com', 'www.youtube.com', 'youtu.be'],
    domains: ['youtube.com', 'youtu.be'],
  },
  linkedin: {
    id: 'linkedin',
    label: 'LinkedIn',
    tier: 2,
    setupKind: 'public_read_only',
    hosts: ['linkedin.com', 'www.linkedin.com'],
    domains: ['linkedin.com'],
  },
  xueqiu: {
    id: 'xueqiu',
    label: 'Xueqiu',
    tier: 1,
    setupKind: 'cookies',
    hosts: ['xueqiu.com', 'www.xueqiu.com', 'stock.xueqiu.com'],
    domains: ['xueqiu.com'],
  },
  twitter: {
    id: 'twitter',
    label: 'X / Twitter',
    tier: 2,
    setupKind: 'unsupported_node_only',
    hosts: ['x.com', 'twitter.com', 'www.x.com', 'www.twitter.com'],
    domains: ['x.com', 'twitter.com'],
  },
  reddit: {
    id: 'reddit',
    label: 'Reddit',
    tier: 2,
    setupKind: 'unsupported_node_only',
    hosts: ['reddit.com', 'www.reddit.com', 'old.reddit.com'],
    domains: ['reddit.com'],
  },
  facebook: {
    id: 'facebook',
    label: 'Facebook',
    tier: 2,
    setupKind: 'unsupported_node_only',
    hosts: ['facebook.com', 'www.facebook.com'],
    domains: ['facebook.com'],
  },
  instagram: {
    id: 'instagram',
    label: 'Instagram',
    tier: 2,
    setupKind: 'unsupported_node_only',
    hosts: ['instagram.com', 'www.instagram.com'],
    domains: ['instagram.com'],
  },
  bilibili: {
    id: 'bilibili',
    label: 'Bilibili',
    tier: 2,
    setupKind: 'unsupported_node_only',
    hosts: ['bilibili.com', 'www.bilibili.com', 'b23.tv'],
    domains: ['bilibili.com', 'b23.tv'],
  },
  xiaohongshu: {
    id: 'xiaohongshu',
    label: 'Xiaohongshu',
    tier: 2,
    setupKind: 'unsupported_node_only',
    hosts: ['xiaohongshu.com', 'www.xiaohongshu.com', 'xhslink.com'],
    domains: ['xiaohongshu.com', 'xhslink.com'],
  },
  xiaoyuzhou: {
    id: 'xiaoyuzhou',
    label: 'Xiaoyuzhou',
    tier: 2,
    setupKind: 'unsupported_node_only',
    hosts: ['xiaoyuzhoufm.com', 'www.xiaoyuzhoufm.com'],
    domains: ['xiaoyuzhoufm.com'],
  },
  exa_search: {
    id: 'exa_search',
    label: 'Exa Search',
    tier: 2,
    setupKind: 'unsupported_node_only',
    hosts: [],
    domains: [],
  },
});

function normalizePlatformId(value) {
  const id = String(value || '').trim().toLowerCase().replace(/[^a-z0-9_]+/g, '_');
  if (id === 'x') return 'twitter';
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
