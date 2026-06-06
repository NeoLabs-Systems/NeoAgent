'use strict';

const EventEmitter = require('events');
const db = require('../../db/database');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { SSEClientTransport } = require('@modelcontextprotocol/sdk/client/sse.js');
const { validateRemoteMcpEndpoint } = require('../runtime/mcp');
const {
  buildTransportOptions,
  extractErrorMessage,
  normalizeServerId,
} = require('./client_support');
const recovery = require('./recovery');
const toolOperations = require('./tool_operations');

const DEFAULT_RECONNECT_DELAY_MS = 60_000;
const DEFAULT_MAX_RECONNECT_DELAY_MS = 15 * 60_000;
const DEFAULT_OPERATION_TIMEOUT_MS = 30_000;

class MCPClient extends EventEmitter {
  constructor(options = {}) {
    super();
    this.servers = new Map();
    this._reconnectTimers = new Map();
    this._reconnectAttempts = new Map();
    this._lifecycleVersions = new Map();
    this._isShuttingDown = false;
    this._reconnectDelayMs = options.reconnectDelayMs ?? DEFAULT_RECONNECT_DELAY_MS;
    this._maxReconnectDelayMs = options.maxReconnectDelayMs ?? DEFAULT_MAX_RECONNECT_DELAY_MS;
    this._operationTimeoutMs = options.operationTimeoutMs ?? DEFAULT_OPERATION_TIMEOUT_MS;
    this._toolFailureThreshold = options.toolFailureThreshold ?? 3;
    this._createTransport = options.createTransport
      || ((endpoint, transportOptions) => new SSEClientTransport(new URL(endpoint), transportOptions));
    this._createClient = options.createClient
      || (() => new Client(
        { name: 'NeoAgent', version: '1.0.0' },
        { capabilities: { tools: {} } },
      ));
  }

  _nextLifecycleVersion(serverId) {
    serverId = normalizeServerId(serverId);
    const version = (this._lifecycleVersions.get(serverId) || 0) + 1;
    this._lifecycleVersions.set(serverId, version);
    return version;
  }

  _isCurrentLifecycle(serverId, server, version) {
    serverId = normalizeServerId(serverId);
    return (
      !this._isShuttingDown
      && this._lifecycleVersions.get(serverId) === version
      && this.servers.get(serverId) === server
    );
  }

  _cancelReconnect(serverId) {
    serverId = normalizeServerId(serverId);
    const timer = this._reconnectTimers.get(serverId);
    if (!timer) return;
    clearTimeout(timer);
    this._reconnectTimers.delete(serverId);
  }

  _persistStatus(serverId, status) {
    serverId = normalizeServerId(serverId);
    db.prepare('UPDATE mcp_servers SET status = ? WHERE id = ?').run(status, serverId);
  }

  _setServerStatus(server, status, extra = {}) {
    if (!server) return;
    server.status = status;
    Object.assign(server, extra);
    this._persistStatus(server.id, status);
    this.emit('server_status', {
      serverId: server.id,
      status,
      error: server.lastError || null,
      consecutiveFails: server.consecutiveFails || 0,
      nextRetryAt: server.nextRetryAt || null,
    });
  }

  async _closeClient(server) {
    if (!server?.client) return;
    try {
      await this._runWithTimeout(
        () => server.client.close(),
        `Closing MCP server "${server.name || server.id}"`,
      );
    } catch (err) {
      console.error(`[MCP] Error closing client ${server.id}:`, extractErrorMessage(err));
    }
  }

  _recordFailure(server, err) {
    const message = extractErrorMessage(err);
    const attempts = (this._reconnectAttempts.get(server.id) || 0) + 1;
    this._reconnectAttempts.set(server.id, attempts);
    server.consecutiveFails = attempts;
    server.lastError = message;
    server.nextRetryAt = null;
    this._setServerStatus(server, err?.requiresAuth ? 'auth_required' : 'error');
    return message;
  }

  async _runWithTimeout(operation, label) {
    let timer;
    const timeout = new Promise((_, reject) => {
      timer = setTimeout(() => {
        const error = new Error(`${label} timed out after ${this._operationTimeoutMs} ms`);
        error.code = 'MCP_OPERATION_TIMEOUT';
        reject(error);
      }, this._operationTimeoutMs);
    });

    try {
      return await Promise.race([Promise.resolve().then(operation), timeout]);
    } finally {
      clearTimeout(timer);
    }
  }

