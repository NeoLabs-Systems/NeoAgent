'use strict';

const { EXTENSION_COMMANDS } = require('../browser/extension/protocol');
const { createChannels } = require('./channels');
const { deleteCookieBundle, getCookieSummary, writeCookieBundle } = require('./store');
const { domainsForPlatform, getPlatformDefinition, normalizePlatformId } = require('./platforms');
const { assertHttpUrl } = require('./utils');

const COOKIE_IMPORT_PLATFORMS = new Set(['xueqiu']);
const MAX_IMPORTED_COOKIES = 80;
const MAX_COOKIE_NAME_CHARS = 256;
const MAX_COOKIE_VALUE_CHARS = 4096;

function shapeError(error) {
  return {
    error: error?.message || String(error),
    status: error?.status || 500,
  };
}

function sanitizeCookies(cookies = [], allowedDomains = []) {
  const allowed = allowedDomains.map((domain) => String(domain || '').toLowerCase()).filter(Boolean);
  return (Array.isArray(cookies) ? cookies : [])
    .filter((cookie) => cookie && cookie.name && cookie.value != null)
    .filter((cookie) => String(cookie.name).length <= MAX_COOKIE_NAME_CHARS)
    .filter((cookie) => String(cookie.value).length <= MAX_COOKIE_VALUE_CHARS)
    .filter((cookie) => {
      const domain = String(cookie.domain || '').replace(/^\./, '').toLowerCase();
      return allowed.some((item) => domain === item || domain.endsWith(`.${item}`));
    })
    .slice(0, MAX_IMPORTED_COOKIES)
    .map((cookie) => ({
      name: String(cookie.name),
      value: String(cookie.value),
      domain: String(cookie.domain || ''),
      path: String(cookie.path || '/'),
      secure: cookie.secure === true,
      httpOnly: cookie.httpOnly === true,
      sameSite: cookie.sameSite || null,
      expirationDate: cookie.expirationDate || cookie.expires || null,
    }));
}

class SocialReachService {
  constructor(options = {}) {
    this.browserExtensionRegistry = options.browserExtensionRegistry || null;
    this.channels = createChannels();
    this.channelById = new Map(this.channels.map((channel) => [channel.id, channel]));
  }

  getChannel(platform) {
    const id = normalizePlatformId(platform);
    return this.channelById.get(id) || null;
  }

  detectChannelForUrl(url) {
    const parsed = assertHttpUrl(url);
    return this.channels.find((channel) => channel.id !== 'web' && channel.canHandleUrl(parsed.toString()))
      || this.getChannel('web');
  }

  async getStatus(userId) {
    const statuses = [];
    for (const channel of this.channels) {
      try {
        const status = await channel.check({ userId });
        if (!status.cookie && channel.setupKind === 'cookies') {
          status.cookie = getCookieSummary(userId, channel.id);
        }
        statuses.push(status);
      } catch (error) {
        statuses.push({
          platform: channel.id,
          label: channel.label,
          ready: false,
          status: 'error',
          activeBackend: null,
          tier: channel.tier,
          setupKind: channel.setupKind,
          message: error?.message || String(error),
        });
      }
    }
    return {
      platforms: statuses,
      generatedAt: new Date().toISOString(),
    };
  }

  async read(userId, args = {}) {
    const platform = normalizePlatformId(args.platform || '');
    const channel = platform ? this.getChannel(platform) : this.detectChannelForUrl(args.url);
    if (!channel) {
      const error = new Error(`Unsupported social reach platform: ${platform || 'unknown'}`);
      error.status = 400;
      throw error;
    }
    return channel.read({ ...args, userId });
  }

  async search(userId, args = {}) {
    const platform = normalizePlatformId(args.platform || '');
    const channel = this.getChannel(platform);
    if (!channel) {
      const error = new Error('platform is required and must be supported.');
      error.status = 400;
      throw error;
    }
    return channel.search({ ...args, userId });
  }

  async importCookiesFromExtension(userId, platform, options = {}) {
    const id = normalizePlatformId(platform);
    const definition = getPlatformDefinition(id);
    if (!definition || !COOKIE_IMPORT_PLATFORMS.has(id)) {
      const error = new Error(`${definition?.label || id || 'Platform'} does not support cookie import yet.`);
      error.status = 400;
      throw error;
    }
    if (!this.browserExtensionRegistry || typeof this.browserExtensionRegistry.dispatch !== 'function') {
      const error = new Error('Chrome extension registry is unavailable.');
      error.status = 503;
      throw error;
    }
    const domains = domainsForPlatform(id);
    const response = await this.browserExtensionRegistry.dispatch(userId, EXTENSION_COMMANDS.GET_COOKIES, {
      platform: id,
      domains,
      tokenId: options.tokenId || null,
    }, {
      tokenId: options.tokenId || null,
      timeoutMs: 15000,
    });
    const cookies = sanitizeCookies(response?.cookies || [], domains);
    if (cookies.length === 0) {
      const error = new Error(`No ${definition.label} cookies were found in the connected Chrome profile. Log in first, then import again.`);
      error.status = 422;
      throw error;
    }
    const bundle = writeCookieBundle(userId, id, { cookies });
    return {
      platform: id,
      configured: true,
      count: cookies.length,
      importedAt: bundle.importedAt,
    };
  }

  clearCookies(userId, platform) {
    const id = normalizePlatformId(platform);
    deleteCookieBundle(userId, id);
    return { platform: id, configured: false, count: 0 };
  }

  shapeError(error) {
    return shapeError(error);
  }
}

module.exports = {
  SocialReachService,
  sanitizeCookies,
};
