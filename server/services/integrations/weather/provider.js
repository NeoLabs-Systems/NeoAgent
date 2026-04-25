'use strict';

const crypto = require('crypto');
const db = require('../../../db/database');
const { fetchJson } = require('../oauth_provider');

const WEATHER_APP = {
  id: 'forecast',
  label: 'Forecast',
  description: 'Public weather data from Open-Meteo (no API key required).',
};

const WEATHER_TOOL_DEFINITIONS = [
  {
    appId: WEATHER_APP.id,
    name: 'weather_search_locations',
    access: 'read',
    description: 'Search Open-Meteo locations by city or place name.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Location text like "Berlin" or "San Francisco".' },
        limit: { type: 'number', description: 'Maximum locations to return, default 5.' },
      },
      required: ['query'],
    },
  },
  {
    appId: WEATHER_APP.id,
    name: 'weather_get_current',
    access: 'read',
    description: 'Get current weather conditions for a location or coordinates.',
    parameters: {
      type: 'object',
      properties: {
        location: { type: 'string', description: 'Optional location name like "Tokyo".' },
        latitude: { type: 'number', description: 'Latitude, required with longitude if location is omitted.' },
        longitude: { type: 'number', description: 'Longitude, required with latitude if location is omitted.' },
      },
    },
  },
  {
    appId: WEATHER_APP.id,
    name: 'weather_get_forecast',
    access: 'read',
    description: 'Get hourly weather forecast for a location or coordinates.',
    parameters: {
      type: 'object',
      properties: {
        location: { type: 'string', description: 'Optional location name like "London".' },
        latitude: { type: 'number', description: 'Latitude, required with longitude if location is omitted.' },
        longitude: { type: 'number', description: 'Longitude, required with latitude if location is omitted.' },
        forecast_hours: { type: 'number', description: 'Forecast horizon in hours (1-72), default 24.' },
      },
    },
  },
];

const WEATHER_CODE_LABELS = {
  0: 'Clear sky',
  1: 'Mainly clear',
  2: 'Partly cloudy',
  3: 'Overcast',
  45: 'Fog',
  48: 'Depositing rime fog',
  51: 'Light drizzle',
  53: 'Moderate drizzle',
  55: 'Dense drizzle',
  56: 'Light freezing drizzle',
  57: 'Dense freezing drizzle',
  61: 'Slight rain',
  63: 'Moderate rain',
  65: 'Heavy rain',
  66: 'Light freezing rain',
  67: 'Heavy freezing rain',
  71: 'Slight snowfall',
  73: 'Moderate snowfall',
  75: 'Heavy snowfall',
  77: 'Snow grains',
  80: 'Slight rain showers',
  81: 'Moderate rain showers',
  82: 'Violent rain showers',
  85: 'Slight snow showers',
  86: 'Heavy snow showers',
  95: 'Thunderstorm',
  96: 'Thunderstorm with slight hail',
  99: 'Thunderstorm with heavy hail',
};

function normalizeConnectionAccount(row, envStatus) {
  if (!row) {
    return {
      id: null,
      status: 'not_connected',
      connected: false,
      accountEmail: null,
      lastConnectedAt: null,
      accessMode: 'read_write',
    };
  }

  return {
    id: row.id || null,
    status: row.status || 'not_connected',
    connected: row.status === 'connected',
    accountEmail: row.account_email || null,
    lastConnectedAt: row.last_connected_at || null,
    accessMode: 'read_write',
  };
}

function sanitizeToolDefinition(definition) {
  return {
    ...definition,
    description:
      `${definition.description} When multiple Weather accounts are connected, set connection_id or account_email to choose which one to use.`,
    parameters: {
      ...(definition.parameters || { type: 'object', properties: {} }),
      type: 'object',
      properties: {
        ...((definition.parameters && definition.parameters.properties) || {}),
        connection_id: {
          type: 'number',
          description: 'Optional connected Weather account ID.',
        },
        account_email: {
          type: 'string',
          description: 'Optional connected Weather account identifier.',
        },
      },
      required: Array.isArray(definition.parameters?.required)
        ? definition.parameters.required.slice()
        : [],
    },
  };
}

function toNumber(value, fallback = null) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