  async startServer(serverId, url, name = '', userId = null, options = {}) {
    serverId = normalizeServerId(serverId);
    if (this._isShuttingDown) {
      throw new Error('MCP client is shutting down');
    }

    const isReconnect = options._isReconnect === true;
    if (!isReconnect) {
      this._cancelReconnect(serverId);
      this._reconnectAttempts.delete(serverId);
    }

    const slug = (name || String(serverId)).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
    const previous = this.servers.get(serverId);
    const lifecycleVersion = this._nextLifecycleVersion(serverId);
    if (previous) {
      await this._closeClient(previous);
    }

    let serverObj = null;
    try {
      const endpoint = validateRemoteMcpEndpoint(url);
      const transportOpts = buildTransportOptions(serverId);
      const transport = this._createTransport(endpoint, transportOpts);
      const client = this._createClient();
      const previousFails = this._reconnectAttempts.get(serverId) || 0;

      serverObj = {
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
        consecutiveFails: previousFails,
        lastError: null,
        nextRetryAt: null,
      };

      this.servers.set(serverId, serverObj);
      this._setServerStatus(serverObj, 'starting');

      await this._runWithTimeout(
        () => client.connect(transport),
        `Connecting to MCP server "${serverObj.name}"`,
      );
      const response = await this._runWithTimeout(
        () => client.listTools(),
        `Discovering tools from MCP server "${serverObj.name}"`,
      );

      if (!this._isCurrentLifecycle(serverId, serverObj, lifecycleVersion)) {
        await this._closeClient(serverObj);
        const superseded = new Error(`MCP server ${serverId} start was superseded`);
        superseded.code = 'MCP_START_SUPERSEDED';
        throw superseded;
      }

      serverObj.tools = response.tools || [];
      serverObj.consecutiveFails = 0;
      serverObj.lastError = null;
      serverObj.nextRetryAt = null;
      this._reconnectAttempts.delete(serverId);
      this._setServerStatus(serverObj, 'running');

      return { status: 'running', tools: serverObj.tools };
    } catch (err) {
      if (err?.code === 'MCP_START_SUPERSEDED') {
        throw err;
      }
      if (serverObj && this.servers.get(serverId) === serverObj) {
        const requiresAuth = String(err?.message || '').startsWith('OAUTH_REDIRECT:');
        if (requiresAuth) err.requiresAuth = true;
        const message = this._recordFailure(serverObj, err);
        if (!requiresAuth) {
          await this._closeClient(serverObj);
        }
        const friendlyErr = new Error(message);
        friendlyErr.originalError = err;
        friendlyErr.requiresAuth = requiresAuth;
        throw friendlyErr;
      }
      if (previous && this.servers.get(serverId) === previous) {
        const message = this._recordFailure(previous, err);
        const friendlyErr = new Error(message);
        friendlyErr.originalError = err;
        throw friendlyErr;
      }
      throw err;
    }
  }

  async finishOAuth(serverId, code) {
    serverId = normalizeServerId(serverId);
    const server = this.servers.get(serverId);
    if (!server || !server.transport) {
      throw new Error(`Server ${serverId} transport not initialized`);
    }
    try {
      await this._runWithTimeout(
        () => server.transport.finishAuth(code),
        `Completing OAuth for MCP server "${server.name}"`,
      );
      await this._runWithTimeout(
        () => server.client.connect(server.transport),
        `Connecting to MCP server "${server.name}" after OAuth`,
      );
      const response = await this._runWithTimeout(
        () => server.client.listTools(),
        `Discovering tools from MCP server "${server.name}"`,
      );
      server.tools = response.tools || [];
      server.consecutiveFails = 0;
      server.lastError = null;
      server.nextRetryAt = null;
      this._reconnectAttempts.delete(serverId);
      this._setServerStatus(server, 'running');
      return { status: 'running', tools: server.tools };
    } catch (err) {
      const message = this._recordFailure(server, err);
      const friendlyErr = new Error(message);
      friendlyErr.originalError = err;
      throw friendlyErr;
    }
  }

  async stopServer(serverId) {
    serverId = normalizeServerId(serverId);
    this._cancelReconnect(serverId);
    this._reconnectAttempts.delete(serverId);
    this._nextLifecycleVersion(serverId);

    const server = this.servers.get(serverId);
    if (!server) {
      this._persistStatus(serverId, 'stopped');
      return { status: 'stopped' };
    }

    await this._closeClient(server);
    this.servers.delete(serverId);
    this._persistStatus(serverId, 'stopped');
    this.emit('server_status', { serverId, status: 'stopped' });
    return { status: 'stopped' };
  }

  _scheduleReconnect(serverId, userId, options) {
    return recovery.scheduleReconnect(this, serverId, userId, options);
  }

  _getOwnedServer(serverId, userId = null) {
    serverId = normalizeServerId(serverId);
    const server = this.servers.get(serverId);
    if (!server) return null;
    if (userId != null && server.userId !== userId) return null;
    return server;
  }

  async listTools(serverId, userId = null) {
    return toolOperations.listTools(this, serverId, userId);
  }

  async callTool(serverId, toolName, args = {}, userId = null) {
    return toolOperations.callTool(this, serverId, toolName, args, userId);
  }

  async callToolByName(fullName, args = {}, userId = null, options = {}) {
    return toolOperations.callToolByName(this, fullName, args, userId, options);
  }

  getAllTools(userId = null, options = {}) {
    return toolOperations.getAllTools(this, userId, options);
  }

  getStatus(userId = null, options = {}) {
    return toolOperations.getStatus(this, userId, options);
  }

  async loadFromDB(userId) {
    return recovery.loadFromDB(this, userId);
  }

  async shutdown() {
    return recovery.shutdown(this);
  }
}

module.exports = { MCPClient };
