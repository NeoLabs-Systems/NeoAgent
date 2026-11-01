'use strict';

// Other agents' schedules → the five-field cron NeoAgent runs on.

// Interval in milliseconds → the closest 5-field cron expression. Returns
// { cron, exact } so the report can say when a schedule was rounded.
function intervalToCron(everyMs) {
  const minutes = Math.max(1, Math.round(Number(everyMs) / 60000));
  if (minutes < 60) {
    const step = [1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30].reduce((best, value) => (
      Math.abs(value - minutes) < Math.abs(best - minutes) ? value : best
    ), 1);
    return { cron: step === 1 ? '* * * * *' : `*/${step} * * * *`, exact: step === minutes };
  }
  const hours = Math.round(minutes / 60);
  if (hours < 24) {
    const step = [1, 2, 3, 4, 6, 8, 12].reduce((best, value) => (
      Math.abs(value - hours) < Math.abs(best - hours) ? value : best
    ), 1);
    return { cron: step === 1 ? '0 * * * *' : `0 */${step} * * *`, exact: step * 60 === minutes };
  }
  const days = Math.round(hours / 24);
  if (days === 7) return { cron: '0 9 * * 1', exact: minutes === 7 * 24 * 60 };
  return { cron: '0 9 * * *', exact: minutes === 24 * 60 };
}

// Six-field cron with a zero/any seconds field drops it; anything finer than
// a minute cannot be kept.
function toFiveFieldCron(expr) {
  const fields = String(expr || '').trim().split(/\s+/);
  if (fields.length === 5) return { cron: fields.join(' '), exact: true };
  if (fields.length === 6) {
    return { cron: fields.slice(1).join(' '), exact: fields[0] === '0' || fields[0] === '*' };
  }
  return null;
}

module.exports = {
  intervalToCron,
  toFiveFieldCron,
};
