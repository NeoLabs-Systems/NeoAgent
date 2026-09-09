'use strict';

const { CALENDAR_APP } = require('./constants');
const { davRequest, parseCredentials } = require('./client');
const { buildEventIcs, parseDavResponses, parseEvent, toCalDavUtc } = require('./dav');
const {
  davCalendarsPath,
  hrefToRemotePath,
  normalizeRemotePath,
  requireText,
  text,
} = require('./network');

const CALENDAR_TOOLS = Object.freeze([
  {
    name: 'nextcloud_list_calendars',
    access: 'read',
    description: 'List CalDAV calendars for the connected Nextcloud account.',
    parameters: { type: 'object', properties: {} },
  },
  {
    name: 'nextcloud_list_events',
    access: 'read',
    description: 'List events in a Nextcloud calendar. Defaults to the next 30 days when start/end are omitted.',
    parameters: {
      type: 'object',
      properties: {
        calendar: { type: 'string', description: 'Calendar path from nextcloud_list_calendars.' },
        start: { type: 'string', description: 'Inclusive ISO-8601 lower bound.' },
        end: { type: 'string', description: 'Exclusive ISO-8601 upper bound.' },
      },
      required: ['calendar'],
    },
  },
  {
    name: 'nextcloud_get_event',
    access: 'read',
    description: 'Get one Nextcloud calendar event by calendar path and event path or uid.',
    parameters: {
      type: 'object',
      properties: {
        calendar: { type: 'string', description: 'Calendar path.' },
        event_path: { type: 'string', description: 'Event href path, for example personal/event.ics.' },
      },
      required: ['calendar', 'event_path'],
    },
  },
  {
    name: 'nextcloud_create_event',
    access: 'write',
    description: 'Create a Nextcloud calendar event.',
    parameters: {
      type: 'object',
      properties: {
        calendar: { type: 'string', description: 'Calendar path.' },
        summary: { type: 'string', description: 'Event title.' },
        start: { type: 'string', description: 'Start ISO datetime or YYYY-MM-DD.' },
        end: { type: 'string', description: 'End ISO datetime or YYYY-MM-DD.' },
        description: { type: 'string', description: 'Event description.' },
        location: { type: 'string', description: 'Event location.' },
      },
      required: ['calendar', 'summary', 'start', 'end'],
    },
  },
  {
    name: 'nextcloud_update_event',
    access: 'write',
    description: 'Replace a Nextcloud calendar event. Include the full replacement fields.',
    parameters: {
      type: 'object',
      properties: {
        calendar: { type: 'string', description: 'Calendar path.' },
        event_path: { type: 'string', description: 'Existing event path.' },
        summary: { type: 'string', description: 'Event title.' },
        start: { type: 'string', description: 'Start ISO datetime or YYYY-MM-DD.' },
        end: { type: 'string', description: 'End ISO datetime or YYYY-MM-DD.' },
        description: { type: 'string', description: 'Event description.' },
        location: { type: 'string', description: 'Event location.' },
        uid: { type: 'string', description: 'Optional UID to preserve.' },
      },
      required: ['calendar', 'event_path', 'summary', 'start', 'end'],
    },
  },
  {
    name: 'nextcloud_delete_event',
    access: 'write',
    description: 'Delete a Nextcloud calendar event.',
    parameters: {
      type: 'object',
      properties: {
        calendar: { type: 'string', description: 'Calendar path.' },
        event_path: { type: 'string', description: 'Event path from nextcloud_list_events.' },
      },
      required: ['calendar', 'event_path'],
    },
  },
].map((tool) => Object.freeze({ ...tool, appId: CALENDAR_APP.id })));

function calendarPrefix(username) {
  return `/remote.php/dav/calendars/${username}/`;
}

function eventHref(username, calendar, eventPath) {
  const relative = normalizeRemotePath(eventPath);
  if (relative.includes('/')) return davCalendarsPath(username, relative);
  return davCalendarsPath(username, `${normalizeRemotePath(calendar)}/${relative}`);
}

