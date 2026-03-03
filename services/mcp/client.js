const { spawn } = require('child_process');
const path = require('path');
const EventEmitter = require('events');
const db = require('../../db/database');

class MCPClient extends EventEmitter {
  constructor() {
    super();
    this.servers = new Map();
  }

  async startServer(serverId, command, args = [], env = {}) {
    if (this.servers.has(serverId)) {
      await this.stopServer(serverId);
    }

    return new Promise((resolve, reject) => {
      const proc = spawn(command, args, {
        env: { ...process.env, ...env },
        stdio: ['pipe', 'pipe', 'pipe'],
        shell: true,
        cwd: process.cwd()
      });

      const server = {
        process: proc,
        id: serverId,
        command,
        args,
        env,
        tools: [],
        status: 'starting',
        buffer: '',
        pendingRequests: new Map(),
        nextId: 1
      };

      this.servers.set(serverId, server);

      proc.stdout.on('data', (data) => {
        server.buffer += data.toString();
        const lines = server.buffer.split('\n');
        server.buffer = lines.pop();

        for (const line of lines) {
          if (!line.trim()) continue;
          try {
            const msg = JSON.parse(line);
            this._handleMessage(serverId, msg);
          } catch (e) {
            // Non-JSON output, ignore
          }
        }
      });

      proc.stderr.on('data', (data) => {
        console.error(`[MCP:${serverId}] stderr:`, data.toString());
        this.emit('server_error', { serverId, error: data.toString() });
      });

      proc.on('error', (err) => {
        server.status = 'error';
        this.emit('server_status', { serverId, status: 'error', error: err.message });
        reject(err);
      });

      proc.on('exit', (code) => {
        server.status = 'stopped';
        this.servers.delete(serverId);
        this.emit('server_status', { serverId, status: 'stopped', exitCode: code });
      });

      // Send initialize request
      const initId = this._sendRequest(serverId, 'initialize', {
        protocolVersion: '2024-11-05',
        capabilities: { tools: {} },
        clientInfo: { name: 'NeoAgent', version: '1.0.0' }
      });

      const timeout = setTimeout(() => {
        reject(new Error('MCP initialize timeout'));
      }, 15000);

      server.pendingRequests.set(initId, {
        resolve: (result) => {
          clearTimeout(timeout);
          server.status = 'running';
          server.serverInfo = result;
          this._sendNotification(serverId, 'notifications/initialized', {});
          this.emit('server_status', { serverId, status: 'running', serverInfo: result });
          resolve({ status: 'running', serverInfo: result });
        },
        reject: (err) => {
          clearTimeout(timeout);
          reject(err);
        }
      });
    });
  }

  async stopServer(serverId) {
    const server = this.servers.get(serverId);
    if (!server) return;

    server.process.kill('SIGTERM');
    await new Promise(resolve => setTimeout(resolve, 2000));

    if (server.process && !server.process.killed) {
      server.process.kill('SIGKILL');
    }

    this.servers.delete(serverId);
  }

  async listTools(serverId) {
    const server = this.servers.get(serverId);
    if (!server || server.status !== 'running') {
      throw new Error(`Server ${serverId} not running`);
    }

    const result = await this._request(serverId, 'tools/list', {});
    server.tools = result.tools || [];
    return server.tools;
  }

  async callTool(serverId, toolName, args = {}) {
    const server = this.servers.get(serverId);
    if (!server || server.status !== 'running') {
      throw new Error(`Server ${serverId} not running`);
    }

    const result = await this._request(serverId, 'tools/call', {
      name: toolName,
      arguments: args
    });

    return result;
  }

  async listResources(serverId) {
    return this._request(serverId, 'resources/list', {});
  }

  async readResource(serverId, uri) {
    return this._request(serverId, 'resources/read', { uri });
  }

  async listPrompts(serverId) {
    return this._request(serverId, 'prompts/list', {});
  }

  async getPrompt(serverId, name, args = {}) {
    return this._request(serverId, 'prompts/get', { name, arguments: args });
  }

  _sendRequest(serverId, method, params) {
    const server = this.servers.get(serverId);
    if (!server) throw new Error(`Server ${serverId} not found`);

    const id = server.nextId++;
    const msg = JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n';
    server.process.stdin.write(msg);
    return id;
  }

  _sendNotification(serverId, method, params) {
    const server = this.servers.get(serverId);
    if (!server) return;

    const msg = JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n';
    server.process.stdin.write(msg);
  }

  _request(serverId, method, params) {
    return new Promise((resolve, reject) => {
      const id = this._sendRequest(serverId, method, params);
      const server = this.servers.get(serverId);

      const timeout = setTimeout(() => {
        server.pendingRequests.delete(id);
        reject(new Error(`MCP request timeout: ${method}`));
      }, 30000);

      server.pendingRequests.set(id, {
        resolve: (result) => {
          clearTimeout(timeout);
          resolve(result);
        },
        reject: (err) => {
          clearTimeout(timeout);
          reject(err);
        }
      });
    });
  }

  _handleMessage(serverId, msg) {
    const server = this.servers.get(serverId);
    if (!server) return;

    if (msg.id !== undefined && server.pendingRequests.has(msg.id)) {
      const pending = server.pendingRequests.get(msg.id);
      server.pendingRequests.delete(msg.id);

      if (msg.error) {
        pending.reject(new Error(msg.error.message || 'MCP error'));
      } else {
        pending.resolve(msg.result);
      }
    } else if (msg.method) {
      this.emit('notification', { serverId, method: msg.method, params: msg.params });
    }
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
        command: server.command,
        args: server.args,
        toolCount: server.tools.length,
        serverInfo: server.serverInfo || null
      };
    }
    return statuses;
  }

  async loadFromDB(userId) {
    const servers = db.prepare('SELECT * FROM mcp_servers WHERE user_id = ? AND enabled = 1').all(userId);
    const results = [];

    for (const srv of servers) {
      try {
        const config = JSON.parse(srv.config || '{}');
        await this.startServer(srv.id, srv.command, config.args || [], config.env || {});
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
