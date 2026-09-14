'use strict';

function expiresAtFromSeconds(expiresIn, { ifInvalid = 'default' } = {}) {
  const seconds = Number(expiresIn);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    if (ifInvalid === 'null') return null;
    return new Date(Date.now() + 3600 * 1000).toISOString();
  }
  return new Date(Date.now() + seconds * 1000).toISOString();
}

function tokenExpiresSoon(credentials, skewMs = 60 * 1000) {
  const expiresAt = Date.parse(String(credentials?.expires_at || ''));
  return Number.isFinite(expiresAt) && expiresAt <= Date.now() + skewMs;
}

async function withRefreshedOAuthCredentials(context, {
  refresh,
  request,
  shouldRetry,
}) {
  let credentials = context.credentials;
  if (tokenExpiresSoon(credentials)) {
    credentials = await refresh(credentials, context.signal);
    context.updateCredentials(credentials);
  }
  try {
    return await request(credentials);
  } catch (error) {
    const retry = typeof shouldRetry === 'function'
      ? shouldRetry(error, credentials)
      : (error?.status === 401 && Boolean(String(credentials?.refresh_token || '').trim()));
    if (!retry) throw error;
    credentials = await refresh(credentials, context.signal);
    context.updateCredentials(credentials);
    return request(credentials);
  }
}

module.exports = {
  expiresAtFromSeconds,
  tokenExpiresSoon,
  withRefreshedOAuthCredentials,
};
