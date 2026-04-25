'use strict';

const cron = require('node-cron');
const { findNextRun, parseCronExpression } = require('../schedule_utils');

function normalizeRunAt(value) {
  if (!value) return null;
  const date = new Date(value);
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
  async validateConfig(config = {}) {
    const mode = String(config.mode || '').trim() || ((config.runAt || config.run_at) ? 'one_time' : 'recurring');
    if (!['recurring', 'one_time'].includes(mode)) {
      throw new Error('Schedule trigger mode must be "recurring" or "one_time".');
    }
    if (mode === 'one_time') {
      const runAt = normalizeRunAt(config.runAt || config.run_at);
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
    };
  },
  summarize(config = {}) {
    if (config.mode === 'one_time') {
      return config.runAt ? `One-time at ${config.runAt}` : 'One-time';
    }
    return String(config.cronExpression || '').trim() || 'Recurring schedule';
  },
  nextRun(config = {}) {
    if (config.mode === 'one_time') return config.runAt || null;
    try {
      return findNextRun(config.cronExpression)?.toISOString() || null;
    } catch {
      return null;
    }
  },
};
