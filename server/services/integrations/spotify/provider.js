'use strict';

const { describeEnvStatus, resolveSpotifyOAuthConfig } = require('../env');
const { appendQuery, createOAuthProvider } = require('../oauth_provider');

const SPOTIFY_APPS = [
  {
    id: 'spotify',
    label: 'Spotify',
    description: 'Connect Spotify for playback status, search, and playback controls.',
    scopes: [
      'user-read-email',
      'user-read-private',
      'user-read-playback-state',
      'user-modify-playback-state',
      'user-read-currently-playing',
      'user-read-recently-played',
    ],
  },
];

const spotifyToolDefinitions = [
  {
    appId: 'spotify',
    name: 'spotify_get_current_playback',
    access: 'read',
    description: 'Get current playback state for the connected Spotify account.',
    parameters: { type: 'object', properties: {} },
  },
  {
    appId: 'spotify',
    name: 'spotify_get_recently_played',
    access: 'read',
    description: 'Get recently played tracks for the connected Spotify account.',
    parameters: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Maximum number of tracks (1-50), default 20.' },
      },
    },
  },
  {
    appId: 'spotify',
    name: 'spotify_search',
    access: 'read',
    description: 'Search Spotify catalog for tracks, albums, artists, or playlists.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search query text.' },
        type: { type: 'string', description: 'Comma-separated types: track,artist,album,playlist. Default track.' },
        limit: { type: 'number', description: 'Maximum items per type (1-50), default 10.' },
        market: { type: 'string', description: 'Optional market code like US.' },
      },
      required: ['query'],
    },
  },
  {
    appId: 'spotify',
    name: 'spotify_control_playback',
    access: 'write',
    description: 'Control Spotify playback: play, pause, next, previous, seek, set_volume, shuffle, or repeat.',
    parameters: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          description: 'Playback action: play, pause, next, previous, seek, set_volume, shuffle, repeat.',
        },
        device_id: { type: 'string', description: 'Optional target device ID.' },
        context_uri: { type: 'string', description: 'Optional context URI for play action.' },
        uris: { type: 'array', items: { type: 'string' }, description: 'Optional track URIs for play action.' },
        position_ms: { type: 'number', description: 'Optional playback offset in ms for play/seek.' },
        volume_percent: { type: 'number', description: 'Volume 0-100 for set_volume action.' },
        state: { type: 'boolean', description: 'Shuffle state for shuffle action.' },
        mode: { type: 'string', description: 'Repeat mode for repeat action: track, context, off.' },
      },
      required: ['action'],
    },
  },
  {
    appId: 'spotify',
    name: 'spotify_api_request',
    access: 'dynamic_http_method',
    description: 'Make an authenticated Spotify Web API request for advanced operations.',
    parameters: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'HTTP method.' },
        path: { type: 'string', description: 'Spotify API path such as /v1/me/player/devices.' },
        query: { type: 'object', description: 'Optional query parameters.' },
        body: { type: 'object', description: 'Optional JSON request body.' },
      },
      required: ['method', 'path'],
    },
  },
];

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) {
    throw new Error(`${label} is required.`);
  }
  return text;
}

function spotifyUrl(path, query) {
  const rawPath = String(path || '').trim();
  const url = new URL(
    rawPath.startsWith('http')
      ? rawPath
      : `https://api.spotify.com${rawPath.startsWith('/') ? '' : '/'}${rawPath}`,
  );
  if (url.hostname !== 'api.spotify.com') {
    throw new Error('Spotify API request URL must target api.spotify.com.');
  }
  for (const [key, value] of Object.entries(query || {})) {
    if (value === undefined || value === null) continue;
    url.searchParams.set(key, String(value));
  }
  return url.toString();
}

async function refreshSpotifyAccessToken(config, credentials) {
  const refreshToken = String(credentials?.refresh_token || '').trim();
  if (!refreshToken) {
    return credentials;
  }
  const basic = Buffer.from(`${config.clientId}:${config.clientSecret}`).toString('base64');
  const response = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basic}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    }).toString(),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = data?.error_description || data?.error || `${response.status} ${response.statusText}`;
    throw new Error(`Spotify token refresh failed: ${message}`);
  }
  const expiresIn = Number(data?.expires_in) || 3600;
  return {
    ...credentials,
    access_token: data?.access_token || credentials.access_token,
    refresh_token: data?.refresh_token || refreshToken,
    token_type: data?.token_type || credentials.token_type || 'Bearer',
    scope: data?.scope || credentials.scope || '',
    expires_in: expiresIn,
    expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
  };
}

async function ensureSpotifyAccessToken(config, credentials) {
  const accessToken = String(credentials?.access_token || '').trim();
  if (!accessToken) {
    throw new Error('Spotify access token is missing. Reconnect this integration account.');
  }

  const expiresAt = Date.parse(String(credentials?.expires_at || ''));
  const isNearExpiry = Number.isFinite(expiresAt) && expiresAt <= Date.now() + 60 * 1000;
  if (isNearExpiry && credentials?.refresh_token) {
    return refreshSpotifyAccessToken(config, credentials);
  }
  return credentials;
}

