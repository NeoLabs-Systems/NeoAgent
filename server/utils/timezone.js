'use strict';

const partsFormatters = new Map();

// Returns the canonical IANA name for `value`, or null when it is not a zone
// this runtime knows.
function normalizeTimeZone(value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  try {
    return new Intl.DateTimeFormat('en-US', { timeZone: raw }).resolvedOptions().timeZone;
  } catch {
    return null;
  }
}

function serverTimeZone() {
  return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
}

function partsFormatter(timeZone) {
  let formatter = partsFormatters.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
    });
    partsFormatters.set(timeZone, formatter);
  }
  return formatter;
}

// Minutes to add to UTC to get wall-clock time in `timeZone` at `date`.
function utcOffsetMinutes(timeZone, date = new Date()) {
  const parts = {};
  for (const part of partsFormatter(timeZone).formatToParts(date)) {
    parts[part.type] = Number(part.value);
  }
  const wallClockAsUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
  const wholeSeconds = Math.floor(date.getTime() / 1000) * 1000;
  return Math.round((wallClockAsUtc - wholeSeconds) / 60000);
}

// Resolves a wall-clock time in `timeZone`, given as epoch milliseconds read as
// if the wall clock were UTC, to the real instant.
function wallClockToDate(wallClockAsUtcMs, timeZone) {
  const firstGuess = wallClockAsUtcMs - (utcOffsetMinutes(timeZone, new Date(wallClockAsUtcMs)) * 60000);
  return new Date(wallClockAsUtcMs - (utcOffsetMinutes(timeZone, new Date(firstGuess)) * 60000));
}

function formatUtcOffset(offsetMinutes) {
  const sign = offsetMinutes >= 0 ? '+' : '-';
  const abs = Math.abs(offsetMinutes);
  return `${sign}${String(Math.floor(abs / 60)).padStart(2, '0')}:${String(abs % 60).padStart(2, '0')}`;
}

module.exports = {
  formatUtcOffset,
  normalizeTimeZone,
  serverTimeZone,
  utcOffsetMinutes,
  wallClockToDate,
};
