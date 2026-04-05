'use strict';

function trimEnv(name) {
  return String(process.env[name] || '').trim();
}

function resolvePublicBaseUrl() {
  const explicit = trimEnv('PUBLIC_URL');
  if (explicit) return explicit.replace(/\/$/, '');
  return `http://localhost:${trimEnv('PORT') || '3333'}`;
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

function describeEnvStatus(config) {
  if (config.configured) {
    return {
      configured: true,
      missing: [],
      summary: 'Server OAuth credentials are configured.',
    };
  }

  return {
    configured: false,
    missing: config.missing,
    summary: `Server setup required: ${config.missing.join(', ')}`,
  };
}

module.exports = {
  describeEnvStatus,
  resolveGoogleOAuthConfig,
  resolvePublicBaseUrl,
};