async function executeCalendarTool(toolName, args, credentials, options = {}) {
  const auth = parseCredentials(credentials);
  const signal = options.signal || null;
  const prefix = calendarPrefix(auth.username);

  switch (toolName) {
    case 'nextcloud_list_calendars': {
      const { text: xml } = await davRequest(auth, `${davCalendarsPath(auth.username, '')}/`, {
        method: 'PROPFIND',
        headers: { Depth: '1', 'Content-Type': 'application/xml; charset=utf-8' },
        body: `<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:displayname/><d:resourcetype/></d:prop>
</d:propfind>`,
        signal,
      });
      const calendars = parseDavResponses(xml)
        .filter((entry) => entry.ok && entry.isCalendar)
        .map((entry) => ({
          path: hrefToRemotePath(entry.href, prefix),
          name: text(entry.displayName) || hrefToRemotePath(entry.href, prefix),
        }))
        .filter((entry) => entry.path);
      return { result: calendars };
    }
    case 'nextcloud_list_events': {
      const start = args.start ? toCalDavUtc(args.start) : toCalDavUtc(new Date().toISOString());
      const end = args.end
        ? toCalDavUtc(args.end)
        : toCalDavUtc(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString());
      const { text: xml } = await davRequest(auth, davCalendarsPath(auth.username, args.calendar), {
        method: 'REPORT',
        headers: { Depth: '1', 'Content-Type': 'application/xml; charset=utf-8' },
        body: `<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data/></d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VEVENT">
        <c:time-range start="${start}" end="${end}"/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>`,
        signal,
      });
      const events = parseDavResponses(xml)
        .filter((entry) => entry.ok && entry.calendarData)
        .map((entry) => ({
          path: hrefToRemotePath(entry.href, prefix),
          etag: text(entry.etag) || null,
          ...parseEvent(entry.calendarData),
        }));
      return { result: events };
    }
    case 'nextcloud_get_event': {
      const { text: ics } = await davRequest(auth, eventHref(auth.username, args.calendar, args.event_path), {
        method: 'GET',
        accept: 'text/calendar, */*',
        signal,
      });
      return {
        result: {
          path: hrefToRemotePath(eventHref(auth.username, args.calendar, args.event_path), prefix),
          ...parseEvent(ics),
        },
      };
    }
    case 'nextcloud_create_event': {
      const ics = buildEventIcs({
        summary: requireText(args.summary, 'summary'),
        start: args.start,
        end: args.end,
        description: args.description,
        location: args.location,
      });
      const uid = parseEvent(ics).uid;
      const eventPath = `${normalizeRemotePath(args.calendar)}/${uid}.ics`;
      await davRequest(auth, davCalendarsPath(auth.username, eventPath), {
        method: 'PUT',
        headers: { 'Content-Type': 'text/calendar; charset=utf-8' },
        body: ics,
        signal,
      });
      return { result: { path: eventPath, uid, summary: text(args.summary) } };
    }
    case 'nextcloud_update_event': {
      const currentPath = hrefToRemotePath(eventHref(auth.username, args.calendar, args.event_path), prefix);
      const uid = text(args.uid) || pathUid(currentPath);
      const ics = buildEventIcs({
        uid,
        summary: requireText(args.summary, 'summary'),
        start: args.start,
        end: args.end,
        description: args.description,
        location: args.location,
      });
      await davRequest(auth, eventHref(auth.username, args.calendar, args.event_path), {
        method: 'PUT',
        headers: { 'Content-Type': 'text/calendar; charset=utf-8' },
        body: ics,
        signal,
      });
      return { result: { path: currentPath, uid, summary: text(args.summary) } };
    }
    case 'nextcloud_delete_event':
      await davRequest(auth, eventHref(auth.username, args.calendar, args.event_path), {
        method: 'DELETE',
        signal,
      });
      return {
        result: {
          deleted: true,
          path: hrefToRemotePath(eventHref(auth.username, args.calendar, args.event_path), prefix),
        },
      };
    default:
      return null;
  }
}

function pathUid(eventPath) {
  const name = normalizeRemotePath(eventPath).split('/').filter(Boolean).pop() || '';
  return name.replace(/\.ics$/i, '');
}

module.exports = {
  CALENDAR_TOOLS,
  executeCalendarTool,
};
