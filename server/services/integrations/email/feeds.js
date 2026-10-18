'use strict';

const ICAL = require('ical.js');
const { executeSafeHttpRequest } = require('../../network/safe_request');
const { trimText: text } = require('../../../utils/text');

const FEED_APP = Object.freeze({
  id: 'calendar_feed',
  label: 'Calendar link',
  description: 'Read events from a calendar\'s iCal link (Google, Outlook, iCloud or any .ics address).',
});

const FEED_TOOLS = Object.freeze([
  {
    appId: FEED_APP.id,
    name: 'ical_list_events',
    access: 'read',
    description: 'List events from a calendar shared by its iCal link, repeating events expanded. Defaults to the next 7 days. Read-only.',
    parameters: {
      type: 'object',
      properties: {
        start: { type: 'string', description: 'Inclusive ISO lower bound.' },
        end: { type: 'string', description: 'Exclusive ISO upper bound.' },
        query: { type: 'string', description: 'Text to find in title, location or description.' },
      },
    },
  },
]);

const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_FEED_BYTES = 10 * 1024 * 1024;
const MAX_EVENTS = 500;
// Bounds the walk through a repeating event that started long ago.
const MAX_OCCURRENCES_PER_EVENT = 5000;

/** An iCal address as calendar apps give it; webcal:// is plain HTTPS. */
function normalizeFeedUrl(value) {
  const raw = text(value).replace(/^webcals?:\/\//i, 'https://');
  let url;
  try {
    url = new URL(raw);
  } catch {
    throw new Error('Paste the calendar\'s full iCal address.');
  }
  if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password) {
    throw new Error('The iCal address must start with https:// or webcal://.');
  }
  return url.toString();
}

/** Downloads and parses a feed; private-network and oversized feeds are refused. */
async function fetchFeed(url, signal) {
  const response = await executeSafeHttpRequest(
    { url, method: 'GET', headers: { accept: 'text/calendar, */*' } },
    { signal, maxResponseBytes: MAX_FEED_BYTES },
  );
  if (response.status < 200 || response.status >= 300) {
    throw new Error(`The calendar link answered ${response.status}. Check that the address is still shared.`);
  }
  if (response.truncated) throw new Error('This calendar is too large to read.');
  try {
    return new ICAL.Component(ICAL.parse(String(response.body || '')));
  } catch {
    throw new Error('That address did not return an iCal calendar.');
  }
}

function calendarName(calendar) {
  return text(calendar.getFirstPropertyValue('x-wr-calname'));
}

// All-day events stay plain dates; anything else is an instant in UTC.
function when(time) {
  return time.isDate ? time.toString() : time.toJSDate().toISOString();
}

function occurrence(details, name) {
  const item = details.item;
  return {
    calendar: name || null,
    title: text(item.summary),
    start: when(details.startDate),
    end: when(details.endDate),
    allDay: details.startDate.isDate,
    location: text(item.location) || null,
    notes: text(item.description).slice(0, 1000) || null,
  };
}

/** Every occurrence overlapping [start, end), soonest first. */
function eventsBetween(calendar, start, end) {
  const windowStart = ICAL.Time.fromJSDate(start, true);
  const windowEnd = ICAL.Time.fromJSDate(end, true);
  const name = calendarName(calendar);
  const components = calendar.getAllSubcomponents('vevent');
  const exceptions = components.filter((component) => component.hasProperty('recurrence-id'));
  const found = [];
  for (const component of components.filter((candidate) => !candidate.hasProperty('recurrence-id'))) {
    const event = new ICAL.Event(component);
    for (const exception of exceptions) {
      if (exception.getFirstPropertyValue('uid') === event.uid) event.relateException(exception);
    }
    if (!event.isRecurring()) {
      if (event.startDate && event.startDate.compare(windowEnd) < 0 && (event.endDate || event.startDate).compare(windowStart) > 0) {
        found.push(occurrence({ item: event, startDate: event.startDate, endDate: event.endDate || event.startDate }, name));
      }
      continue;
    }
    const iterator = event.iterator();
    for (let step = 0; step < MAX_OCCURRENCES_PER_EVENT; step += 1) {
      const next = iterator.next();
      if (!next || next.compare(windowEnd) >= 0) break;
      const details = event.getOccurrenceDetails(next);
      if (details.endDate.compare(windowStart) > 0) found.push(occurrence(details, name));
    }
  }
  return found.sort((left, right) => left.start.localeCompare(right.start)).slice(0, MAX_EVENTS);
}

function matches(event, query) {
  const needle = text(query).toLowerCase();
  return !needle || [event.title, event.location, event.notes].some((value) => text(value).toLowerCase().includes(needle));
}

function isoArg(value, name) {
  const date = new Date(text(value));
  if (Number.isNaN(date.getTime())) throw new Error(`${name} must be an ISO date or datetime.`);
  return date;
}

async function executeFeedTool(toolName, args, credentials, options = {}) {
  if (toolName !== 'ical_list_events') return null;
  const start = args.start ? isoArg(args.start, 'start') : new Date();
  const end = args.end ? isoArg(args.end, 'end') : new Date(start.getTime() + 7 * DAY_MS);
  const calendar = await fetchFeed(credentials.url, options.signal || null);
  return {
    result: {
      calendar: credentials.name,
      events: eventsBetween(calendar, start, end).filter((event) => matches(event, args.query)),
    },
  };
}

module.exports = {
  FEED_APP,
  FEED_TOOLS,
  calendarName,
  eventsBetween,
  executeFeedTool,
  fetchFeed,
  normalizeFeedUrl,
};
