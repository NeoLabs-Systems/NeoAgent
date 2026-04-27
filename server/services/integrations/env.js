'use strict';

function trimEnv(name) {
  return String(process.env[name] || '').trim();
}

function resolvePublicBaseUrl() {
  const explicit = trimEnv('PUBLIC_URL');
  if (explicit) return explicit.replace(/\/$/, '');
  const schemeOverride = trimEnv('PUBLIC_URL_SCHEME').toLowerCase();
  const scheme = schemeOverride ||
    (String(process.env.NODE_ENV || '').trim() === 'development' ? 'http' : 'https');
  return `${scheme}://localhost:${trimEnv('PORT') || '3333'}`;
}

function resolveOAuthConfig(prefix) {
  const normalizedPrefix = String(prefix || '').trim().toUpperCase();
  const clientId = trimEnv(`${normalizedPrefix}_OAUTH_CLIENT_ID`);
  const clientSecret = trimEnv(`${normalizedPrefix}_OAUTH_CLIENT_SECRET`);
  const redirectUri =
    trimEnv(`${normalizedPrefix}_OAUTH_REDIRECT_URI`) ||
    `${resolvePublicBaseUrl()}/api/integrations/oauth/callback`;
  const missing = [];
  if (!clientId) missing.push(`${normalizedPrefix}_OAUTH_CLIENT_ID`);
  if (!clientSecret) missing.push(`${normalizedPrefix}_OAUTH_CLIENT_SECRET`);
  return {
    clientId,
    clientSecret,
    redirectUri,
    configured: missing.length === 0,
    missing,
  };
}

function resolveGoogleOAuthConfig() {
  return resolveOAuthConfig('GOOGLE');
}

function resolveNotionOAuthConfig() {
  return resolveOAuthConfig('NOTION');
}

function resolveSlackOAuthConfig() {
  return resolveOAuthConfig('SLACK');
}

function resolveFigmaOAuthConfig() {
  return resolveOAuthConfig('FIGMA');
}

function resolveMicrosoftOAuthConfig() {
  const base = resolveOAuthConfig('MICROSOFT');
  return {
    ...base,
    tenantId: trimEnv('MICROSOFT_OAUTH_TENANT_ID') || 'common',
  };
}

function resolveHomeAssistantOAuthConfig() {
  const base = resolveOAuthConfig('HOME_ASSISTANT');
  return {
    ...base,
    baseUrl: trimEnv('HOME_ASSISTANT_BASE_URL').replace(/\/$/, ''),
  };
}

function resolveSpotifyOAuthConfig() {
  return resolveOAuthConfig('SPOTIFY');
}

function resolveGithubOAuthConfig() {
  return resolveOAuthConfig('GITHUB');
}

function describeEnvStatus(config, options = {}) {
  const label = String(options.label || 'This integration').trim() || 'This integration';
  if (config.configured) {
    return {
      configured: true,
      missing: [],
      summary: `${label} is ready for account connections.`,
    };
  }

  return {
    configured: false,
    missing: config.missing,
    summary: `${label} still needs administrator setup before accounts can connect.`,
  };
}

module.exports = {
  describeEnvStatus,
  resolveFigmaOAuthConfig,
  resolveHomeAssistantOAuthConfig,
  resolveMicrosoftOAuthConfig,
  resolveNotionOAuthConfig,
  resolveOAuthConfig,
  resolveGoogleOAuthConfig,
  resolvePublicBaseUrl,
  resolveSpotifyOAuthConfig,
  resolveSlackOAuthConfig,
  resolveGithubOAuthConfig,
};
