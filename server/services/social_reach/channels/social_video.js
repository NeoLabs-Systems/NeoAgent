'use strict';

const { getPlatformDefinition } = require('../platforms');
const { SocialReachChannel } = require('./base');
const { normalizeAndDetectPlatform } = require('../../social_video/url');
const { createAbortError } = require('../../../utils/abort');

const PLATFORM_LABELS = Object.freeze({
  youtube: 'YouTube',
  tiktok: 'TikTok',
  instagram: 'Instagram/Reels',
  x: 'X',
});

class SocialVideoReachChannel extends SocialReachChannel {
  constructor(options = {}) {
    super(getPlatformDefinition('social_video'));
    this.socialVideoService = options.socialVideoService || null;
  }

  canHandleUrl(url) {
    try {
      normalizeAndDetectPlatform(url);
      return true;
    } catch {
      return false;
    }
  }

  async check({ signal } = {}) {
    if (!this.socialVideoService || typeof this.socialVideoService.getHealthStatus !== 'function') {
      return {
        ...(await super.check()),
        ready: false,
        status: 'warn',
        activeBackend: null,
        message: 'Social video extraction is not connected right now.',
      };
    }

    const health = await this.socialVideoService.getHealthStatus({ signal }).catch((error) => {
      if (signal?.aborted) throw createAbortError(signal);
      return {
        ready: false,
        dependencies: [],
        error: error.message || String(error),
      };
    });
    const missing = (health.dependencies || [])
      .filter((item) => !item.available)
      .map((item) => item.name)
      .filter(Boolean);

    return {
      ...(await super.check()),
      ready: health.ready === true,
      status: health.ready === true ? 'ok' : 'warn',
      activeBackend: 'social_video_extractor',
      message: health.ready === true
        ? 'Reads YouTube, TikTok, Instagram/Reels, and X video links with the existing social video extractor.'
        : `Install ${missing.join(' and ') || 'the video tools'} to extract social video links.`,
      setup: health,
    };
  }

  async read({ userId, url, include_frame: includeFrame, force_stt: forceStt, agentId, signal }) {
    if (!this.socialVideoService || typeof this.socialVideoService.extractFromUrl !== 'function') {
      const error = new Error('Social video extraction is not connected right now.');
      error.status = 503;
      throw error;
    }
    const detected = normalizeAndDetectPlatform(url);
    const result = await this.socialVideoService.extractFromUrl(userId, detected.normalizedUrl, {
      includeFrame: includeFrame !== false,
      forceStt: forceStt === true,
      agentId: agentId || null,
      signal,
    });
    return {
      ...result,
      platform: this.id,
      videoPlatform: detected.platform,
      label: PLATFORM_LABELS[detected.platform] || detected.platform,
      source: 'social_video_extractor',
    };
  }
}

module.exports = {
  SocialVideoReachChannel,
};
