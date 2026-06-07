'use strict';

const crypto = require('crypto');
const db = require('../../db/database');

const OAUTH_STATE_TTL_MS = 10 * 60_000;

function hashOAuthState(value) {
  return crypto.createHash('sha256').update(String(value || '')).digest('hex');
}

class DBAuthProvider {
  constructor(serverId, clientId, authServerUrl) {
    this.serverId = serverId;
    this.clientId = clientId;
    this.authServerUrl = authServerUrl;
  }

  get redirectUrl() {
    const baseUrl = process.env.PUBLIC_URL || `http://localhost:${process.env.PORT || 3333}`;
    return `${baseUrl}/api/mcp/oauth/callback`;
  }

  get clientMetadata() {
    return { client_id: this.clientId };
  }

  state() {
    const state = `${this.serverId}::${crypto.randomBytes(16).toString('hex')}`;
    const config = this._getConfig();
    config.auth = config.auth || {};
    config.auth.oauthStateHash = hashOAuthState(state);
    config.auth.oauthStateCreatedAt = new Date().toISOString();
    this._saveConfig(config);
    return state;
  }

  clientInformation() {
    return { client_id: this.clientId };
  }

  _getConfig() {
    const row = db.prepare('SELECT config FROM mcp_servers WHERE id = ?').get(this.serverId);
    return row ? JSON.parse(row.config || '{}') : {};
  }

  _saveConfig(config) {
    db.prepare('UPDATE mcp_servers SET config = ? WHERE id = ?')
      .run(JSON.stringify(config), this.serverId);
  }

  tokens() {
    return this._getConfig().auth?.tokens;
  }

  saveTokens(tokens) {
    const config = this._getConfig();
    config.auth = config.auth || {};
    config.auth.tokens = tokens;
    this._saveConfig(config);
  }

  redirectToAuthorization(authorizationUrl) {
    throw new Error(`OAUTH_REDIRECT:${authorizationUrl.toString()}`);
  }

  saveCodeVerifier(codeVerifier) {
    const config = this._getConfig();
    config.auth = config.auth || {};
    config.auth.codeVerifier = codeVerifier;
    this._saveConfig(config);
  }

  codeVerifier() {
    return this._getConfig().auth?.codeVerifier;
  }
}

function consumeOAuthState(serverId, state) {
  const row = db.prepare('SELECT config FROM mcp_servers WHERE id = ?').get(serverId);
  if (!row) return false;

  let config;
  try {
    config = JSON.parse(row.config || '{}');
  } catch {
    return false;
  }

  const expectedHash = String(config.auth?.oauthStateHash || '');
  const createdAt = Date.parse(config.auth?.oauthStateCreatedAt || '');
  if (
    !expectedHash
    || !Number.isFinite(createdAt)
    || Date.now() - createdAt > OAUTH_STATE_TTL_MS
    || createdAt > Date.now() + 60_000
  ) {
    return false;
  }

  const actualHash = hashOAuthState(state);
  const expectedBuffer = Buffer.from(expectedHash, 'hex');
  const actualBuffer = Buffer.from(actualHash, 'hex');
  if (
    expectedBuffer.length !== actualBuffer.length
    || !crypto.timingSafeEqual(expectedBuffer, actualBuffer)
  ) {
    return false;
  }

  delete config.auth.oauthStateHash;
  delete config.auth.oauthStateCreatedAt;
  db.prepare('UPDATE mcp_servers SET config = ? WHERE id = ?')
    .run(JSON.stringify(config), serverId);
  return true;
}

function extractErrorMessage(err) {
  const raw = err?.message || String(err || 'Unknown error');
  if (raw.includes('<!doctype') || raw.includes('<html') || raw.includes('<!DOCTYPE')) {
    const httpMatch = raw.match(/HTTP (\d+)/i);
    return httpMatch
      ? `Server returned HTTP ${httpMatch[1]} - the MCP endpoint may be down or misconfigured`
      : 'Server returned an HTML error page - the MCP endpoint may be down or misconfigured';
  }
  if (err?.code === 'ECONNREFUSED' || raw.includes('ECONNREFUSED')) {
    const addrMatch = raw.match(/connect ECONNREFUSED ([^\s,]+)/);
    return addrMatch
      ? `Connection refused at ${addrMatch[1]} - is the MCP server running?`
      : 'Connection refused - the MCP server is not reachable';
  }
  return raw.split('\n')[0].trim();
}

function normalizeServerId(value) {
  const text = String(value ?? '').trim();
  if (!text) return value;
  const numeric = Number(text);
  return Number.isSafeInteger(numeric) && numeric > 0 ? numeric : value;
}

function buildTransportOptions(serverId) {
  const row = db.prepare('SELECT config FROM mcp_servers WHERE id = ?').get(serverId);
  const config = row ? JSON.parse(row.config || '{}') : {};
  const auth = config.auth || {};
  const transportOptions = {
    requestInit: { headers: {} },
    eventSourceInit: { headers: {} },
  };

  if (auth.type === 'bearer' && auth.token) {
    const authorization = `Bearer ${auth.token}`;
    transportOptions.requestInit.headers.Authorization = authorization;
    transportOptions.eventSourceInit.headers.Authorization = authorization;
  } else if (auth.type === 'oauth') {
    transportOptions.authProvider = new DBAuthProvider(
      serverId,
      auth.clientId,
      auth.authServerUrl,
    );
  }

  return transportOptions;
}

module.exports = {
  DBAuthProvider,
  buildTransportOptions,
  consumeOAuthState,
  extractErrorMessage,
  normalizeServerId,
};
