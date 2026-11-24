'use strict';

const handlers = {
  async read_health_data(args, ctx) {
    const { userId } = ctx;
    const { readHealthData } = require('../../../health/ingestion');
    const result = readHealthData(userId, args.metric_type, args.limit);
    return result;
  },

  async social_video_extract(args, ctx) {
    const { agentId, signal, socialVideo, userId } = ctx;
    const service = socialVideo();
    if (!service || typeof service.extractFromUrl !== 'function') {
    return { error: 'Social video extraction service is unavailable.' };
    }
    const sourceUrl = String(args.url || '').trim();
    if (!sourceUrl) {
    return { error: 'url is required' };
    }
    return await service.extractFromUrl(userId, sourceUrl, {
    includeFrame: args.include_frame !== false,
    forceStt: args.force_stt === true,
    agentId,
    signal,
    });
  },

  async social_reach_status(args, ctx) {
    const { signal, socialReach, userId } = ctx;
    const service = socialReach();
    if (!service || typeof service.getStatus !== 'function') {
    return { error: 'Social reach service is unavailable.' };
    }
    return await service.getStatus(userId, { signal });
  },

  async social_reach_read(args, ctx) {
    const { signal, socialReach, userId } = ctx;
    const service = socialReach();
    if (!service || typeof service.read !== 'function') {
    return { error: 'Social reach service is unavailable.' };
    }
    return await service.read(userId, args || {}, { signal });
  },

  async social_reach_search(args, ctx) {
    const { signal, socialReach, userId } = ctx;
    const service = socialReach();
    if (!service || typeof service.search !== 'function') {
    return { error: 'Social reach service is unavailable.' };
    }
    return await service.search(userId, args || {}, { signal });
  },
};

module.exports = { handlers };
