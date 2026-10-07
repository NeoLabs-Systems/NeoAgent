'use strict';

const { connectionConfig, listFrom, requiredText, summaryParts } = require('./shared');
const { minutesBefore, startingPoll } = require('./calendar_starting');

module.exports = {
  type: 'nextcloud_calendar_event_starting',
  label: 'Nextcloud Calendar Event Starting',
  providerKey: 'nextcloud',
  appKey: 'calendar',
  configHint: '{ connectionId, calendar: path from nextcloud_list_calendars, minutesBefore?: 0-1440 (default 10) }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'nextcloud', 'calendar'),
      calendar: requiredText(config.calendar, 300, 'Nextcloud calendar is required.'),
      minutesBefore: minutesBefore(config),
    };
  },
  summarize(config = {}) {
    return summaryParts('Nextcloud Calendar', [config.calendar, `${config.minutesBefore} min before events`]);
  },
  poll: startingPoll(async (tool, config, window) => {
    const result = await tool('nextcloud_list_events', {
      calendar: config.calendar,
      start: window.start,
      end: window.end,
    });
    // Each occurrence of a recurring event shares its UID.
    return listFrom(result).map((event) => ({
      ...event,
      id: `${event.uid || event.path}${event.recurrenceId ? `@${event.recurrenceId}` : ''}`,
    }));
  }, 'nextcloud_calendar'),
};
