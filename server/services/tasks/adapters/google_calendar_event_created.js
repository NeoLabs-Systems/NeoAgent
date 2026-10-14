'use strict';

const { normalizeBoolean, normalizeTrimmedText } = require('../security');
const { MINUTE_MS, connectionConfig, summaryParts, timeCursor } = require('./shared');

const LOOKBACK_MINUTES = 60;

module.exports = {
  type: 'google_calendar_event_created',
  label: 'Google Calendar Event Created',
  providerKey: 'google_workspace',
  appKey: 'calendar',
  configHint: '{ connectionId, calendarId?: default primary, invitesOnly?: only events someone else organizes }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'google_workspace', 'calendar'),
      calendarId: normalizeTrimmedText(config.calendarId || config.calendar_id, 300),
      invitesOnly: normalizeBoolean(config.invitesOnly ?? config.invites_only, false),
    };
  },
  summarize(config = {}) {
    return summaryParts('Google Calendar new events', [config.calendarId, config.invitesOnly && 'invites only']);
  },
  poll: {
    intervalMinutes: 5,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool, config, now }) {
      const updatedMin = new Date(now - LOOKBACK_MINUTES * MINUTE_MS).toISOString();
      const calendarId = encodeURIComponent(config.calendarId || 'primary');
      const response = await tool('google_workspace_calendar_api_request', {
        method: 'GET',
        path: `/calendar/v3/calendars/${calendarId}/events`,
        query: { updatedMin, orderBy: 'updated', showDeleted: false, maxResults: 100 },
      });
      const items = Array.isArray(response?.data?.items) ? response.data.items : [];
      return items
        // Recently updated includes edits; only events created in the window are new.
        .filter((item) => item && item.status !== 'cancelled' && String(item.created || '') >= updatedMin)
        .filter((item) => !config.invitesOnly || item.organizer?.self !== true)
        .map((item) => ({
          fingerprint: timeCursor(item.created, item.id),
          timestamp: item.created,
          context: {
            triggerEvent: {
              provider: 'google_calendar',
              event: 'calendar_event_created',
              eventId: item.id,
              title: item.summary || '',
              start: item.start?.dateTime || item.start?.date || null,
              end: item.end?.dateTime || item.end?.date || null,
              location: item.location || null,
              organizer: item.organizer?.email || null,
              url: item.htmlLink || null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
