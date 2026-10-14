'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, summaryParts } = require('./shared');
const { minutesBefore, startingPoll } = require('./calendar_starting');

module.exports = {
  type: 'google_calendar_event_starting',
  label: 'Google Calendar Event Starting',
  providerKey: 'google_workspace',
  appKey: 'calendar',
  configHint: '{ connectionId, minutesBefore?: 0-1440 (default 10), calendarId?: default primary }; all-day events are skipped',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'google_workspace', 'calendar'),
      calendarId: normalizeTrimmedText(config.calendarId || config.calendar_id, 300),
      minutesBefore: minutesBefore(config),
    };
  },
  summarize(config = {}) {
    return summaryParts('Google Calendar', [`${config.minutesBefore} min before events`, config.calendarId]);
  },
  poll: startingPoll(async (tool, config, window) => {
    const result = await tool('google_workspace_calendar_list_events', {
      calendar_id: config.calendarId || undefined,
      time_min: window.start,
      time_max: window.end,
      max_results: 20,
    });
    return result?.upcomingTimedEvents || [];
  }, 'google_calendar'),
};
