'use strict';

const { connectionConfig } = require('./shared');

module.exports = {
  type: 'phone_alarm',
  label: 'Phone Alarm',
  providerKey: 'phone',
  appKey: 'alarms',
  configHint: '{ connectionId }; runs when the next shared Android alarm is due',
  async validateConfig(config = {}, context = {}) {
    return connectionConfig(config, context, 'phone', 'alarms');
  },
  summarize() {
    return 'Phone alarm';
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'ordered',
    baseline: 'now',
    initialCheckpoint: () => new Date().toISOString(),
    async fetchRows({ tool, now }) {
      const result = await tool('phone_list_alarms');
      return (result?.alarms || [])
        .filter((alarm) => Date.parse(alarm.time) <= now)
        .map((alarm) => ({
          fingerprint: `${alarm.time}|alarm`,
          timestamp: alarm.time,
          context: { triggerEvent: { provider: 'phone', event: 'alarm', time: alarm.time } },
        }))
        .sort((a, b) => a.fingerprint.localeCompare(b.fingerprint));
    },
  },
};
