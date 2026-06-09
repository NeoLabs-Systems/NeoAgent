'use strict';

const db = require('../../db/database');
const { normalizeServerId } = require('./client_support');

function scheduleReconnect(manager, serverId, userId, options) {
  serverId = normalizeServerId(serverId);
  if (manager._isShuttingDown || manager._reconnectTimers.has(serverId)) return;
  const server = manager.servers.get(serverId);
  if (!server || server.status === 'auth_required') return;

  const attempts = Math.max(1, manager._reconnectAttempts.get(serverId) || 1);
  const delayMs = Math.min(
    manager._reconnectDelayMs * (2 ** Math.min(attempts - 1, 20)),
    manager._maxReconnectDelayMs,
  );
  server.nextRetryAt = new Date(Date.now() + delayMs).toISOString();
  manager._setServerStatus(server, 'reconnecting');

  const timer = setTimeout(async () => {
    manager._reconnectTimers.delete(serverId);
    if (manager._isShuttingDown) return;
    const currentServer = manager.servers.get(serverId);
    if (!currentServer || currentServer.status === 'running') return;

    const row = db.prepare(
      'SELECT * FROM mcp_servers WHERE id = ? AND enabled = 1'
    ).get(serverId);
    if (!row) {
      await manager.stopServer(serverId);
      return;
    }

    try {
      await manager.startServer(serverId, row.command, row.name, userId, {
        ...options,
        _isReconnect: true,
      });
      console.log(`[MCP] Reconnected to ${row.name}`);
    } catch {
      const failedServer = manager.servers.get(serverId);
      if (
        failedServer
        && failedServer.status !== 'auth_required'
        && !manager._isShuttingDown
      ) {
        scheduleReconnect(manager, serverId, userId, options);
      }
    }
  }, delayMs);
  timer.unref?.();

  manager._reconnectTimers.set(serverId, timer);
}

async function loadFromDB(manager, userId) {
  const servers = db.prepare(
    'SELECT * FROM mcp_servers WHERE user_id = ? AND enabled = 1'
  ).all(userId);
  const results = [];

  for (const serverRow of servers) {
    try {
      await manager.startServer(
        serverRow.id,
        serverRow.command,
        serverRow.name,
        userId,
        { agentId: serverRow.agent_id },
      );
      results.push({
        id: serverRow.id,
        name: serverRow.name,
        status: 'running',
      });
    } catch (err) {
      const message = err.message;
      console.error(`[MCP] Failed to start "${serverRow.name}":`, message);
      const server = manager.servers.get(serverRow.id);
      if (server && server.status !== 'auth_required') {
        scheduleReconnect(
          manager,
          serverRow.id,
          userId,
          { agentId: serverRow.agent_id },
        );
      }
      results.push({
        id: serverRow.id,
        name: serverRow.name,
        status: server?.status || 'error',
        error: message,
      });
    }
  }

  return results;
}

async function shutdown(manager) {
  manager._isShuttingDown = true;
  for (const timer of manager._reconnectTimers.values()) {
    clearTimeout(timer);
  }
  manager._reconnectTimers.clear();

  const stops = Array.from(manager.servers.keys())
    .map((serverId) => manager.stopServer(serverId));
  await Promise.allSettled(stops);
}

module.exports = {
  loadFromDB,
  scheduleReconnect,
  shutdown,
};
