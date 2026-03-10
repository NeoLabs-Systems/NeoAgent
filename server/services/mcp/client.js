const EventEmitter = require('events');
const crypto = require('crypto');
const db = require('../../db/database');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { SSEClientTransport } = require('@modelcontextprotocol/sdk/client/sse.js');

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
    // Throw error so the API route catches it and returns the URL to the frontend
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

class MCPClient extends EventEmitter {
  constructor() {
    super();
    this.servers = new Map();
  }

  async startServer(serverId, url, name = '') {
    if (this.servers.has(serverId)) {
      await this.stopServer(serverId);
    }

    const slug = (name || String(serverId)).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
    try {
      const serverRow = db.prepare('SELECT config FROM mcp_servers WHERE id = ?').get(serverId);
      let configObj = {};
      let authObj = {};
      if (serverRow) {
        configObj = JSON.parse(serverRow.config || '{}');
        authObj = configObj.auth || {};
      }

      const transportOpts = {
        requestInit: { headers: {} },
        eventSourceInit: { headers: {} }
      };

      if (authObj.type === 'bearer' && authObj.token) {
        const h = `Bearer ${authObj.token}`;
        transportOpts.requestInit.headers['Authorization'] = h;
        // Native EventSource doesn't support headers well in browsers, but Node.js EventSource / sse.js might
        transportOpts.eventSourceInit.headers['Authorization'] = h;
      } else if (authObj.type === 'oauth') {
        transportOpts.authProvider = new DBAuthProvider(serverId, authObj.clientId, authObj.authServerUrl);
      }

      const transport = new SSEClientTransport(new URL(url), transportOpts);
      const client = new Client(
        { name: 'NeoAgent', version: '1.0.0' },
        { capabilities: { tools: {} } }
      );

      const serverObj = {
        id: serverId,
        url,
        slug,
        name: name || String(serverId),
        command: url,
        client,
        transport,
        tools: [],
        status: 'starting'
      };

      this.servers.set(serverId, serverObj);

      await client.connect(transport);

      const server = this.servers.get(serverId);
      if (server) {
        server.status = 'running';
        this.emit('server_status', { serverId, status: 'running' });
      }

      return { status: 'running' };
    } catch (err) {
      const server = this.servers.get(serverId);
      if (server) {
        server.status = 'error';
        this.emit('server_status', { serverId, status: 'error', error: err.message });
      }
      throw err;
    }
  }

  async finishOAuth(serverId, code) {
    const server = this.servers.get(serverId);
    if (!server || !server.transport) {
      throw new Error(`Server ${serverId} transport not initialized`);
    }
    await server.transport.finishAuth(code);
    await server.client.connect(server.transport).catch(() => { }); // Reconnect using tokens

    server.status = 'running';
    this.emit('server_status', { serverId, status: 'running' });
  }

  async stopServer(serverId) {
    const server = this.servers.get(serverId);
    if (!server) return;

    try {
      if (server.client) await server.client.close();
    } catch (err) {
      console.error(`Error closing MCP client ${serverId}:`, err);
    }

    this.servers.delete(serverId);
    this.emit('server_status', { serverId, status: 'stopped' });
  }

  async listTools(serverId) {
    const server = this.servers.get(serverId);
    if (!server || server.status !== 'running') {
      throw new Error(`Server ${serverId} not running`);
    }

    const response = await server.client.listTools();
    server.tools = response.tools || [];
    return server.tools;
  }

  async callTool(serverId, toolName, args = {}) {
    const server = this.servers.get(serverId);
    if (!server || server.status !== 'running') {
      throw new Error(`Server ${serverId} not running`);
    }

    return await server.client.callTool({
      name: toolName,
      arguments: args
    });
  }

  async callToolByName(fullName, args = {}) {
    for (const [serverId, server] of this.servers) {
      const prefix = `mcp_${server.slug}_`;
      if (fullName.startsWith(prefix)) {
        const originalName = fullName.substring(prefix.length);
        return await this.callTool(serverId, originalName, args);
      }
    }
    return null;
  }

  getAllTools() {
    const allTools = [];
    for (const [serverId, server] of this.servers) {
      if (server.status !== 'running') continue;
      for (const tool of server.tools) {
        allTools.push({
          ...tool,
          name: `mcp_${server.slug}_${tool.name}`,
          originalName: tool.name,
          parameters: tool.inputSchema || tool.parameters,
          serverId
        });
      }
    }
    return allTools;
  }

  getStatus() {
    const statuses = {};
    for (const [serverId, server] of this.servers) {
      statuses[serverId] = {
        status: server.status,
        command: server.url,
        args: [],
        toolCount: server.tools.length,
        serverInfo: null
      };
    }
    return statuses;
  }

  async loadFromDB(userId) {
    const servers = db.prepare('SELECT * FROM mcp_servers WHERE user_id = ? AND enabled = 1').all(userId);
    const results = [];

    for (const srv of servers) {
      try {
        await this.startServer(srv.id, srv.command, srv.name);
        await this.listTools(srv.id);
        results.push({ id: srv.id, name: srv.name, status: 'running' });
      } catch (err) {
        console.error(`Failed to start MCP server ${srv.name}:`, err.message);
        results.push({ id: srv.id, name: srv.name, status: 'error', error: err.message });
      }
    }

    return results;
  }

  async shutdown() {
    const promises = [];
    for (const serverId of this.servers.keys()) {
      promises.push(this.stopServer(serverId));
    }
    await Promise.allSettled(promises);
  }
}

module.exports = { MCPClient };
