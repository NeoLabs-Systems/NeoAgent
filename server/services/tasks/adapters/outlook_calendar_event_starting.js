'use strict';

const { connectionConfig, summaryParts } = require('./shared');
const { minutesBefore, startingPoll } = require('./calendar_starting');

module.exports = {
  type: 'outlook_calendar_event_starting',
  label: 'Outlook Calendar Event Starting',
  providerKey: 'microsoft_365',
  appKey: 'calendar',
  configHint: '{ connectionId, minutesBefore?: 0-1440 (default 10) }; all-day events are skipped',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'microsoft_365', 'calendar'),
      minutesBefore: minutesBefore(config),
    };
  },
  summarize(config = {}) {
    return summaryParts('Outlook Calendar', [`${config.minutesBefore} min before events`]);
  },
  poll: startingPoll(async (tool, config, window) => {
    const response = await tool('microsoft_365_calendar_list_events', {
      start: window.start,
      end: window.end,
      top: 20,
    });
    return response?.upcomingTimedEvents || [];
  }, 'outlook_calendar'),
};
