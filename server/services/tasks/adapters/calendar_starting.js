'use strict';

const { MINUTE_MS, boundedInteger, timeCursor } = require('./shared');

// A reminder that came due while the server was briefly away still goes out,
// as long as it is no older than this.
const CATCH_UP_MINUTES = 10;

function minutesBefore(config) {
  return boundedInteger(config.minutesBefore ?? config.minutes_before, 10, 0, 1440);
}

// Events whose reminder time falls in the catch-up window up to now.
function startingWindow(config, now) {
  const leadMs = config.minutesBefore * MINUTE_MS;
  return {
    start: new Date(now + leadMs - CATCH_UP_MINUTES * MINUTE_MS).toISOString(),
    end: new Date(now + leadMs + MINUTE_MS).toISOString(),
  };
}

// The cursor is the reminder time, so each event fires once, in order.
function startingRows(events, config, now, provider) {
  const leadMs = config.minutesBefore * MINUTE_MS;
  return events
    .filter((event) => event && !event.allDay && /T/.test(String(event.start || '')))
    .map((event) => {
      const startMs = Date.parse(event.start);
      const remindAt = startMs - leadMs;
      if (!Number.isFinite(startMs) || remindAt > now) return null;
      return {
        fingerprint: timeCursor(remindAt, event.id),
        timestamp: new Date(startMs).toISOString(),
        context: {
          triggerEvent: {
            provider,
            event: 'calendar_event_starting',
            eventId: event.id,
            title: event.summary || '',
            start: event.start,
            end: event.end || null,
            location: event.location || null,
            url: event.htmlLink || null,
            minutesBefore: config.minutesBefore,
          },
        },
      };
    })
    .filter((row) => row && row.fingerprint)
    .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
}

function startingPoll(fetchEvents, provider) {
  return {
    intervalMinutes: 1,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool, config, now }) {
      const events = await fetchEvents(tool, config, startingWindow(config, now));
      return startingRows(events, config, now, provider);
    },
  };
}

module.exports = {
  minutesBefore,
  startingPoll,
};
