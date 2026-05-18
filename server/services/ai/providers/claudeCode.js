const os = require('os');
const fs = require('fs');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');
const { AnthropicProvider } = require('./anthropic');

const CLAUDE_CLI_CREDS_PATH = path.join(os.homedir(), '.claude', '.credentials.json');
const CLAUDE_CODE_BASE_URL = 'https://api.anthropic.com';
const CLAUDE_CODE_VERSION = process.env.CLAUDE_CODE_VERSION || '2.1.75';
const CLAUDE_CODE_OAUTH_BETA = 'claude-code-20250219,oauth-2025-04-20,fine-grained-tool-streaming-2025-05-14';
const CLAUDE_CODE_SYSTEM_PROMPT = "You are Claude Code, Anthropic's official CLI for Claude.";
const CLAUDE_CODE_CLIENT_ID = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
const CLAUDE_CODE_TOKEN_URL = 'https://platform.claude.com/v1/oauth/token';
const CLAUDE_CODE_SCOPES = 'user:inference user:profile org:create_api_key user:sessions:claude_code user:mcp_servers';

function readTokenRecord(data) {
  const tokens = data?.claudeAiOauthTokens || data?.claudeAiOauth || {};
  const access = tokens.accessToken || tokens.access;
  const refresh = tokens.refreshToken || tokens.refresh;
  const expires = tokens.expiresAt || tokens.expires;
  return {
    access: typeof access === 'string' && access ? access : null,
    refresh: typeof refresh === 'string' && refresh ? refresh : null,
    expires: typeof expires === 'number' && Number.isFinite(expires) ? expires : null,
  };
}

function readTokenValue(data) {
  return readTokenRecord(data).access;
}

function readClaudeCliTokenRecord() {
  try {
    const raw = fs.readFileSync(CLAUDE_CLI_CREDS_PATH, 'utf8');
    const data = JSON.parse(raw);
    return readTokenRecord(data);
  } catch {
    return { access: null, refresh: null, expires: null };
  }
}

function readClaudeCliToken() {
  return readClaudeCliTokenRecord().access;
}

function mergeAnthropicBeta(existing) {
  if (!existing) return CLAUDE_CODE_OAUTH_BETA;
  const seen = new Set();
  return String(existing)
    .split(',')
    .concat(CLAUDE_CODE_OAUTH_BETA.split(','))
    .map((item) => item.trim())
    .filter((item) => {
      if (!item || seen.has(item)) return false;
      seen.add(item);
      return true;
    })
    .join(',');
}

function normalizeExpiresAt(data) {
  if (typeof data.expires_at === 'number' && Number.isFinite(data.expires_at)) {
    return data.expires_at > 10_000_000_000 ? data.expires_at : data.expires_at * 1000;
  }
  if (typeof data.expiresAt === 'number' && Number.isFinite(data.expiresAt)) {
    return data.expiresAt > 10_000_000_000 ? data.expiresAt : data.expiresAt * 1000;
  }
  if (typeof data.expires_in === 'number' && Number.isFinite(data.expires_in)) {
    return Date.now() + (data.expires_in * 1000);
  }
  return null;
}

function sanitizeEnvKey(key) {
  return String(key).replace(/[\r\n]/g, '');
}

function sanitizeEnvValue(value) {
  return String(value).replace(/[\r\n]/g, '');
}

function persistEnvValue(key, value) {
  if (!value) return;
  try {
    const { ENV_FILE } = require('../../../../runtime/paths');
    const safeKey = sanitizeEnvKey(key);
    const safeValue = sanitizeEnvValue(value);
    const raw = fs.existsSync(ENV_FILE) ? fs.readFileSync(ENV_FILE, 'utf8') : '';
    const lines = raw ? raw.split('\n') : [];
    let replaced = false;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].startsWith(`${safeKey}=`)) {
        lines[i] = `${safeKey}=${safeValue}`;
        replaced = true;
        break;
      }
    }
    if (!replaced) lines.push(`${safeKey}=${safeValue}`);
    const output = lines.filter((_, idx, arr) => idx !== arr.length - 1 || arr[idx] !== '').join('\n') + '\n';
    fs.mkdirSync(path.dirname(ENV_FILE), { recursive: true });
    fs.writeFileSync(ENV_FILE, output, { mode: 0o600 });
  } catch { }
}

async function refreshClaudeCodeAccessToken(refreshToken, fetchImpl = fetch) {
  if (!refreshToken) return null;
  const response = await fetchImpl(CLAUDE_CODE_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: CLAUDE_CODE_CLIENT_ID,
      scope: CLAUDE_CODE_SCOPES,
    }),
  });

  const text = await response.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = {};
  }

  if (!response.ok) {
    const detail = data?.error?.message || data?.error_description || data?.error || text || 'Unknown error';
    throw new Error(`Claude Code OAuth refresh failed: HTTP ${response.status} ${detail}`);
  }
  if (!data.access_token) {
    throw new Error('Claude Code OAuth refresh succeeded but no access_token was returned.');
  }

  return {
    access: data.access_token,
    refresh: data.refresh_token || refreshToken,
    expires: normalizeExpiresAt(data),
  };
}

