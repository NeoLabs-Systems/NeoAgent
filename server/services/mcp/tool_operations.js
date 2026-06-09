'use strict';

const { extractErrorMessage, normalizeServerId } = require('./client_support');

async function listTools(manager, serverId, userId = null) {
  serverId = normalizeServerId(serverId);
  const server = manager._getOwnedServer(serverId, userId);
  if (!server || server.status !== 'running') {
    throw new Error(`Server ${serverId} not running`);
  }

  try {
    const response = await manager._runWithTimeout(
      () => server.client.listTools(),
      `Discovering tools from MCP server "${server.name}"`,
    );
    server.tools = response.tools || [];
    server.consecutiveFails = 0;
    server.lastError = null;
    manager._reconnectAttempts.delete(serverId);
    return server.tools;
  } catch (err) {
    const message = manager._recordFailure(server, err);
    manager._scheduleReconnect(serverId, server.userId, { agentId: server.agentId });
    throw new Error(`Failed to list tools for MCP server "${server.name}": ${message}`);
  }
}

async function callTool(manager, serverId, toolName, args = {}, userId = null) {
  serverId = normalizeServerId(serverId);
  const server = manager._getOwnedServer(serverId, userId);
  if (!server) throw new Error(`Server ${serverId} not found`);

  if (server.status !== 'running') {
    const hint = server.lastError ? ` (${server.lastError})` : '';
    throw new Error(`MCP server "${server.name}" is not available${hint}`);
  }

  try {
    const result = await manager._runWithTimeout(
      () => server.client.callTool({ name: toolName, arguments: args }),
      `Calling MCP tool "${toolName}" on "${server.name}"`,
    );
    server.consecutiveFails = 0;
    server.lastError = null;
    manager._reconnectAttempts.delete(serverId);
    return result;
  } catch (err) {
    const message = extractErrorMessage(err);
    const consecutiveFails = (server.consecutiveFails || 0) + 1;
    server.consecutiveFails = consecutiveFails;
    server.lastError = message;

    if (consecutiveFails >= manager._toolFailureThreshold) {
      manager._reconnectAttempts.set(serverId, consecutiveFails);
      server.nextRetryAt = null;
      manager._setServerStatus(server, 'error');
      manager._scheduleReconnect(serverId, server.userId, { agentId: server.agentId });
    }

    throw new Error(`MCP tool "${toolName}" failed: ${message}`);
  }
}

async function callToolByName(manager, fullName, args = {}, userId = null, options = {}) {
  for (const [serverId, server] of manager.servers) {
    if (userId != null && server.userId !== userId) continue;
    if (options.agentId && server.agentId && server.agentId !== options.agentId) continue;
    const prefix = `mcp_${server.slug}_`;
    if (!fullName.startsWith(prefix)) continue;

    const originalName = fullName.substring(prefix.length);
    return callTool(manager, serverId, originalName, args, userId);
  }
  return null;
}

function getAllTools(manager, userId = null, options = {}) {
  const allTools = [];
  for (const [serverId, server] of manager.servers) {
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

function getStatus(manager, userId = null, options = {}) {
  const statuses = {};
  const agentId = options.agentId || options.agent_id || null;
  for (const [serverId, server] of manager.servers) {
    if (userId != null && server.userId !== userId) continue;
    if (agentId && server.agentId && server.agentId !== agentId) continue;
    statuses[serverId] = {
      status: server.status,
      command: server.url,
      args: [],
      toolCount: server.tools.length,
      error: server.lastError || null,
      consecutiveFails: server.consecutiveFails || 0,
      nextRetryAt: server.nextRetryAt || null,
      serverInfo: null,
    };
  }
  return statuses;
}

module.exports = {
  callTool,
  callToolByName,
  getAllTools,
  getStatus,
  listTools,
};
