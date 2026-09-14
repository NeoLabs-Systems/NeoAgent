'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  finalizeListedCalendarEvents,
} = require('../../../server/services/integrations/calendar_window');

test('finalizeListedCalendarEvents omits overlapping timed events unless include_ongoing is set', () => {
  const events = [
    { start: '2026-08-30T15:00:00Z', end: '2026-08-30T17:00:00Z', allDay: false, summary: 'overlap' },
    { start: '2026-08-30T16:30:00Z', end: '2026-08-30T17:00:00Z', allDay: false, summary: 'upcoming' },
    { start: '2026-08-30', allDay: true, summary: 'all day' },
  ];
  const listed = finalizeListedCalendarEvents(events, {
    timeMin: '2026-08-30T16:00:00Z',
    timeMax: '2026-08-30T18:00:00Z',
    args: {},
  });
  assert.equal(listed.events.map((event) => event.summary).join(','), 'upcoming');
  assert.equal(listed.omittedOngoingTimedCount, 1);
  assert.equal(listed.omittedAllDayCount, 1);

  const overlapping = finalizeListedCalendarEvents(events, {
    timeMin: '2026-08-30T16:00:00Z',
    timeMax: '2026-08-30T18:00:00Z',
    args: { include_ongoing: true, include_all_day: true },
  });
  assert.equal(overlapping.events.length, 3);
});
