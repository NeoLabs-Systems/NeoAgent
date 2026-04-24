'use strict';

const MINUTE_MS = 60 * 1000;
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
  const minute = date.getUTCMinutes();
  const hour = date.getUTCHours();
  const dayOfMonth = date.getUTCDate();
  const month = date.getUTCMonth() + 1;
  const dayOfWeek = date.getUTCDay();

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

function getMinimumIntervalMinutes(expression, occurrenceCount = 3) {
  const matches = [];
  let cursor = new Date();
  for (let index = 0; index < occurrenceCount; index += 1) {
    const next = findNextRun(expression, cursor);
    if (!next) {
      break;
    }
    matches.push(next);
    cursor = new Date(next.getTime());
  }
  if (matches.length < 2) {
    return null;
  }

  let minInterval = Number.POSITIVE_INFINITY;
  for (let index = 1; index < matches.length; index += 1) {
    const intervalMinutes = Math.round((matches[index].getTime() - matches[index - 1].getTime()) / MINUTE_MS);
    if (intervalMinutes < minInterval) {
      minInterval = intervalMinutes;
    }
  }

  return Number.isFinite(minInterval) ? minInterval : null;
}

module.exports = {
  findNextRun,
  getMinimumIntervalMinutes,
  matchesCron,
  parseCronExpression,
};
