'use strict';

const MINUTE_MS = 60 * 1000;
// A head start is capped so that a single pathological run (a task that once
// took hours) cannot drag every future occurrence arbitrarily far forward.
const MAX_LEAD_TIME_MS = 60 * 60 * 1000;
// How many recent completed runs feed the average used for the head start.
const RUN_SAMPLE_SIZE = 10;
const MONTH_NAMES = new Map([
  ['jan', 1],
  ['feb', 2],
  ['mar', 3],
  ['apr', 4],
  ['may', 5],
  ['jun', 6],
  ['jul', 7],
  ['aug', 8],
  ['sep', 9],
  ['oct', 10],
  ['nov', 11],
  ['dec', 12],
]);
const WEEKDAY_NAMES = new Map([
  ['sun', 0],
  ['mon', 1],
  ['tue', 2],
  ['wed', 3],
  ['thu', 4],
  ['fri', 5],
  ['sat', 6],
]);

function normalizeCronValue(raw, names = null) {
  const value = String(raw || '').trim().toLowerCase();
  if (names?.has(value)) {
    return names.get(value);
  }
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed)) {
    throw new Error(`Invalid cron value "${raw}"`);
  }
  return parsed;
}

function addRange(values, start, end, step, min, max, fieldName) {
  if (!Number.isInteger(start) || !Number.isInteger(end)) {
    throw new Error(`Invalid ${fieldName} range`);
  }
  if (start > end) {
    throw new Error(`Invalid ${fieldName} range "${start}-${end}"`);
  }
  if (start < min || end > max) {
    throw new Error(`${fieldName} range "${start}-${end}" is out of bounds`);
  }
  for (let current = start; current <= end; current += step) {
    values.add(current);
  }
}

function parseCronField(field, { min, max, fieldName, names = null, normalize = null }) {
  const raw = String(field || '').trim();
  if (!raw) {
    throw new Error(`Missing ${fieldName} field`);
  }

  const values = new Set();
  const wildcard = raw === '*';
  const parts = raw.split(',');

  for (const part of parts) {
    const segment = part.trim();
    if (!segment) continue;

    const [rangePart, stepPart] = segment.split('/');
    const step = stepPart == null ? 1 : Number.parseInt(stepPart, 10);
    if (!Number.isInteger(step) || step <= 0) {
      throw new Error(`Invalid ${fieldName} step "${stepPart}"`);
    }

    if (rangePart === '*') {
      addRange(values, min, max, step, min, max, fieldName);
      continue;
    }

    if (rangePart.includes('-')) {
      const [startRaw, endRaw] = rangePart.split('-', 2);
      let start = normalizeCronValue(startRaw, names);
      let end = normalizeCronValue(endRaw, names);
      if (typeof normalize === 'function') {
        start = normalize(start);
        end = normalize(end);
      }
      addRange(values, start, end, step, min, max, fieldName);
      continue;
    }

    let value = normalizeCronValue(rangePart, names);
    if (typeof normalize === 'function') {
      value = normalize(value);
    }
    if (value < min || value > max) {
      throw new Error(`${fieldName} value "${rangePart}" is out of bounds`);
    }
    values.add(value);
  }

  return { wildcard, values };
}

function parseCronExpression(expression) {
  const fields = String(expression || '').trim().split(/\s+/);
  if (fields.length !== 5) {
    throw new Error(`Invalid cron expression "${expression}"`);
  }

  return {
    minute: parseCronField(fields[0], {
      min: 0,
      max: 59,
      fieldName: 'minute',
    }),
    hour: parseCronField(fields[1], {
      min: 0,
      max: 23,
      fieldName: 'hour',
    }),
    dayOfMonth: parseCronField(fields[2], {
      min: 1,
      max: 31,
      fieldName: 'day-of-month',
    }),
    month: parseCronField(fields[3], {
      min: 1,
      max: 12,
      fieldName: 'month',
      names: MONTH_NAMES,
    }),
    dayOfWeek: parseCronField(fields[4], {
      min: 0,
      max: 6,
      fieldName: 'day-of-week',
      names: WEEKDAY_NAMES,
      normalize: (value) => (value === 7 ? 0 : value),
    }),
  };
}

function matchesCron(date, schedule) {
  const minute = date.getMinutes();
  const hour = date.getHours();
  const dayOfMonth = date.getDate();
  const month = date.getMonth() + 1;
  const dayOfWeek = date.getDay();

  if (!schedule.minute.values.has(minute)) return false;
  if (!schedule.hour.values.has(hour)) return false;
  if (!schedule.month.values.has(month)) return false;

  const domMatch = schedule.dayOfMonth.values.has(dayOfMonth);
  const dowMatch = schedule.dayOfWeek.values.has(dayOfWeek);

  if (schedule.dayOfMonth.wildcard && schedule.dayOfWeek.wildcard) {
    return true;
  }
  if (schedule.dayOfMonth.wildcard) {
    return dowMatch;
  }
  if (schedule.dayOfWeek.wildcard) {
    return domMatch;
  }
  return domMatch || dowMatch;
}

function floorToMinute(date) {
  return new Date(Math.floor(date.getTime() / MINUTE_MS) * MINUTE_MS);
}

function findNextRun(expression, fromDate = new Date(), maxLookaheadMinutes = 366 * 24 * 60) {
  const schedule = parseCronExpression(expression);
  const cursor = floorToMinute(fromDate);
  cursor.setUTCSeconds(0, 0);

  for (let index = 1; index <= maxLookaheadMinutes; index += 1) {
    const candidate = new Date(cursor.getTime() + (index * MINUTE_MS));
    if (matchesCron(candidate, schedule)) {
      return candidate;
    }
  }
  return null;
}

// How long before its scheduled time a run must start so that it finishes at
// that time: its measured average duration. Returns 0 when there is no usable
// history yet, which keeps the task starting at its configured time.
function resolveLeadTimeMs(averageRunSeconds) {
  const averageSeconds = Number(averageRunSeconds);
  if (!Number.isFinite(averageSeconds) || averageSeconds <= 0) return 0;
  return Math.min(Math.round(averageSeconds * 1000), MAX_LEAD_TIME_MS);
}

module.exports = {
  MINUTE_MS,
  RUN_SAMPLE_SIZE,
  findNextRun,
  matchesCron,
  parseCronExpression,
  resolveLeadTimeMs,
};
