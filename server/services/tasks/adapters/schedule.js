'use strict';

const cron = require('node-cron');
const { findNextRun } = require('../schedule_utils');

function normalizeRunAt(value) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error('A valid runAt datetime is required.');
  }
  return date.toISOString();
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

    const cronExpression = String(config.cronExpression || config.cron_expression || '').trim();
    if (!cronExpression || !cron.validate(cronExpression)) {
      throw new Error('A valid cron expression is required.');
    }
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
