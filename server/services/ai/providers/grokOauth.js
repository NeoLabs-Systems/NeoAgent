const OpenAI = require('openai');
const { ENV_FILE, upsertEnvValue } = require('../../../../runtime/paths');
const { fetchResponseText } = require('../../network/http');
const { GrokProvider } = require('./grok');

const GROK_OAUTH_BASE_URL = 'https://api.x.ai/v1';
const GROK_OAUTH_CLIENT_ID = 'b1a00492-073a-47ea-816f-4c329264a828';
const GROK_OAUTH_TOKEN_URL = 'https://auth.x.ai/oauth2/token';
const GROK_OAUTH_SCOPES = 'openid profile email offline_access grok-cli:access api:access';
const OAUTH_REFRESH_TIMEOUT_MS = 30000;
const OAUTH_MAX_RESPONSE_BYTES = 256 * 1024;

function normalizeExpiresAt(data) {
  if (typeof data.expires_at === 'number' && Number.isFinite(data.expires_at)) {
    return data.expires_at > 10_000_000_000 ? data.expires_at : data.expires_at * 1000;
  }
  if (typeof data.expires_in === 'number' && Number.isFinite(data.expires_in)) {
    return Date.now() + (data.expires_in * 1000);
  }
  return null;
}

function persistEnvValue(key, value) {
  if (!value) return;
  try {
    upsertEnvValue(ENV_FILE, key, value);
  } catch { }
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
    expires: normalizeExpiresAt(data),
  };
}

class GrokOAuthProvider extends GrokProvider {
  constructor(config = {}) {
    const authToken = config.apiKey || process.env.GROK_OAUTH_ACCESS_TOKEN;
    super({
      ...config,
      apiKey: authToken,
      baseUrl: GROK_OAUTH_BASE_URL,
    });
    this.name = 'grok-oauth';
    this.models = ['grok-4', 'grok-4-mini'];

    if (!authToken) {
      console.warn('[GrokOAuth] No access token. Run `neoagent login grok-oauth` to authenticate.');
    }

    this.authToken = authToken || null;
    this.refreshToken = config.refreshToken || process.env.GROK_OAUTH_REFRESH_TOKEN || null;
    this.fetchImpl = config.fetch || fetch;
  }

  async refreshClient(signal = null) {
    const refreshed = await refreshGrokOAuthAccessToken(this.refreshToken, this.fetchImpl, signal);
    if (!refreshed?.access) return false;
    this.authToken = refreshed.access;
    this.refreshToken = refreshed.refresh || this.refreshToken;
    process.env.GROK_OAUTH_ACCESS_TOKEN = this.authToken;
    persistEnvValue('GROK_OAUTH_ACCESS_TOKEN', this.authToken);
    if (this.refreshToken) {
      process.env.GROK_OAUTH_REFRESH_TOKEN = this.refreshToken;
      persistEnvValue('GROK_OAUTH_REFRESH_TOKEN', this.refreshToken);
    }
    this.client = new OpenAI({ apiKey: this.authToken, baseURL: GROK_OAUTH_BASE_URL });
    return true;
  }

  async chat(messages, tools = [], options = {}) {
    try {
      return await super.chat(messages, tools, options);
    } catch (err) {
      if (err?.status !== 401 || !this.refreshToken) throw err;
      await this.refreshClient(options.signal);
      return await super.chat(messages, tools, options);
    }
  }

  async *stream(messages, tools = [], options = {}) {
    try {
      yield* super.stream(messages, tools, options);
    } catch (err) {
      if (err?.status !== 401 || !this.refreshToken) throw err;
      await this.refreshClient(options.signal);
      yield* super.stream(messages, tools, options);
    }
  }
}

module.exports = { GrokOAuthProvider, refreshGrokOAuthAccessToken, GROK_OAUTH_SCOPES, GROK_OAUTH_CLIENT_ID };
