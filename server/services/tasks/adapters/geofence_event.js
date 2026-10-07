'use strict';

const { normalizeTrimmedText } = require('../security');
const { boundedInteger, optionalNumber, summaryParts } = require('./shared');

const TRANSITIONS = Object.freeze(['enter', 'exit']);

function coordinate(value, limit, name) {
  const numeric = optionalNumber(value);
  if (numeric === null || Math.abs(numeric) > limit) {
    throw new Error(`A valid ${name} is required.`);
  }
  return numeric;
}

// Each task is one fence. The phone fetches the fences of enabled tasks,
// checks its position, and reports entering or leaving one by its task ID.
module.exports = {
  type: 'geofence_event',
  label: 'Location Geofence',
  configHint: '{ label, latitude, longitude, radiusMeters?: 50-50000 (default 200), transition: enter|exit }; needs location tracking on the phone',
  async validateConfig(config = {}) {
    const transition = normalizeTrimmedText(config.transition, 10).toLowerCase() || 'enter';
    if (!TRANSITIONS.includes(transition)) {
      throw new Error('Geofence transition must be "enter" or "exit".');
    }
    return {
      label: normalizeTrimmedText(config.label, 120) || 'Place',
      latitude: coordinate(config.latitude, 90, 'latitude'),
      longitude: coordinate(config.longitude, 180, 'longitude'),
      radiusMeters: boundedInteger(config.radiusMeters ?? config.radius_meters, 200, 50, 50000),
      transition,
    };
  },
  summarize(config = {}) {
    return summaryParts(config.transition === 'exit' ? 'Leaving' : 'Arriving at', [
      config.label,
      `${config.radiusMeters} m`,
    ]);
  },
  event: {
    source: 'runtime',
    name: 'geofence',
    matches(config, event, task) {
      return Number(event.fenceId) === Number(task.id) && event.transition === config.transition;
    },
    toPayload(event, config) {
      return {
        fingerprint: `geofence:${event.fenceId}:${event.transition}:${event.occurredAt}`,
        timestamp: event.occurredAt,
        context: {
          triggerEvent: {
            provider: 'location',
            event: event.transition === 'exit' ? 'geofence_exited' : 'geofence_entered',
            label: config.label,
            latitude: event.latitude,
            longitude: event.longitude,
            occurredAt: event.occurredAt,
          },
        },
      };
    },
  },
};
