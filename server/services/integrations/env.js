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

function resolveGoogleOAuthConfig() {
  const clientId = trimEnv('GOOGLE_OAUTH_CLIENT_ID');
  const clientSecret = trimEnv('GOOGLE_OAUTH_CLIENT_SECRET');
  const redirectUri =
    trimEnv('GOOGLE_OAUTH_REDIRECT_URI') ||
    `${resolvePublicBaseUrl()}/api/integrations/oauth/callback`;
  const missing = [];
  if (!clientId) missing.push('GOOGLE_OAUTH_CLIENT_ID');
  if (!clientSecret) missing.push('GOOGLE_OAUTH_CLIENT_SECRET');
  return {
    clientId,
    clientSecret,
    redirectUri,
    configured: missing.length === 0,
    missing,
  };
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
  resolveGoogleOAuthConfig,
  resolvePublicBaseUrl,
};
