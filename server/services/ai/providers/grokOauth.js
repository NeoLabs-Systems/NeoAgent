'use strict';

const OpenAI = require('openai');
const { ENV_FILE, removeEnvValue, upsertEnvValue } = require('../../../../runtime/paths');
const { fetchResponseText, waitForAbortableResult } = require('../../network/http');
const { GrokProvider } = require('./grok');

const GROK_OAUTH_BASE_URL = 'https://api.x.ai/v1';
const GROK_OAUTH_CLIENT_ID = 'b1a00492-073a-47ea-816f-4c329264a828';
const GROK_OAUTH_TOKEN_URL = 'https://auth.x.ai/oauth2/token';
const GROK_OAUTH_SCOPES = 'openid profile email offline_access grok-cli:access api:access';
const OAUTH_REFRESH_TIMEOUT_MS = 30000;
const OAUTH_MAX_RESPONSE_BYTES = 256 * 1024;
const OAUTH_REFRESH_SKEW_MS = 5 * 60 * 1000;
const GROK_INVALID_CREDENTIAL_CODE = 'unauthenticated:bad-credentials';

const refreshesByToken = new Map();

function finiteNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function normalizeExpiresAt(data) {
  const expiresAt = finiteNumber(data?.expires_at ?? data?.expiresAt);
  if (expiresAt !== null && expiresAt > 0) {
    return expiresAt > 10_000_000_000 ? expiresAt : expiresAt * 1000;
  }
  const expiresIn = finiteNumber(data?.expires_in ?? data?.expiresIn);
  if (expiresIn !== null && expiresIn > 0) {
    return Date.now() + (expiresIn * 1000);
  }
  return null;
}

function readJwtExpiresAt(accessToken) {
  try {
    const parts = String(accessToken || '').split('.');
    if (parts.length < 2) return null;
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    const expiresAt = finiteNumber(payload?.exp);
    return expiresAt !== null && expiresAt > 0 ? expiresAt * 1000 : null;
  } catch {
    return null;
  }
}

function getGrokOAuthTokenExpiresAt(accessToken, tokenData = {}) {
  return readJwtExpiresAt(accessToken) || normalizeExpiresAt(tokenData);
}

function isGrokAuthenticationError(error) {
  let current = error;
  for (let depth = 0; current && depth < 3; depth += 1) {
    if (current.status === 401 || current.statusCode === 401) return true;
    const status = current.status ?? current.statusCode;
    const code = current.code ?? current.error?.code;
    if (status === 403 && code === GROK_INVALID_CREDENTIAL_CODE) return true;
    current = current.cause;
  }
  return false;
}

function persistEnvValue(key, value) {
  if (!value) return;
  try {
    upsertEnvValue(ENV_FILE, key, value);
  } catch { }
}

function persistTokenRecord(refreshed) {
  process.env.GROK_OAUTH_ACCESS_TOKEN = refreshed.access;
  persistEnvValue('GROK_OAUTH_ACCESS_TOKEN', refreshed.access);
  if (refreshed.refresh) {
    process.env.GROK_OAUTH_REFRESH_TOKEN = refreshed.refresh;
    persistEnvValue('GROK_OAUTH_REFRESH_TOKEN', refreshed.refresh);
  }
  if (refreshed.expires) {
    process.env.GROK_OAUTH_EXPIRES_AT = String(Math.trunc(refreshed.expires));
    persistEnvValue('GROK_OAUTH_EXPIRES_AT', process.env.GROK_OAUTH_EXPIRES_AT);
  } else {
    delete process.env.GROK_OAUTH_EXPIRES_AT;
    try {
      removeEnvValue(ENV_FILE, 'GROK_OAUTH_EXPIRES_AT');
    } catch { }
  }
  return refreshed;
}

async function refreshGrokOAuthAccessToken(refreshToken, fetchImpl = fetch, signal = null) {
  if (!refreshToken) return null;
  const { response, text } = await fetchResponseText(GROK_OAUTH_TOKEN_URL, {
    fetchImpl,
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: GROK_OAUTH_CLIENT_ID,
    }),
    signal,
    timeoutMs: OAUTH_REFRESH_TIMEOUT_MS,
    maxResponseBytes: OAUTH_MAX_RESPONSE_BYTES,
    serviceName: 'Grok OAuth refresh',
    timeoutCode: 'PROVIDER_OAUTH_TIMEOUT',
    tooLargeCode: 'PROVIDER_OAUTH_RESPONSE_TOO_LARGE',
  });

  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = {};
  }

  if (!response.ok) {
    if (data?.error === 'invalid_grant') {
      throw new Error('Grok OAuth refresh token is invalid or expired. Re-run `neoagent login grok-oauth` to re-authenticate.');
    }
    const detail = String(data?.error_description || data?.error || text || 'Unknown error').slice(0, 2000);
    throw new Error(`Grok OAuth refresh failed: HTTP ${response.status} ${detail}`);
  }
  if (!data.access_token) {
    throw new Error('Grok OAuth refresh succeeded but no access_token was returned.');
  }

  return {
    access: data.access_token,
    refresh: data.refresh_token || refreshToken,
    expires: getGrokOAuthTokenExpiresAt(data.access_token, data),
  };
}

