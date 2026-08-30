'use strict';

const { google } = require('googleapis');
const { coerceStringList, executeGoogleApiRequest } = require('./common');
const {
  applyCalendarListMode,
  excludeStartedTimedEvents,
  partitionCalendarEvents,
} = require('../calendar_window');

const calendarToolDefinitions = [
  {
    name: 'google_workspace_calendar_list_events',
    access: 'read',
    description:
      'List or search Google Calendar events for the connected account. When time_min is supplied, the default starts_within_window mode returns only timed events whose real start is at or after time_min (and before time_max when present). Multi-day events that started earlier and merely overlap the window are omitted unless include_ongoing is true. All-day events are omitted unless include_all_day is true. For reminders about events starting soon, keep both options false and decide only from upcomingTimedEvents.',
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
        time_min: {
          type: 'string',
          description: 'RFC3339 lower bound for the overlap window. Also separates already-running timed events from events that start in the window.',
        },
        time_max: {
          type: 'string',
          description: 'RFC3339 exclusive upper bound for an event start.',
        },
        max_results: {
          type: 'number',
          description: 'Maximum events to return (default 10).',
        },
        include_ongoing: {
          type: 'boolean',
          description: 'Include timed events that started before time_min and are still running. Defaults to false for bounded windows.',
        },
        include_all_day: {
          type: 'boolean',
          description: 'Include all-day and multi-day date events. Defaults to false for bounded windows.',
        },
      },
    },
  },
  {
    name: 'google_workspace_calendar_create_event',
    access: 'write',
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
    access: 'write',
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
    access: 'write',
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
    access: 'read',
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
  {
    name: 'google_workspace_calendar_api_request',
    access: 'dynamic_http_method',
    description:
      'Make an authenticated Google Calendar API request for advanced calendar operations not covered by the dedicated tools.',
    parameters: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'HTTP method: GET, POST, PUT, PATCH, or DELETE.' },
        path: {
          type: 'string',
          description:
            'Calendar API path or URL, e.g. /calendar/v3/users/me/calendarList.',
        },
        query: { type: 'object', description: 'Optional query parameters.' },
        body: { type: 'object', description: 'Optional JSON request body.' },
      },
      required: ['method', 'path'],
    },
  },
];

function summarizeEvent(event) {
  // An event is all-day when it carries a `date` but no `dateTime`. Google returns
  // every all-day / multi-day event that *overlaps* the query window — recurring
  // birthdays, anniversaries, full-day markers — so a 1-hour "what's coming up"
  // query is easily flooded by them. Expose the flag so callers can tell a real
  // timed appointment apart from an all-day marker without re-querying.
  const isAllDay = Boolean(event.start?.date && !event.start?.dateTime);
  return {
    id: event.id || '',
    status: event.status || null,
    summary: event.summary || '',
    description: event.description || null,
    location: event.location || null,
    htmlLink: event.htmlLink || null,
    allDay: isAllDay,
    start: event.start?.dateTime || event.start?.date || null,
    end: event.end?.dateTime || event.end?.date || null,
    attendees: Array.isArray(event.attendees)
      ? event.attendees.map((attendee) => attendee.email).filter(Boolean)
      : [],
  };
}

function summarizeListedEvents(items, window = {}) {
  const events = Array.isArray(items) ? items.map(summarizeEvent) : [];
  return partitionCalendarEvents(events, window);
}

async function executeCalendarTool(toolName, args, auth, executionOptions = {}) {
  const calendar = google.calendar({ version: 'v3', auth });
  const calendarId = String(args.calendar_id || 'primary').trim() || 'primary';
  // Models sometimes emit camelCase timeMin/timeMax despite the snake_case
  // schema; accept either so a misnamed arg doesn't silently drop the window.
  const timeMin = args.time_min || args.timeMin || undefined;
  const timeMax = args.time_max || args.timeMax || undefined;

  switch (toolName) {
    case 'google_workspace_calendar_list_events': {
      if (
        (executionOptions.triggerSource === 'schedule' || executionOptions.triggerSource === 'tasks')
        && executionOptions.taskId
        && (!timeMin || !timeMax)
      ) {
        throw new Error(
          'Automatic calendar checks require both time_min and time_max. Query a bounded event-start window derived from the task schedule and requested reminder offset.',
        );
      }
      const response = await calendar.events.list({
        calendarId,
        q: String(args.query || '').trim() || undefined,
        timeMin,
        timeMax,
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: Math.max(1, Math.min(Number(args.max_results) || 10, 50)),
      });
      const items = Array.isArray(response.data.items) ? response.data.items : [];
      const summarizedItems = items.map(summarizeEvent);
      const automaticReminderEvents = (
        (executionOptions.triggerSource === 'schedule' || executionOptions.triggerSource === 'tasks')
        && executionOptions.taskId
        && args.include_ongoing !== true
      )
        ? excludeStartedTimedEvents(summarizedItems, executionOptions.scheduledAt)
        : summarizedItems;
      const summary = partitionCalendarEvents(automaticReminderEvents, { timeMin, timeMax });
      const hasWindowStart = Boolean(timeMin);
      return applyCalendarListMode(summary, {
        includeOngoing: !hasWindowStart || args.include_ongoing === true,
        includeAllDay: !hasWindowStart || args.include_all_day === true,
      });
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
          ...((args.timezone
            ? { timeZone: String(args.timezone) }
            : existing.data?.start?.timeZone
            ? { timeZone: existing.data.start.timeZone }
            : {})),
        };
      }
      if (args.end !== undefined) {
        next.end = {
          dateTime: String(args.end || ''),
          ...((args.timezone
            ? { timeZone: String(args.timezone) }
            : existing.data?.end?.timeZone
            ? { timeZone: existing.data.end.timeZone }
            : {})),
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
          timeMin: String(timeMin || ''),
          timeMax: String(timeMax || ''),
          timeZone: args.timezone || undefined,
          items:
            calendarIds.length > 0
              ? calendarIds.map((id) => ({ id }))
              : [{ id: 'primary' }],
        },
      });
      return { calendars: response.data.calendars || {} };
    }

    case 'google_workspace_calendar_api_request': {
      if (
        (executionOptions.triggerSource === 'schedule' || executionOptions.triggerSource === 'tasks')
        && executionOptions.taskId
        && String(args.method || 'GET').trim().toUpperCase() === 'GET'
        && /\/calendar\/v3\/calendars\/[^/]+\/events(?:\?|$)/i.test(String(args.path || ''))
      ) {
        throw new Error(
          'Automatic calendar checks must use google_workspace_calendar_list_events with explicit time_min and time_max bounds.',
        );
      }
      return executeGoogleApiRequest(auth, args, {
        baseUrl: 'https://www.googleapis.com',
      });
    }

    default:
      return null;
  }
}

module.exports = {
  calendarToolDefinitions,
  executeCalendarTool,
  summarizeEvent,
  summarizeListedEvents,
};
