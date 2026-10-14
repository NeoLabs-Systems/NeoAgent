'use strict';

const crypto = require('crypto');
const { normalizeTrimmedText } = require('../security');

// De-duplication keys off the fingerprint, so it identifies the notification
// rather than the delivery: a phone that retries sends identical fields.
function notificationFingerprint({ appPackage, title, body, actionTaken }) {
  const digest = crypto.createHash('sha256')
    .update(JSON.stringify([appPackage, title, body, actionTaken]))
    .digest('hex')
    .slice(0, 32);
  return `notification:${digest}`;
}

module.exports = {
  type: 'android_notification_received',
  label: 'Android Notification Received',
  configHint: '{ appPackage?: e.g. "com.whatsapp" }',
  async validateConfig(config = {}) {
    return {
      appPackage: normalizeTrimmedText(config.appPackage || config.app_package, 200),
    };
  },
  summarize(config = {}) {
    const parts = ['Android Notification'];
    if (config.appPackage) parts.push(`app: ${config.appPackage}`);
    return parts.join(' · ');
  },
  event: {
    source: 'runtime',
    name: 'android_notification',
    matches(config, event) {
      return !config.appPackage || config.appPackage === event.appPackage;
    },
    toPayload(event) {
      return {
        fingerprint: notificationFingerprint(event),
        timestamp: event.receivedAt,
        context: {
          triggerEvent: {
            provider: 'android_notification',
            appPackage: event.appPackage,
            title: event.title,
            body: event.body,
            actionTaken: event.actionTaken,
          },
        },
      };
    },
  },
};
