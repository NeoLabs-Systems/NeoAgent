'use strict';

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const {
  normalizeTimeZone,
  utcOffsetMinutes,
  wallClockToDate,
} = require('../../../server/utils/timezone');
const { findNextRun } = require('../../../server/services/tasks/schedule_utils');

describe('user time zones', () => {
  test('normalizes known zones and rejects unknown ones', () => {
    assert.equal(normalizeTimeZone(' Europe/Berlin '), 'Europe/Berlin');
    assert.equal(normalizeTimeZone('Mars/Olympus'), null);
    assert.equal(normalizeTimeZone(''), null);
  });

  test('reports offsets across daylight saving time', () => {
    assert.equal(utcOffsetMinutes('Europe/Berlin', new Date('2026-01-15T12:00:00Z')), 60);
    assert.equal(utcOffsetMinutes('Europe/Berlin', new Date('2026-07-15T12:00:00Z')), 120);
    assert.equal(utcOffsetMinutes('Asia/Kathmandu', new Date('2026-07-15T12:00:00Z')), 345);
  });

  test('resolves a wall-clock time to the matching instant', () => {
    const summer = wallClockToDate(Date.parse('2026-07-15T08:00:00Z'), 'America/New_York');
    assert.equal(summer.toISOString(), '2026-07-15T12:00:00.000Z');
    const winter = wallClockToDate(Date.parse('2026-01-15T08:00:00Z'), 'America/New_York');
    assert.equal(winter.toISOString(), '2026-01-15T13:00:00.000Z');
  });

  test('cron occurrences follow the user wall clock', () => {
    const from = new Date('2026-03-27T12:00:00Z');
    assert.equal(
      findNextRun('0 8 * * *', from, 'Europe/Berlin').toISOString(),
      '2026-03-28T07:00:00.000Z',
    );
    // Berlin switches to summer time on 2026-03-29, moving 08:00 an hour earlier in UTC.
    assert.equal(
      findNextRun('0 8 * * *', new Date('2026-03-28T08:00:00Z'), 'Europe/Berlin').toISOString(),
      '2026-03-29T06:00:00.000Z',
    );
    assert.equal(
      findNextRun('30 9 * * 1', from, 'Asia/Tokyo').toISOString(),
      '2026-03-30T00:30:00.000Z',
    );
  });
});
