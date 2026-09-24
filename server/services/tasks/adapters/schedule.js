'use strict';

const cron = require('node-cron');
const { findNextRun, parseCronExpression } = require('../schedule_utils');
const { getUserTimeZone } = require('../../account/timezone');
const { wallClockToDate } = require('../../../utils/timezone');

const ZONELESS_DATETIME_RE = /^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?$/;

// A datetime without an offset is the user's wall-clock time, not the server's.
function normalizeRunAt(value, timeZone) {
  if (!value) return null;
  const raw = String(value).trim();
  const date = timeZone && ZONELESS_DATETIME_RE.test(raw)
    ? wallClockToDate(Date.parse(`${raw.replace(' ', 'T')}Z`), timeZone)
    : new Date(raw);
  if (Number.isNaN(date.getTime())) {
    throw new Error('A valid runAt datetime is required.');
  }
  return date.toISOString();
}

function normalizeCronExpression(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    throw new Error('A valid cron expression is required.');
  }

  const fields = raw.split(/\s+/);
  if (fields.length === 6) {
    const seconds = String(fields[0] || '').trim();
    if (seconds !== '0' && seconds !== '*') {
      throw new Error('Cron expressions with seconds are not supported. Use a 5-field expression.');
    }
    fields.shift();
  }

  if (fields.length !== 5) {
    throw new Error('A valid cron expression is required.');
  }

  // Quartz-style "?" means "no specific value"; convert to standard wildcard.
  if (fields[2] === '?') fields[2] = '*';
  if (fields[4] === '?') fields[4] = '*';

  const normalized = fields.join(' ');
  parseCronExpression(normalized);
  if (!cron.validate(normalized)) {
    throw new Error('A valid cron expression is required.');
  }
  return normalized;
}

module.exports = {
  type: 'schedule',
  label: 'Schedule',
  async validateConfig(config = {}, context = {}) {
    const mode = String(config.mode || '').trim() || ((config.runAt || config.run_at) ? 'one_time' : 'recurring');
    if (!['recurring', 'one_time'].includes(mode)) {
      throw new Error('Schedule trigger mode must be "recurring" or "one_time".');
    }
    if (mode === 'one_time') {
      const runAt = normalizeRunAt(config.runAt || config.run_at, getUserTimeZone(context.userId));
      if (!runAt) {
        throw new Error('one_time schedule requires runAt');
      }
      return {
        mode,
        runAt,
      };
    }

    const cronExpression = normalizeCronExpression(config.cronExpression || config.cron_expression);
    return {
      mode,
      cronExpression,
      // When set, the run starts its measured average duration early so that it
      // finishes at the scheduled time instead of starting then.
      finishOnTime: config.finishOnTime === true || config.finish_on_time === true,
    };
  },
  summarize(config = {}) {
    if (config.mode === 'one_time') {
      return config.runAt ? `One-time at ${config.runAt}` : 'One-time';
    }
    return String(config.cronExpression || '').trim() || 'Recurring schedule';
  },
  nextRun(config = {}, timeZone = null) {
    if (config.mode === 'one_time') return config.runAt || null;
    try {
      return findNextRun(config.cronExpression, new Date(), timeZone)?.toISOString() || null;
    } catch {
      return null;
    }
  },
};
