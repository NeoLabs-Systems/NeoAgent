'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeTrimmedText,
} = require('../security');
const { sortByTimestamp } = require('./shared');

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
  configHint: '{ connectionId, location, eventTypes: [rain_start|snow_start|wind_alert|temperature_above|temperature_below], windAlertKph?, temperatureAboveC?, temperatureBelowC? }',
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
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const forecast = await tool('weather_get_forecast', {
        ...(config.location ? { location: config.location } : {}),
        forecast_hours: Math.max(1, Math.min(Number(config.horizonHours) || 12, 48)),
      });
      const hourly = Array.isArray(forecast?.hourly) ? forecast.hourly : [];
      const eventTypes = Array.isArray(config.eventTypes) ? config.eventTypes : [];
      const rows = [];

      for (let index = 0; index < hourly.length; index += 1) {
        const row = hourly[index] || {};
        const previous = index > 0 ? (hourly[index - 1] || {}) : null;
        const time = String(row.time || '').trim();
        if (!time) continue;

        const rain = Number(row.rain || row.precipitation || 0);
        const prevRain = Number(previous?.rain || previous?.precipitation || 0);
        const snowfall = Number(row.snowfall || 0);
        const prevSnow = Number(previous?.snowfall || 0);
        const windSpeed = Number(row.windSpeed || 0);
        const temperature = Number(row.temperature);

        const candidates = [
          {
            type: 'rain_start',
            active:
              eventTypes.includes('rain_start')
              && rain >= Number(config.minPrecipitationMm || 0.4)
              && prevRain < Number(config.minPrecipitationMm || 0.4),
          },
          {
            type: 'snow_start',
            active:
              eventTypes.includes('snow_start')
              && snowfall >= Number(config.minSnowfallCm || 0.2)
              && prevSnow < Number(config.minSnowfallCm || 0.2),
          },
          {
            type: 'wind_alert',
            active:
              eventTypes.includes('wind_alert')
              && windSpeed >= Number(config.windAlertKph || 40),
          },
          {
            type: 'temperature_above',
            active:
              eventTypes.includes('temperature_above')
              && Number.isFinite(temperature)
              && temperature >= Number(config.temperatureAboveC || 32),
          },
          {
            type: 'temperature_below',
            active:
              eventTypes.includes('temperature_below')
              && Number.isFinite(temperature)
              && temperature <= Number(config.temperatureBelowC || 0),
          },
        ];

        for (const candidate of candidates) {
          if (!candidate.active) continue;
          rows.push({
            fingerprint: `weather:${config.connectionId}:${candidate.type}:${time}`,
            timestamp: time,
            context: {
              triggerEvent: {
                provider: 'weather',
                eventType: candidate.type,
                location: forecast?.location?.label || config.location || null,
                time,
                rain,
                snowfall,
                windSpeed,
                temperature,
              },
            },
          });
        }
      }

      return rows.sort(sortByTimestamp);
    },
  },
};