function isAuthenticationError(err) {
  return err?.status === 401 || err?.error?.type === 'authentication_error';
}

function isInferenceScopeError(err) {
  const message = String(err?.error?.message || err?.message || '');
  const type = String(err?.error?.type || err?.type || '');
  return err?.status === 403
    && (type === 'permission_error' || message.includes('"permission_error"'))
    && message.includes('scope requirement')
    && message.includes('user:inference');
}

function formatClaudeCodeCredentialError(err) {
  if (isInferenceScopeError(err)) {
    return new Error(`Claude Code OAuth token is missing inference scope. Re-run \`neoagent login claude-code\` to create a token with ${CLAUDE_CODE_SCOPES}.`);
  }
  return err;
}

class ClaudeCodeProvider extends AnthropicProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'claude-code';
    this.models = [
      'claude-opus-4-7',
      'claude-sonnet-4-6',
      'claude-haiku-4-5-20251001',
    ];
    this.contextWindows = {
      'claude-opus-4-7': 200000,
      'claude-sonnet-4-6': 200000,
      'claude-haiku-4-5-20251001': 200000,
    };

    const cliTokenRecord = readClaudeCliTokenRecord();
    const authToken = config.apiKey || process.env.CLAUDE_CODE_OAUTH_TOKEN || cliTokenRecord.access;
    if (!authToken) {
      console.warn('[ClaudeCode] No access token. Run `neoagent login claude-code` to authenticate.');
    }

    this.authToken = authToken || null;
    this.refreshToken = config.refreshToken || process.env.CLAUDE_CODE_REFRESH_TOKEN || cliTokenRecord.refresh || null;
    this.fetchImpl = config.fetch || fetch;
    this.baseURL = config.baseUrl || CLAUDE_CODE_BASE_URL;
    this.defaultHeaders = {
      ...(config.defaultHeaders || {}),
      accept: 'application/json',
      'anthropic-dangerous-direct-browser-access': 'true',
      'anthropic-beta': mergeAnthropicBeta(config.defaultHeaders?.['anthropic-beta']),
      'user-agent': `claude-cli/${CLAUDE_CODE_VERSION}`,
      'x-app': 'cli',
    };

    this.client = this.createClient(this.authToken, config);
  }

  createClient(authToken, config = this.config) {
    // OAuth tokens use Authorization: Bearer. Claude Code subscription inference
    // also requires the Claude Code beta surface headers used by the official CLI.
    return new Anthropic({
      authToken: authToken || undefined,
      baseURL: this.baseURL,
      defaultHeaders: authToken ? this.defaultHeaders : config.defaultHeaders,
      ...(this.fetchImpl ? { fetch: this.fetchImpl } : {}),
    });
  }

  async refreshClient() {
    const refreshed = await refreshClaudeCodeAccessToken(this.refreshToken, this.fetchImpl);
    if (!refreshed?.access) return false;
    this.authToken = refreshed.access;
    this.refreshToken = refreshed.refresh || this.refreshToken;
    process.env.CLAUDE_CODE_OAUTH_TOKEN = this.authToken;
    persistEnvValue('CLAUDE_CODE_OAUTH_TOKEN', this.authToken);
    if (this.refreshToken) {
      process.env.CLAUDE_CODE_REFRESH_TOKEN = this.refreshToken;
      persistEnvValue('CLAUDE_CODE_REFRESH_TOKEN', this.refreshToken);
    }
    this.client = this.createClient(this.authToken);
    return true;
  }

  convertMessages(messages) {
    const converted = super.convertMessages(messages);
    if (!converted.system) {
      converted.system = [{ type: 'text', text: CLAUDE_CODE_SYSTEM_PROMPT }];
      return converted;
    }
    converted.system = [
      { type: 'text', text: CLAUDE_CODE_SYSTEM_PROMPT },
      { type: 'text', text: converted.system },
    ];
    return converted;
  }

  async chat(messages, tools = [], options = {}) {
    try {
      return await super.chat(messages, tools, options);
    } catch (err) {
      if ((!isAuthenticationError(err) && !isInferenceScopeError(err)) || !this.refreshToken) {
        throw formatClaudeCodeCredentialError(err);
      }
      await this.refreshClient();
      try {
        return await super.chat(messages, tools, options);
      } catch (retryErr) {
        throw formatClaudeCodeCredentialError(retryErr);
      }
    }
  }

  async *stream(messages, tools = [], options = {}) {
    try {
      yield* super.stream(messages, tools, options);
    } catch (err) {
      if ((!isAuthenticationError(err) && !isInferenceScopeError(err)) || !this.refreshToken) {
        throw formatClaudeCodeCredentialError(err);
      }
      await this.refreshClient();
      try {
        yield* super.stream(messages, tools, options);
      } catch (retryErr) {
        throw formatClaudeCodeCredentialError(retryErr);
      }
    }
  }
}

module.exports = { ClaudeCodeProvider, readClaudeCliToken, refreshClaudeCodeAccessToken, CLAUDE_CODE_SCOPES };
