'use strict';

const EventEmitter = require('events');
const crypto = require('crypto');
const db = require('../../db/database');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { SSEClientTransport } = require('@modelcontextprotocol/sdk/client/sse.js');
const { validateRemoteMcpEndpoint } = require('../runtime/mcp');

const CONSECUTIVE_FAIL_LIMIT = 3;
const RECONNECT_DELAY_MS = 60_000;

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
    return `${this.serverId}::${crypto.randomBytes(16).toString('hex')}`;
  }

  clientInformation() {
    return { client_id: this.clientId };
  }

  _getConfig() {
    const row = db.prepare('SELECT config FROM mcp_servers WHERE id = ?').get(this.serverId);
    return row ? JSON.parse(row.config || '{}') : {};
  }

  _saveConfig(config) {
    db.prepare('UPDATE mcp_servers SET config = ? WHERE id = ?').run(JSON.stringify(config), this.serverId);
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

function extractErrorMessage(err) {
  const raw = err?.message || String(err || 'Unknown error');
  // Strip HTML bodies (e.g. Cloudflare 530 error pages) — keep only the first line
  if (raw.includes('<!doctype') || raw.includes('<html') || raw.includes('<!DOCTYPE')) {
    const httpMatch = raw.match(/HTTP (\d+)/i);
    return httpMatch
      ? `Server returned HTTP ${httpMatch[1]} — the MCP endpoint may be down or misconfigured`
      : 'Server returned an HTML error page — the MCP endpoint may be down or misconfigured';
  }
  // ECONNREFUSED: pull out just the host/port
  if (err?.code === 'ECONNREFUSED' || raw.includes('ECONNREFUSED')) {
    const addrMatch = raw.match(/connect ECONNREFUSED ([^\s,]+)/);
    return addrMatch
      ? `Connection refused at ${addrMatch[1]} — is the MCP server running?`
      : 'Connection refused — the MCP server is not reachable';
  }
  return raw.split('\n')[0].trim();
}

class MCPClient extends EventEmitter {
  constructor() {
    super();
    this.servers = new Map();
    this._reconnectTimers = new Map();
  }

  async startServer(serverId, url, name = '', userId = null, options = {}) {
    if (this.servers.has(serverId)) {
      await this.stopServer(serverId);
    }

    const slug = (name || String(serverId)).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
    try {
      const endpoint = validateRemoteMcpEndpoint(url);
      const serverRow = db.prepare('SELECT config FROM mcp_servers WHERE id = ?').get(serverId);
      let configObj = {};
      let authObj = {};
      if (serverRow) {
        configObj = JSON.parse(serverRow.config || '{}');
        authObj = configObj.auth || {};
      }

      const transportOpts = {
        requestInit: { headers: {} },
        eventSourceInit: { headers: {} },
      };

      if (authObj.type === 'bearer' && authObj.token) {
        const h = `Bearer ${authObj.token}`;
        transportOpts.requestInit.headers['Authorization'] = h;
        transportOpts.eventSourceInit.headers['Authorization'] = h;
      } else if (authObj.type === 'oauth') {
        transportOpts.authProvider = new DBAuthProvider(serverId, authObj.clientId, authObj.authServerUrl);
      }

      const transport = new SSEClientTransport(new URL(endpoint), transportOpts);
      const client = new Client(
        { name: 'NeoAgent', version: '1.0.0' },
        { capabilities: { tools: {} } },
      );

      const serverObj = {
        id: serverId,
        userId,
        agentId: options.agentId || null,
        url: endpoint,
        slug,
        name: name || String(serverId),
        command: endpoint,
        client,
        transport,
        tools: [],
        status: 'starting',
        consecutiveFails: 0,
        lastError: null,
      };

      this.servers.set(serverId, serverObj);

      await client.connect(transport);

      const server = this.servers.get(serverId);
      if (server) {
        server.status = 'running';
        server.consecutiveFails = 0;
        server.lastError = null;
        this.emit('server_status', { serverId, status: 'running' });
      }

      return { status: 'running' };
    } catch (err) {
      const message = extractErrorMessage(err);
      const server = this.servers.get(serverId);
      if (server) {
        server.consecutiveFails = (server.consecutiveFails || 0) + 1;
        server.lastError = message;
        server.status = 'error';
        this.emit('server_status', { serverId, status: 'error', error: message });
      }
      const friendlyErr = new Error(message);
      friendlyErr.originalError = err;
      throw friendlyErr;
    }
  }

  async finishOAuth(serverId, code) {
    const server = this.servers.get(serverId);
    if (!server || !server.transport) {
      throw new Error(`Server ${serverId} transport not initialized`);
    }
    await server.transport.finishAuth(code);
    await server.client.connect(server.transport).catch(() => {});

    server.status = 'running';
    server.consecutiveFails = 0;
    server.lastError = null;
    this.emit('server_status', { serverId, status: 'running' });
  }

  async stopServer(serverId) {
    const timer = this._reconnectTimers.get(serverId);
    if (timer) {
      clearTimeout(timer);
      this._reconnectTimers.delete(serverId);
    }

    const server = this.servers.get(serverId);
    if (!server) return;

    try {
      if (server.client) await server.client.close();
    } catch (err) {
      console.error(`[MCP] Error closing client ${serverId}:`, err.message);
    }

    this.servers.delete(serverId);
    this.emit('server_status', { serverId, status: 'stopped' });
  }

  _scheduleReconnect(serverId, userId, options) {
    if (this._reconnectTimers.has(serverId)) return;

    const timer = setTimeout(async () => {
      this._reconnectTimers.delete(serverId);
      const server = this.servers.get(serverId);
      if (!server || server.status === 'running') return;

      const row = db.prepare('SELECT * FROM mcp_servers WHERE id = ? AND enabled = 1').get(serverId);
      if (!row) return;

      try {
        await this.startServer(serverId, row.command, row.name, userId, options);
        await this.listTools(serverId, userId);
        console.log(`[MCP] Reconnected to ${row.name}`);
      } catch (err) {
        const server = this.servers.get(serverId);
        if (server && server.consecutiveFails < CONSECUTIVE_FAIL_LIMIT) {
          this._scheduleReconnect(serverId, userId, options);
        } else {
          console.warn(`[MCP] ${row.name} disabled after ${CONSECUTIVE_FAIL_LIMIT} consecutive failures: ${err.message}`);
        }
      }
    }, RECONNECT_DELAY_MS);

    this._reconnectTimers.set(serverId, timer);
  }

  _getOwnedServer(serverId, userId = null) {
    const server = this.servers.get(serverId);
    if (!server) return null;
    if (userId != null && server.userId !== userId) return null;
    return server;
  }

  async listTools(serverId, userId = null) {
    const server = this._getOwnedServer(serverId, userId);
    if (!server || server.status !== 'running') {
      throw new Error(`Server ${serverId} not running`);
    }

    const response = await server.client.listTools();
    server.tools = response.tools || [];
    return server.tools;
  }

  async callTool(serverId, toolName, args = {}, userId = null) {
    const server = this._getOwnedServer(serverId, userId);
    if (!server) throw new Error(`Server ${serverId} not found`);

    if (server.status !== 'running') {
      const hint = server.lastError ? ` (${server.lastError})` : '';
      throw new Error(`MCP server "${server.name}" is not available${hint}`);
    }

    try {
      const result = await server.client.callTool({ name: toolName, arguments: args });
      server.consecutiveFails = 0;
      return result;
    } catch (err) {
      const message = extractErrorMessage(err);
      server.consecutiveFails = (server.consecutiveFails || 0) + 1;
      server.lastError = message;

      if (server.consecutiveFails >= CONSECUTIVE_FAIL_LIMIT) {
        server.status = 'error';
        this.emit('server_status', { serverId, status: 'error', error: message });
        this._scheduleReconnect(serverId, server.userId, { agentId: server.agentId });
      }

      throw new Error(`MCP tool "${toolName}" failed: ${message}`);
    }
  }

  async callToolByName(fullName, args = {}, userId = null, options = {}) {
    for (const [serverId, server] of this.servers) {
      if (userId != null && server.userId !== userId) continue;
      if (options.agentId && server.agentId && server.agentId !== options.agentId) continue;
      const prefix = `mcp_${server.slug}_`;
      if (!fullName.startsWith(prefix)) continue;

      const originalName = fullName.substring(prefix.length);
      return await this.callTool(serverId, originalName, args, userId);
    }
    return null;
  }

  getAllTools(userId = null, options = {}) {
    const allTools = [];
    for (const [serverId, server] of this.servers) {
      if (userId != null && server.userId !== userId) continue;
      if (options.agentId && server.agentId && server.agentId !== options.agentId) continue;
      if (server.status !== 'running') continue;
      for (const tool of server.tools) {
        allTools.push({
          ...tool,
          name: `mcp_${server.slug}_${tool.name}`,
          originalName: tool.name,
          parameters: tool.inputSchema || tool.parameters,
          serverId,
        });
      }
    }
    return allTools;
  }

  getStatus(userId = null, options = {}) {
    const statuses = {};
    const agentId = options.agentId || options.agent_id || null;
    for (const [serverId, server] of this.servers) {
      if (userId != null && server.userId !== userId) continue;
      if (agentId && server.agentId && server.agentId !== agentId) continue;
      statuses[serverId] = {
        status: server.status,
        command: server.url,
        args: [],
        toolCount: server.tools.length,
        error: server.lastError || null,
        consecutiveFails: server.consecutiveFails || 0,
        serverInfo: null,
      };
    }
    return statuses;
  }

  async loadFromDB(userId) {
    const servers = db.prepare('SELECT * FROM mcp_servers WHERE user_id = ? AND enabled = 1').all(userId);
    const results = [];

    for (const srv of servers) {
      try {
        await this.startServer(srv.id, srv.command, srv.name, userId, { agentId: srv.agent_id });
        await this.listTools(srv.id, userId);
        results.push({ id: srv.id, name: srv.name, status: 'running' });
      } catch (err) {
        const message = err.message;
        console.error(`[MCP] Failed to start "${srv.name}":`, message);
        // Schedule a reconnect attempt for transient failures (not auth errors)
        const server = this.servers.get(srv.id);
        if (server) {
          this._scheduleReconnect(srv.id, userId, { agentId: srv.agent_id });
        }
        results.push({ id: srv.id, name: srv.name, status: 'error', error: message });
      }
    }

    return results;
  }

  async shutdown() {
    for (const timer of this._reconnectTimers.values()) {
      clearTimeout(timer);
    }
    this._reconnectTimers.clear();

    const promises = [];
    for (const serverId of this.servers.keys()) {
      promises.push(this.stopServer(serverId));
    }
    await Promise.allSettled(promises);
  }
}

module.exports = { MCPClient };
