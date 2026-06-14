'use strict';

const { normalizeTrimmedText } = require('../security');

module.exports = {
  type: 'android_notification_received',
  label: 'Android Notification Received',
  async validateConfig(config = {}, context = {}) {
    return {
      appPackage: normalizeTrimmedText(config.appPackage || config.app_package, 200),
    };
  },
  summarize(config = {}) {
    const parts = ['Android Notification'];
    if (config.appPackage) parts.push(`app: ${config.appPackage}`);
    return parts.join(' · ');
  },
};
