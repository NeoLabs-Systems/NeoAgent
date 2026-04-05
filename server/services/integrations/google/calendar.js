'use strict';

const { google } = require('googleapis');
const { coerceStringList } = require('./common');

const calendarToolDefinitions = [
  {
    name: 'google_workspace_calendar_list_events',
    description: 'List or search Google Calendar events for the connected account.',
    parameters: {
      type: 'object',
      properties: {
        calendar_id: {
          type: 'string',
          description: 'Calendar ID, defaults to primary.',
        },
        query: {
          type: 'string',
          description: 'Optional full-text event search query.',
        },
        time_min: { type: 'string', description: 'ISO datetime lower bound.' },
        time_max: { type: 'string', description: 'ISO datetime upper bound.' },
        max_results: {
          type: 'number',
          description: 'Maximum events to return (default 10).',
        },
      },
    },
  },
  {
    name: 'google_workspace_calendar_create_event',
    description: 'Create a Google Calendar event.',
    parameters: {
      type: 'object',
      properties: {
        calendar_id: {
          type: 'string',
          description: 'Calendar ID, defaults to primary.',
        },
        summary: { type: 'string', description: 'Event title.' },
        description: { type: 'string', description: 'Event description.' },
        location: { type: 'string', description: 'Event location.' },
        start: { type: 'string', description: 'Start ISO datetime.' },
        end: { type: 'string', description: 'End ISO datetime.' },
        timezone: {
          type: 'string',
          description: 'IANA timezone for start/end values.',
        },
        attendees: {
          type: 'array',
          items: { type: 'string' },
          description: 'Attendee email addresses.',
        },
      },
      required: ['summary', 'start', 'end'],
    },
  },
  {
    name: 'google_workspace_calendar_update_event',
    description: 'Update fields on an existing Google Calendar event.',
    parameters: {
      type: 'object',
      properties: {
        calendar_id: {
          type: 'string',
          description: 'Calendar ID, defaults to primary.',
        },
        event_id: { type: 'string', description: 'Event ID.' },
        summary: { type: 'string', description: 'Updated event title.' },
        description: { type: 'string', description: 'Updated description.' },
        location: { type: 'string', description: 'Updated location.' },
        start: { type: 'string', description: 'Updated start ISO datetime.' },
        end: { type: 'string', description: 'Updated end ISO datetime.' },
        timezone: {
          type: 'string',
          description: 'IANA timezone for updated start/end values.',
        },
        attendees: {
          type: 'array',
          items: { type: 'string' },
          description: 'Replacement attendee email list.',
        },
      },
      required: ['event_id'],
    },
  },
  {
    name: 'google_workspace_calendar_delete_event',
    description: 'Delete a Google Calendar event.',
    parameters: {
      type: 'object',
      properties: {
        calendar_id: {
          type: 'string',
          description: 'Calendar ID, defaults to primary.',
        },
        event_id: { type: 'string', description: 'Event ID.' },
      },
      required: ['event_id'],
    },
  },
  {
    name: 'google_workspace_calendar_free_busy',
    description: 'Check Google Calendar free/busy windows across calendars.',
    parameters: {
      type: 'object',
      properties: {
        calendar_ids: {
          type: 'array',
          items: { type: 'string' },
          description: 'Calendar IDs to query, defaults to primary.',
        },
        time_min: { type: 'string', description: 'ISO datetime lower bound.' },
        time_max: { type: 'string', description: 'ISO datetime upper bound.' },
        timezone: { type: 'string', description: 'IANA timezone label.' },
      },
      required: ['time_min', 'time_max'],
    },
  },
];

function summarizeEvent(event) {
  return {
    id: event.id || '',
    status: event.status || null,
    summary: event.summary || '',
    description: event.description || null,
    location: event.location || null,
    htmlLink: event.htmlLink || null,
    start: event.start?.dateTime || event.start?.date || null,
    end: event.end?.dateTime || event.end?.date || null,
    attendees: Array.isArray(event.attendees)
      ? event.attendees.map((attendee) => attendee.email).filter(Boolean)
      : [],
  };
}

async function executeCalendarTool(toolName, args, auth) {
  const calendar = google.calendar({ version: 'v3', auth });
  const calendarId = String(args.calendar_id || 'primary').trim() || 'primary';

  switch (toolName) {
    case 'google_workspace_calendar_list_events': {
      const response = await calendar.events.list({
        calendarId,
        q: String(args.query || '').trim() || undefined,
        timeMin: args.time_min || undefined,
        timeMax: args.time_max || undefined,
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: Math.max(1, Math.min(Number(args.max_results) || 10, 50)),
      });
      const items = Array.isArray(response.data.items) ? response.data.items : [];
      return { count: items.length, events: items.map(summarizeEvent) };
    }

    case 'google_workspace_calendar_create_event': {
      const response = await calendar.events.insert({
        calendarId,
        requestBody: {
          summary: String(args.summary || ''),
          description: args.description || undefined,
          location: args.location || undefined,
          start: {
            dateTime: String(args.start || ''),
            ...(args.timezone ? { timeZone: String(args.timezone) } : {}),
          },
          end: {
            dateTime: String(args.end || ''),
            ...(args.timezone ? { timeZone: String(args.timezone) } : {}),
          },
          attendees: coerceStringList(args.attendees).map((email) => ({ email })),
        },
      });
      return summarizeEvent(response.data);
    }

    case 'google_workspace_calendar_update_event': {
      const existing = await calendar.events.get({
        calendarId,
        eventId: String(args.event_id || ''),
      });
      const next = existing.data || {};
      if (args.summary !== undefined) next.summary = String(args.summary || '');
      if (args.description !== undefined) next.description = args.description || '';
      if (args.location !== undefined) next.location = args.location || '';
      if (args.start !== undefined) {
        next.start = {
          dateTime: String(args.start || ''),
          ...(args.timezone ? { timeZone: String(args.timezone) } : {}),
        };
      }
      if (args.end !== undefined) {
        next.end = {
          dateTime: String(args.end || ''),
          ...(args.timezone ? { timeZone: String(args.timezone) } : {}),
        };
      }
      if (args.attendees !== undefined) {
        next.attendees = coerceStringList(args.attendees).map((email) => ({
          email,
        }));
      }
      const response = await calendar.events.update({
        calendarId,
        eventId: String(args.event_id || ''),
        requestBody: next,
      });
      return summarizeEvent(response.data);
    }

    case 'google_workspace_calendar_delete_event': {
      await calendar.events.delete({
        calendarId,
        eventId: String(args.event_id || ''),
      });
      return { deleted: true, eventId: String(args.event_id || '') };
    }

    case 'google_workspace_calendar_free_busy': {
      const calendarIds = coerceStringList(args.calendar_ids);
      const response = await calendar.freebusy.query({
        requestBody: {
          timeMin: String(args.time_min || ''),
          timeMax: String(args.time_max || ''),
          timeZone: args.timezone || undefined,
          items:
            calendarIds.length > 0
              ? calendarIds.map((id) => ({ id }))
              : [{ id: 'primary' }],
        },
      });
      return { calendars: response.data.calendars || {} };
    }

    default:
      return null;
  }
}

module.exports = {
  calendarToolDefinitions,
  executeCalendarTool,
};