class GrokOAuthProvider extends GrokProvider {
  constructor(config = {}) {
    const runtimeAccessToken = process.env.GROK_OAUTH_ACCESS_TOKEN || null;
    const authToken = config.apiKey || runtimeAccessToken;
    const usesRuntimeCredentials = Boolean(
      runtimeAccessToken && authToken === runtimeAccessToken && !config.refreshToken,
    );
    super({
      ...config,
      apiKey: authToken,
      baseUrl: GROK_OAUTH_BASE_URL,
    });
    this.name = 'grok-oauth';

    if (!authToken) {
      console.warn('[GrokOAuth] No access token. Run `neoagent login grok-oauth` to authenticate.');
    }

    this.authToken = authToken || null;
    this.refreshToken = config.refreshToken
      || (usesRuntimeCredentials ? process.env.GROK_OAUTH_REFRESH_TOKEN : null)
      || null;
    this.tokenExpiresAt = getGrokOAuthTokenExpiresAt(this.authToken, {
      expires_at: config.expiresAt
        || (usesRuntimeCredentials ? process.env.GROK_OAUTH_EXPIRES_AT : null),
    });
    this.usesRuntimeCredentials = usesRuntimeCredentials;
    this.fetchImpl = config.fetch || fetch;
  }

  replaceClient(accessToken, expiresAt = null) {
    this.authToken = accessToken;
    this.tokenExpiresAt = expiresAt || getGrokOAuthTokenExpiresAt(accessToken);
    this.client = new OpenAI({ apiKey: this.authToken, baseURL: GROK_OAUTH_BASE_URL });
  }

  syncRuntimeCredentials() {
    if (!this.usesRuntimeCredentials) return false;
    const accessToken = process.env.GROK_OAUTH_ACCESS_TOKEN || null;
    const refreshToken = process.env.GROK_OAUTH_REFRESH_TOKEN || null;
    if (refreshToken) this.refreshToken = refreshToken;
    if (!accessToken || accessToken === this.authToken) return false;
    this.replaceClient(accessToken, getGrokOAuthTokenExpiresAt(accessToken, {
      expires_at: process.env.GROK_OAUTH_EXPIRES_AT,
    }));
    return true;
  }

  tokenIsExpiring() {
    return this.tokenExpiresAt !== null
      && this.tokenExpiresAt <= Date.now() + OAUTH_REFRESH_SKEW_MS;
  }

  async ensureFreshClient(signal = null) {
    this.syncRuntimeCredentials();
    if (!this.refreshToken || !this.tokenIsExpiring()) return;
    await this.refreshClient(signal);
  }

  async refreshClient(signal = null) {
    this.syncRuntimeCredentials();
    const refreshToken = this.refreshToken;
    if (!refreshToken) return false;

    let refresh = refreshesByToken.get(refreshToken);
    if (!refresh) {
      refresh = refreshGrokOAuthAccessToken(refreshToken, this.fetchImpl)
        .then(persistTokenRecord)
        .finally(() => refreshesByToken.delete(refreshToken));
      refreshesByToken.set(refreshToken, refresh);
    }

    const refreshed = await waitForAbortableResult(
      refresh,
      signal,
      'Grok OAuth refresh aborted.',
    );
    if (!refreshed?.access) return false;
    this.refreshToken = refreshed.refresh || this.refreshToken;
    this.replaceClient(refreshed.access, refreshed.expires);
    return true;
  }

  async recoverAuthentication(attemptedToken, signal = null) {
    if (!this.refreshToken) return false;
    if (this.syncRuntimeCredentials() && this.authToken !== attemptedToken) return true;
    return this.refreshClient(signal);
  }

  async withTokenRefresh(operation, signal = null) {
    await this.ensureFreshClient(signal);
    const attemptedToken = this.authToken;
    try {
      return await operation();
    } catch (err) {
      if (!isGrokAuthenticationError(err) || !this.refreshToken) throw err;
      await this.recoverAuthentication(attemptedToken, signal);
      return operation();
    }
  }

  async listModels(signal = null) {
    return this.withTokenRefresh(() => super.listModels(signal), signal);
  }

  async chat(messages, tools = [], options = {}) {
    return this.withTokenRefresh(
      () => super.chat(messages, tools, options),
      options.signal,
    );
  }

  async *stream(messages, tools = [], options = {}) {
    await this.ensureFreshClient(options.signal);
    const attemptedToken = this.authToken;
    try {
      yield* super.stream(messages, tools, options);
    } catch (err) {
      if (!isGrokAuthenticationError(err) || !this.refreshToken) throw err;
      await this.recoverAuthentication(attemptedToken, options.signal);
      yield* super.stream(messages, tools, options);
    }
  }

  async analyzeImage(options = {}) {
    return this.withTokenRefresh(() => super.analyzeImage(options), options.signal);
  }
}

module.exports = {
  GrokOAuthProvider,
  getGrokOAuthTokenExpiresAt,
  isGrokAuthenticationError,
  refreshGrokOAuthAccessToken,
  GROK_OAUTH_SCOPES,
  GROK_OAUTH_CLIENT_ID,
};