function cleanLocationResult(item = {}) {
  return {
    name: item.name || null,
    latitude: toNumber(item.latitude),
    longitude: toNumber(item.longitude),
    country: item.country || null,
    admin1: item.admin1 || null,
    timezone: item.timezone || null,
    population: toNumber(item.population),
  };
}

async function geocodeLocation(locationQuery, limit = 1) {
  const query = String(locationQuery || '').trim();
  if (!query) {
    throw new Error('location is required when latitude/longitude are not provided.');
  }
  const result = await fetchJson(
    `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=${Math.max(1, Math.min(Number(limit) || 1, 10))}&language=en&format=json`,
    { method: 'GET' },
    { serviceName: 'Open-Meteo geocoding' },
  );
  const matches = Array.isArray(result?.results) ? result.results : [];
  if (matches.length === 0) {
    throw new Error(`No location match found for "${query}".`);
  }
  return matches.map(cleanLocationResult);
}

async function resolveLocation(args = {}, connection = null) {
  const latitude = toNumber(args.latitude, null);
  const longitude = toNumber(args.longitude, null);
  if (latitude !== null && longitude !== null) {
    return {
      latitude,
      longitude,
      label: `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`,
      timezone: null,
    };
  }

  const location = String(args.location || '').trim();
  if (location) {
    const [best] = await geocodeLocation(location, 1);
    return {
      latitude: best.latitude,
      longitude: best.longitude,
      label: [best.name, best.admin1, best.country].filter(Boolean).join(', ') || location,
      timezone: best.timezone || null,
    };
  }

  if (connection) {
    try {
      const metadata = JSON.parse(String(connection.metadata_json || '{}')) || {};
      const metaLatitude = toNumber(metadata.latitude, null);
      const metaLongitude = toNumber(metadata.longitude, null);
      if (metaLatitude !== null && metaLongitude !== null) {
        return {
          latitude: metaLatitude,
          longitude: metaLongitude,
          label: String(metadata.locationLabel || `${metaLatitude.toFixed(4)}, ${metaLongitude.toFixed(4)}`),
          timezone: String(metadata.timezone || '') || null,
        };
      }
    } catch {
      // Ignore malformed metadata and fail with a proper validation message below.
    }
  }

  throw new Error('Provide either location or latitude/longitude for weather tools.');
}

function enrichCurrent(current = {}) {
  const weatherCode = Number(current.weather_code);
  return {
    ...current,
    weather_label: Number.isFinite(weatherCode) ? WEATHER_CODE_LABELS[weatherCode] || 'Unknown' : 'Unknown',
  };
}

async function fetchForecastForLocation(location, forecastHours = 24) {
  const horizon = Math.max(1, Math.min(Number(forecastHours) || 24, 72));
  const url = new URL('https://api.open-meteo.com/v1/forecast');
  url.searchParams.set('latitude', String(location.latitude));
  url.searchParams.set('longitude', String(location.longitude));
  url.searchParams.set(
    'current',
    [
      'temperature_2m',
      'apparent_temperature',
      'precipitation',
      'rain',
      'showers',
      'snowfall',
      'weather_code',
      'wind_speed_10m',
      'wind_gusts_10m',
      'wind_direction_10m',
      'is_day',
    ].join(','),
  );
  url.searchParams.set(
    'hourly',
    [
      'temperature_2m',
      'precipitation',
      'rain',
      'showers',
      'snowfall',
      'weather_code',
      'wind_speed_10m',
      'wind_gusts_10m',
      'is_day',
    ].join(','),
  );
  url.searchParams.set('forecast_hours', String(horizon));
  url.searchParams.set('timezone', location.timezone || 'auto');

  const result = await fetchJson(url.toString(), { method: 'GET' }, { serviceName: 'Open-Meteo forecast' });
  const hourly = result?.hourly || {};
  const times = Array.isArray(hourly.time) ? hourly.time : [];
  const rows = times.map((time, index) => {
    const weatherCode = Number(hourly.weather_code?.[index]);
    return {
      time,
      temperature: toNumber(hourly.temperature_2m?.[index]),
      precipitation: toNumber(hourly.precipitation?.[index], 0),
      rain: toNumber(hourly.rain?.[index], 0),
      showers: toNumber(hourly.showers?.[index], 0),
      snowfall: toNumber(hourly.snowfall?.[index], 0),
      windSpeed: toNumber(hourly.wind_speed_10m?.[index], 0),
      windGust: toNumber(hourly.wind_gusts_10m?.[index], 0),
      weatherCode: Number.isFinite(weatherCode) ? weatherCode : null,
      weatherLabel: Number.isFinite(weatherCode) ? WEATHER_CODE_LABELS[weatherCode] || 'Unknown' : 'Unknown',
      isDay: Number(hourly.is_day?.[index]) === 1,
    };
  });

  return {
    location: {
      label: location.label,
      latitude: toNumber(result?.latitude, location.latitude),
      longitude: toNumber(result?.longitude, location.longitude),
      timezone: result?.timezone || location.timezone || null,
      elevation: toNumber(result?.elevation),
    },
    current: enrichCurrent(result?.current || {}),
    hourly: rows,
  };
}

