'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeTrimmedText,
} = require('../security');

const WEATHER_EVENT_TYPES = new Set([
  'rain_start',
  'snow_start',
  'wind_alert',
  'temperature_above',
  'temperature_below',
]);

function normalizeNumber(value, fallback) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function normalizeEventTypes(value) {
  const raw = Array.isArray(value)
    ? value
    : String(value || '')
        .split(',')
        .map((entry) => entry.trim())
        .filter(Boolean);
  const normalized = raw
    .map((entry) => String(entry || '').trim().toLowerCase())
    .filter((entry) => WEATHER_EVENT_TYPES.has(entry));
  return Array.from(new Set(normalized));
}

module.exports = {
  type: 'weather_event',
  label: 'Weather Event',
  providerKey: 'weather',
  appKey: 'forecast',
  async validateConfig(config = {}, context = {}) {
    const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
      userId: context.userId,
      agentId: context.agentId,
      connectionId: config.connectionId || config.connection_id,
      providerKey: 'weather',
      appKey: 'forecast',
    });

    const eventTypes = normalizeEventTypes(config.eventTypes || config.event_types);
    if (eventTypes.length === 0) {
      throw new Error(
        'At least one weather event type is required: rain_start, snow_start, wind_alert, temperature_above, temperature_below.',
      );
    }

    const location = normalizeTrimmedText(
      config.location || config.locationQuery || config.query,
      180,
    );
    if (!location) {
      throw new Error('Weather event location is required (for example: Berlin, DE).');
    }

    return {
      connectionId: connection.id,
      accountEmail: connection.account_email || null,
      location,
      eventTypes,
      minPrecipitationMm: normalizeNumber(config.minPrecipitationMm ?? config.min_precipitation_mm, 0.4),
      minSnowfallCm: normalizeNumber(config.minSnowfallCm ?? config.min_snowfall_cm, 0.2),
      windAlertKph: normalizeNumber(config.windAlertKph ?? config.wind_alert_kph, 40),
      temperatureAboveC: normalizeNumber(config.temperatureAboveC ?? config.temperature_above_c, 32),
      temperatureBelowC: normalizeNumber(config.temperatureBelowC ?? config.temperature_below_c, 0),
      horizonHours: Math.max(1, Math.min(Number(config.horizonHours || config.horizon_hours) || 12, 48)),
    };
  },
  summarize(config = {}) {
    const parts = ['Weather'];
    if (config.location) parts.push(config.location);
    if (Array.isArray(config.eventTypes) && config.eventTypes.length > 0) {
      parts.push(config.eventTypes.join(', '));
    }
    return parts.join(' · ');
  },
};