async function spotifyRequest(config, credentials, { method = 'GET', path, query, body }) {
  let nextCredentials = await ensureSpotifyAccessToken(config, credentials);
  const tokenType = String(nextCredentials?.token_type || 'Bearer').trim() || 'Bearer';

  const performRequest = async (tokenCreds) => {
    const tokenType = String(tokenCreds?.token_type || 'Bearer').trim() || 'Bearer';
    const response = await fetch(spotifyUrl(path, query), {
      method: String(method || 'GET').toUpperCase(),
      headers: {
        Authorization: `${tokenType} ${tokenCreds.access_token}`,
        Accept: 'application/json',
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });

    if (response.status === 204) {
      return { ok: true, data: null, response };
    }

    const text = await response.text();
    let parsed = null;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {
      parsed = null;
    }
    return { ok: response.ok, data: parsed ?? text, response };
  };

  let result = await performRequest(nextCredentials);
  if (!result.ok && result.response.status === 401 && nextCredentials.refresh_token) {
    nextCredentials = await refreshSpotifyAccessToken(config, nextCredentials);
    result = await performRequest(nextCredentials);
  }

  if (!result.ok) {
    const message =
      (result.data && typeof result.data === 'object' && (result.data.error?.message || result.data.error_description || result.data.error)) ||
      `${result.response.status} ${result.response.statusText}`;
    throw new Error(`Spotify request failed: ${String(message).trim()}`);
  }

  return {
    data: result.data,
    credentials: nextCredentials,
  };
}

async function executeSpotifyTool(toolName, args, { credentials }) {
  const config = resolveSpotifyOAuthConfig();
  switch (toolName) {
    case 'spotify_get_current_playback': {
      const { data, credentials: updated } = await spotifyRequest(config, credentials, {
        path: '/v1/me/player',
      });
      return { result: data || { is_playing: false }, credentials: updated };
    }
    case 'spotify_get_recently_played': {
      const limit = Math.max(1, Math.min(Number(args.limit) || 20, 50));
      const { data, credentials: updated } = await spotifyRequest(config, credentials, {
        path: '/v1/me/player/recently-played',
        query: { limit },
      });
      return { result: data, credentials: updated };
    }
    case 'spotify_search': {
      const queryText = requireText(args.query, 'query');
      const types = String(args.type || 'track')
        .split(',')
        .map((entry) => entry.trim().toLowerCase())
        .filter(Boolean)
        .filter((entry) => ['track', 'artist', 'album', 'playlist'].includes(entry));
      const type = types.length > 0 ? types.join(',') : 'track';
      const limit = Math.max(1, Math.min(Number(args.limit) || 10, 50));
      const market = String(args.market || '').trim().toUpperCase();
      const { data, credentials: updated } = await spotifyRequest(config, credentials, {
        path: '/v1/search',
        query: {
          q: queryText,
          type,
          limit,
          ...(market ? { market } : {}),
        },
      });
      return { result: data, credentials: updated };
    }
    case 'spotify_control_playback': {
      const action = String(args.action || '').trim().toLowerCase();
      const deviceId = String(args.device_id || '').trim();
      const query = deviceId ? { device_id: deviceId } : undefined;

      let request;
      switch (action) {
        case 'play':
          request = {
            method: 'PUT',
            path: '/v1/me/player/play',
            query,
            body: {
              ...(String(args.context_uri || '').trim() ? { context_uri: String(args.context_uri).trim() } : {}),
              ...(Array.isArray(args.uris) ? { uris: args.uris } : {}),
              ...(Number.isFinite(Number(args.position_ms)) ? { position_ms: Number(args.position_ms) } : {}),
            },
          };
          break;
        case 'pause':
          request = { method: 'PUT', path: '/v1/me/player/pause', query };
          break;
        case 'next':
          request = { method: 'POST', path: '/v1/me/player/next', query };
          break;
        case 'previous':
          request = { method: 'POST', path: '/v1/me/player/previous', query };
          break;
        case 'seek': {
          const positionMs = Number(args.position_ms);
          if (!Number.isFinite(positionMs) || positionMs < 0) {
            throw new Error('position_ms must be a non-negative number for seek action.');
          }
          request = {
            method: 'PUT',
            path: '/v1/me/player/seek',
            query: {
              ...(query || {}),
              position_ms: Math.floor(positionMs),
            },
          };
          break;
        }
        case 'set_volume': {
          const volume = Number(args.volume_percent);
          if (!Number.isFinite(volume) || volume < 0 || volume > 100) {
            throw new Error('volume_percent must be between 0 and 100 for set_volume action.');
          }
          request = {
            method: 'PUT',
            path: '/v1/me/player/volume',
            query: {
              ...(query || {}),
              volume_percent: Math.round(volume),
            },
          };
          break;
        }
        case 'shuffle': {
          if (typeof args.state !== 'boolean') {
            throw new Error('state must be true or false for shuffle action.');
          }
          request = {
            method: 'PUT',
            path: '/v1/me/player/shuffle',
            query: {
              ...(query || {}),
              state: args.state,
            },
          };
          break;
        }
        case 'repeat': {
          const mode = String(args.mode || '').trim().toLowerCase();
          if (!['track', 'context', 'off'].includes(mode)) {
            throw new Error('mode must be one of track, context, or off for repeat action.');
          }
          request = {
            method: 'PUT',
            path: '/v1/me/player/repeat',
            query: {
              ...(query || {}),
              state: mode,
            },
          };
          break;
        }
        default:
          throw new Error('Unsupported action. Use play, pause, next, previous, seek, set_volume, shuffle, or repeat.');
      }

      const { data, credentials: updated } = await spotifyRequest(config, credentials, request);
      return {
        result: {
          action,
          ok: true,
          response: data,
        },
        credentials: updated,
      };
    }
    case 'spotify_api_request': {
      const { data, credentials: updated } = await spotifyRequest(config, credentials, {
        method: args.method,
        path: requireText(args.path, 'path'),
        query: args.query,
        body: args.body,
      });
      return { result: data, credentials: updated };
    }
    default:
      return null;
  }
}

async function fetchSpotifyProfile(accessToken) {
  const response = await fetch('https://api.spotify.com/v1/me', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = payload?.error?.message || payload?.error || `${response.status} ${response.statusText}`;
    throw new Error(`Spotify profile request failed: ${message}`);
  }
  return payload;
}

function createSpotifyProvider() {
  return createOAuthProvider({
    key: 'spotify',
    label: 'Spotify',
    description: 'Official Spotify account integration for music search and playback control.',
    icon: 'spotify',
    requiresRefreshToken: true,
    apps: SPOTIFY_APPS,
    toolDefinitions: spotifyToolDefinitions,
    connectPrompt:
      'Connect Spotify to allow playback-aware automations, track search, and playback controls from the agent.',
    getEnvStatus() {
      return describeEnvStatus(resolveSpotifyOAuthConfig(), {
        label: 'Spotify',
      });
    },
    async beginOAuth({ state, app }) {
      const config = resolveSpotifyOAuthConfig();
      return {
        url: appendQuery('https://accounts.spotify.com/authorize', {
          response_type: 'code',
          client_id: config.clientId,
          redirect_uri: config.redirectUri,
          scope: app.scopes.join(' '),
          state,
          show_dialog: 'true',
        }),
        appId: app.id,
      };
    },
    async finishOAuth({ code, app }) {
      const config = resolveSpotifyOAuthConfig();
      const basic = Buffer.from(`${config.clientId}:${config.clientSecret}`).toString('base64');
      const tokenResponse = await fetch('https://accounts.spotify.com/api/token', {
        method: 'POST',
        headers: {
          Authorization: `Basic ${basic}`,
          'Content-Type': 'application/x-www-form-urlencoded',
          Accept: 'application/json',
        },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          code,
          redirect_uri: config.redirectUri,
        }).toString(),
      });
      const token = await tokenResponse.json().catch(() => ({}));
      if (!tokenResponse.ok) {
        const message = token?.error_description || token?.error || `${tokenResponse.status} ${tokenResponse.statusText}`;
        throw new Error(`Spotify OAuth token exchange failed: ${message}`);
      }

      const accessToken = String(token?.access_token || '').trim();
      if (!accessToken) {
        throw new Error('Spotify OAuth did not return an access token.');
      }
      const refreshToken = String(token?.refresh_token || '').trim();
      if (!refreshToken) {
        throw new Error('Spotify OAuth did not return a refresh token.');
      }

      const profile = await fetchSpotifyProfile(accessToken);
      const accountEmail =
        String(profile?.email || '').trim() ||
        (String(profile?.id || '').trim() ? `spotify:${String(profile.id).trim()}` : 'spotify_user');

      const expiresIn = Number(token?.expires_in) || 3600;
      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: accessToken,
          refresh_token: refreshToken,
          token_type: token?.token_type || 'Bearer',
          scope: token?.scope || app.scopes.join(' '),
          expires_in: expiresIn,
          expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
        },
        scopes: String(token?.scope || app.scopes.join(' '))
          .split(/\s+/)
          .map((scope) => scope.trim())
          .filter(Boolean),
        metadata: {
          spotifyUserId: profile?.id || null,
          displayName: profile?.display_name || null,
          email: profile?.email || null,
          country: profile?.country || null,
          product: profile?.product || null,
        },
      };
    },
    executeTool: executeSpotifyTool,
  });
}

module.exports = {
  createSpotifyProvider,
};