class WeatherProvider {
  constructor() {
    this.key = 'weather';
    this.label = 'Weather';
    this.description = 'Official weather integration powered by Open-Meteo public APIs (no API key required).';
    this.icon = 'weather';
    this.apps = [{ ...WEATHER_APP }];
    this.connectPrompt =
      'Connect Weather to use keyless forecast and current-condition tools, then trigger tasks on weather events.';
    this.sessions = new Map();
    this.sessionTTL = 30 * 60 * 1000;
    this.#pruneTimer = setInterval(() => this.pruneExpiredSessions(), this.sessionTTL);
  }

  #pruneTimer = null;

  pruneExpiredSessions() {
    const now = Date.now();
    for (const [id, session] of this.sessions) {
      if (now - session.createdAt > this.sessionTTL) {
        this.sessions.delete(id);
      }
    }
  }

  getApp(appId) {
    return String(appId || '').trim() === WEATHER_APP.id ? { ...WEATHER_APP } : null;
  }

  getToolAppId(toolName) {
    const normalized = String(toolName || '').trim();
    return WEATHER_TOOL_DEFINITIONS.some((tool) => tool.name === normalized)
      ? WEATHER_APP.id
      : null;
  }

  getEnvStatus() {
    return {
      configured: true,
      missing: [],
      summary: 'Weather is ready for account connections.',
    };
  }

  buildSnapshot(connectionRows) {
    const env = this.getEnvStatus();
    const accounts = (Array.isArray(connectionRows) ? connectionRows : [])
      .slice()
      .sort((left, right) => String(right.updated_at || '').localeCompare(String(left.updated_at || '')))
      .map((row) => normalizeConnectionAccount(row, env));
    const connectedAccounts = accounts.filter((account) => account.connected);
    const latestConnectedAt = connectedAccounts
      .map((account) => account.lastConnectedAt)
      .filter(Boolean)
      .sort()
      .reverse()[0] || null;

    const appSnapshot = {
      id: WEATHER_APP.id,
      label: WEATHER_APP.label,
      description: WEATHER_APP.description,
      accounts,
      connection: {
        status: connectedAccounts.length > 0 ? 'connected' : 'not_connected',
        connected: connectedAccounts.length > 0,
        accountCount: connectedAccounts.length,
        accountEmail: connectedAccounts.length === 1 ? connectedAccounts[0].accountEmail : null,
        lastConnectedAt: latestConnectedAt,
      },
      availableToolCount: connectedAccounts.length > 0 ? WEATHER_TOOL_DEFINITIONS.length : 0,
    };

    return {
      id: this.key,
      label: this.label,
      description: this.description,
      icon: this.icon,
      apps: [appSnapshot],
      env,
      connection: {
        status: appSnapshot.connection.status,
        connected: appSnapshot.connection.connected,
        accountCount: appSnapshot.connection.accountCount,
        appCount: appSnapshot.connection.connected ? 1 : 0,
        accountEmail: appSnapshot.connection.accountEmail,
        lastConnectedAt: appSnapshot.connection.lastConnectedAt,
      },
      availableToolCount: appSnapshot.availableToolCount,
      connectPrompt: this.connectPrompt,
    };
  }

  summarizeForModel(snapshot) {
    if (!snapshot?.connection?.connected) {
      return 'Weather: available but not connected yet. Ask the user to connect Weather in Official Integrations.';
    }
    return 'Weather: connected with keyless Open-Meteo tools for geocoding, current conditions, and hourly forecast.';
  }

