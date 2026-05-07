'use strict';

const DEFAULT_MIXPANEL_TOKEN = '4a47ae6a05cf39a8faf0438a1200dde6';

function normalizeToken(value) {
  return String(value || '').trim();
}

function resolveMixpanelToken() {
  if (Object.prototype.hasOwnProperty.call(process.env, 'NEOAGENT_MIXPANEL_TOKEN')) {
    return normalizeToken(process.env.NEOAGENT_MIXPANEL_TOKEN);
  }
  return normalizeToken(DEFAULT_MIXPANEL_TOKEN);
}

function getAnalyticsConfig() {
  const mixpanelToken = resolveMixpanelToken();
  return {
    mixpanel: {
      enabled: mixpanelToken.length > 0,
      token: mixpanelToken || null,
    },
  };
}

module.exports = {
  DEFAULT_MIXPANEL_TOKEN,
  getAnalyticsConfig,
  resolveMixpanelToken,
};
