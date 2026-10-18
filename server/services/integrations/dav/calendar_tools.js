'use strict';

const { buildEventIcs, parseDavResponses, parseEvent, parseEvents, toCalDavUtc } = require('./format');
const { encodePathSegments, hrefToRemotePath, normalizeRemotePath } = require('./paths');
const { requireText, trimText: text } = require('../../../utils/text');

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * CalDAV calendar tools for any integration that reaches a calendar home.
 * `execute` takes a store `{ home, request(path, options) }`: `home` is the
 * calendar home path ending in `/`, and `request` performs an authenticated
 * DAV request against it and resolves to `{ text }`.
 */
function createCalendarTools({ prefix, label, appId }) {
  const tools = Object.freeze([
    {
      name: `${prefix}_list_calendars`,
      access: 'read',
      description: `List CalDAV calendars for the connected ${label} account.`,
      parameters: { type: 'object', properties: {} },
    },
    {
      name: `${prefix}_list_events`,
      access: 'read',
      description: `List events in a ${label} calendar. Defaults to the next 30 days when start/end are omitted.`,
      parameters: {
        type: 'object',
        properties: {
          calendar: { type: 'string', description: `Calendar path from ${prefix}_list_calendars.` },
          start: { type: 'string', description: 'Inclusive ISO-8601 lower bound.' },
          end: { type: 'string', description: 'Exclusive ISO-8601 upper bound.' },
        },
        required: ['calendar'],
      },
    },
    {
      name: `${prefix}_get_event`,
      access: 'read',
      description: `Get one ${label} calendar event by calendar path and event path.`,
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
      name: `${prefix}_create_event`,
      access: 'write',
      description: `Create a ${label} calendar event.`,
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
      name: `${prefix}_update_event`,
      access: 'write',
      description: `Replace a ${label} calendar event. Include the full replacement fields.`,
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
      name: `${prefix}_delete_event`,
      access: 'write',
      description: `Delete a ${label} calendar event.`,
      parameters: {
        type: 'object',
        properties: {
          calendar: { type: 'string', description: 'Calendar path.' },
          event_path: { type: 'string', description: `Event path from ${prefix}_list_events.` },
        },
        required: ['calendar', 'event_path'],
      },
    },
  ].map((tool) => Object.freeze({ ...tool, appId })));
  const names = new Set(tools.map((tool) => tool.name));

  async function execute(toolName, args, store, options = {}) {
    if (!names.has(toolName)) return null;
    const signal = options.signal || null;
    const { home } = store;
    const pathIn = (relative) => `${home}${encodePathSegments(relative)}`;
    const eventHref = (calendar, eventPath) => {
      const relative = normalizeRemotePath(eventPath);
      return pathIn(relative.includes('/') ? relative : `${normalizeRemotePath(calendar)}/${relative}`);
    };
    const putEvent = (href, ics) => store.request(href, {
      method: 'PUT',
      headers: { 'Content-Type': 'text/calendar; charset=utf-8' },
      body: ics,
      signal,
    });

    switch (toolName.slice(prefix.length + 1)) {
      case 'list_calendars': {
        const { text: xml } = await store.request(home, {
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
            path: hrefToRemotePath(entry.href, home),
            name: text(entry.displayName) || hrefToRemotePath(entry.href, home),
          }))
          .filter((entry) => entry.path);
        return { result: calendars };
      }
      case 'list_events': {
        const start = toCalDavUtc(args.start || new Date().toISOString());
        const end = toCalDavUtc(args.end || new Date(Date.now() + 30 * DAY_MS).toISOString());
        const { text: xml } = await store.request(pathIn(args.calendar), {
          method: 'REPORT',
          headers: { Depth: '1', 'Content-Type': 'application/xml; charset=utf-8' },
          body: `<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data><c:expand start="${start}" end="${end}"/></c:calendar-data></d:prop>
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
          .flatMap((entry) => parseEvents(entry.calendarData).map((event) => ({
            path: hrefToRemotePath(entry.href, home),
            etag: text(entry.etag) || null,
            ...event,
          })));
        return { result: events };
      }
      case 'get_event': {
        const href = eventHref(args.calendar, args.event_path);
        const { text: ics } = await store.request(href, {
          method: 'GET',
          accept: 'text/calendar, */*',
          signal,
        });
        return { result: { path: hrefToRemotePath(href, home), ...parseEvent(ics) } };
      }
      case 'create_event': {
        const ics = buildEventIcs({
          summary: requireText(args.summary, 'summary'),
          start: args.start,
          end: args.end,
          description: args.description,
          location: args.location,
        });
        const uid = parseEvent(ics).uid;
        const eventPath = `${normalizeRemotePath(args.calendar)}/${uid}.ics`;
        await putEvent(pathIn(eventPath), ics);
        return { result: { path: eventPath, uid, summary: text(args.summary) } };
      }
      case 'update_event': {
        const href = eventHref(args.calendar, args.event_path);
        const currentPath = hrefToRemotePath(href, home);
        const uid = text(args.uid) || pathUid(currentPath);
        await putEvent(href, buildEventIcs({
          uid,
          summary: requireText(args.summary, 'summary'),
          start: args.start,
          end: args.end,
          description: args.description,
          location: args.location,
        }));
        return { result: { path: currentPath, uid, summary: text(args.summary) } };
      }
      case 'delete_event': {
        const href = eventHref(args.calendar, args.event_path);
        await store.request(href, { method: 'DELETE', signal });
        return { result: { deleted: true, path: hrefToRemotePath(href, home) } };
      }
      default:
        return null;
    }
  }

  return { tools, execute };
}

function pathUid(eventPath) {
  const name = normalizeRemotePath(eventPath).split('/').filter(Boolean).pop() || '';
  return name.replace(/\.ics$/i, '');
}

module.exports = { createCalendarTools };