  getToolDefinitions({ connectedAppIds } = {}) {
    const appIds = new Set(Array.isArray(connectedAppIds) ? connectedAppIds : []);
    if (!appIds.has(WEATHER_APP.id)) {
      return [];
    }
    return WEATHER_TOOL_DEFINITIONS.map(sanitizeToolDefinition);
  }

  supportsTool(toolName) {
    return WEATHER_TOOL_DEFINITIONS.some((tool) => tool.name === String(toolName || '').trim());
  }

  async beginConnection({ userId, agentId, appKey }) {
    if (!this.getApp(appKey)) {
      throw new Error(`Unknown ${this.label} app: ${appKey || 'missing app key'}`);
    }

    const accountEmail = 'public@open-meteo';
    db.prepare(
      `INSERT INTO integration_connections (
         user_id,
         agent_id,
         provider_key,
         app_key,
         status,
         account_email,
         scopes_json,
         credentials_json,
         metadata_json,
         last_connected_at,
         updated_at
       ) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
       ON CONFLICT(user_id, agent_id, provider_key, app_key, account_email) DO UPDATE SET
         status = 'connected',
         scopes_json = excluded.scopes_json,
         credentials_json = excluded.credentials_json,
         metadata_json = excluded.metadata_json,
         last_connected_at = excluded.last_connected_at,
         updated_at = excluded.updated_at`,
    ).run(
      userId,
      agentId,
      this.key,
      WEATHER_APP.id,
      accountEmail,
      JSON.stringify(['open-meteo:public']),
      JSON.stringify({}),
      JSON.stringify({ source: 'open-meteo', mode: 'public' }),
    );

    const connection = db.prepare(
      `SELECT id FROM integration_connections
       WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND app_key = ? AND account_email = ?`,
    ).get(userId, agentId, this.key, WEATHER_APP.id, accountEmail);

    const sessionId = crypto.randomBytes(18).toString('hex');
    this.sessions.set(sessionId, {
      id: sessionId,
      userId,
      agentId,
      appKey: WEATHER_APP.id,
      status: 'connected',
      connectionId: connection?.id || null,
      accountEmail,
      createdAt: Date.now(),
    });

    return {
      provider: this.key,
      appId: WEATHER_APP.id,
      status: 'interactive_connect',
      sessionId,
      url: `/api/integrations/${this.key}/connect/${sessionId}`,
    };
  }

  getConnectionSession(userId, providerKey, sessionId, agentId = null) {
    if (providerKey !== this.key) {
      return null;
    }
    const session = this.sessions.get(String(sessionId || '').trim());
    if (!session) {
      return null;
    }
    if (session.userId !== userId || String(session.agentId || '') !== String(agentId || '')) {
      return null;
    }
    return {
      id: session.id,
      provider: this.key,
      appId: session.appKey,
      status: session.status,
      connectionId: session.connectionId,
      accountEmail: session.accountEmail,
      error: null,
      qr: null,
    };
  }

  async disconnect(sessionId = null) {
    if (sessionId) {
      this.sessions.delete(String(sessionId));
    }
    return null;
  }

  shutdown() {
    if (this.#pruneTimer) {
      clearInterval(this.#pruneTimer);
      this.#pruneTimer = null;
    }
  }

  async executeTool(toolName, args, connection) {
    switch (toolName) {
      case 'weather_search_locations': {
        const query = String(args.query || '').trim();
        if (!query) {
          throw new Error('query is required.');
        }
        const limit = Math.max(1, Math.min(Number(args.limit) || 5, 10));
        const results = await geocodeLocation(query, limit);
        return {
          result: {
            query,
            count: results.length,
            results,
          },
        };
      }
      case 'weather_get_current': {
        const location = await resolveLocation(args, connection);
        const forecast = await fetchForecastForLocation(location, 1);
        return {
          result: {
            location: forecast.location,
            current: forecast.current,
          },
        };
      }
      case 'weather_get_forecast': {
        const location = await resolveLocation(args, connection);
        const forecastHours = Math.max(1, Math.min(Number(args.forecast_hours) || 24, 72));
        const forecast = await fetchForecastForLocation(location, forecastHours);
        return {
          result: {
            location: forecast.location,
            current: forecast.current,
            hourly: forecast.hourly,
            horizonHours: forecastHours,
          },
        };
      }
      default:
        return null;
    }
  }
}

function createWeatherProvider() {
  return new WeatherProvider();
}

module.exports = {
  createWeatherProvider,
};
