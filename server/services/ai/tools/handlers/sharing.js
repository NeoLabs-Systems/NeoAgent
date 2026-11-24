'use strict';

const handlers = {
  async share_web_page(args, ctx) {
    const { app, agentId, runtime, userId } = ctx;
    const shares = require('../../../web_shares');
    const baseUrl = app?.locals?.httpRuntimeConfig?.publicUrl || undefined;
    switch (String(args.action || '')) {
      case 'share':
        return shares.shareWebPage({ userId, agentId, runtime: runtime(), name: args.name, port: args.port, baseUrl });
      case 'stop':
        return shares.stopSharingWebPage({ userId, ref: args.name });
      case 'list':
        return { shared_pages: shares.listShares(userId, { baseUrl }) };
      default:
        return { error: 'action must be share, stop or list.' };
    }
  },
};

module.exports = { handlers };
