const EventEmitter = require('events');
const db = require('../../db/database');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { SSEClientTransport } = require('@modelcontextprotocol/sdk/client/sse.js');

class MCPClient extends EventEmitter {
  constructor() {
    super();
    this.servers = new Map();
  }

  async startServer(serverId, url, dummyArgs = [], dummyEnv = {}) {
    if (this.servers.has(serverId)) {
      await this.stopServer(serverId);
    }

    // "url" is passed through the "command" field from the database for backward schema compatibility
    try {
      const transport = new SSEClientTransport(new URL(url));
      const client = new Client(
        { name: 'NeoAgent', version: '1.0.0' },
        { capabilities: { tools: {} } }
      );

      const serverObj = {
        id: serverId,
        url,
        command: url, // to keep UI and routers happy that expect 'command'
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

  getAllTools() {
    const allTools = [];
    for (const [serverId, server] of this.servers) {
      if (server.status !== 'running') continue;
      for (const tool of server.tools) {
        allTools.push({
          ...tool,
          serverId,
          fullName: `mcp_${serverId}_${tool.name}`
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
        await this.startServer(srv.id, srv.command);
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
