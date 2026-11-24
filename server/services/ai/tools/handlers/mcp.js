'use strict';

const db = require('../../../../db/database');

const handlers = {
  async mcp_add_server(args, ctx) {
    const { agentId, mcp, userId } = ctx;
    const mcpClient = mcp();
    if (!mcpClient) return { error: 'MCP manager not available' };
    try {
    const config = { args: args.args || [], env: args.env || {} };
    const autoStart = args.auto_start !== false;
    const result = db.prepare(
      'INSERT INTO mcp_servers (user_id, agent_id, name, command, config, enabled) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(userId, agentId, args.name, args.command, JSON.stringify(config), autoStart ? 1 : 0);
    const serverId = result.lastInsertRowid;
    let tools = [];
    if (autoStart) {
      try {
        const startResult = await mcpClient.startServer(
          serverId,
          args.command,
          args.name,
          userId,
          { agentId }
        );
        tools = startResult.tools || [];
      } catch (startErr) {
        return { registered: true, id: serverId, started: false, error: `Registered but failed to start: ${startErr.message}` };
      }
    }
    return { registered: true, id: serverId, name: args.name, started: autoStart, toolCount: tools.length, tools: tools.map(t => t.name || t) };
    } catch (err) {
    return { error: err.message };
    }
  },

  async mcp_list_servers(args, ctx) {
    const { agentId, mcp, userId } = ctx;
    const mcpClient = mcp();
    const servers = db.prepare('SELECT * FROM mcp_servers WHERE user_id = ? AND agent_id = ? ORDER BY name ASC').all(userId, agentId);
    const liveStatuses = mcpClient ? mcpClient.getStatus(userId, { agentId }) : {};
    return {
    servers: servers.map(s => ({
      id: s.id,
      name: s.name,
      command: s.command,
      args: JSON.parse(s.config || '{}').args || [],
      enabled: !!s.enabled,
      status: liveStatuses[s.id]?.status || 'stopped',
      toolCount: liveStatuses[s.id]?.toolCount || 0,
      error: liveStatuses[s.id]?.error || null,
      consecutiveFails: liveStatuses[s.id]?.consecutiveFails || 0,
      nextRetryAt: liveStatuses[s.id]?.nextRetryAt || null
    }))
    };
  },

  async mcp_remove_server(args, ctx) {
    const { mcp, userId } = ctx;
    const mcpClient = mcp();
    const server = db.prepare('SELECT * FROM mcp_servers WHERE id = ? AND user_id = ?').get(args.server_id, userId);
    if (!server) return { error: `No MCP server with id ${args.server_id} found` };
    if (mcpClient) await mcpClient.stopServer(server.id).catch(() => { });
    db.prepare('DELETE FROM mcp_servers WHERE id = ?').run(server.id);
    return { removed: true, id: server.id, name: server.name };
  },
};

module.exports = { handlers };
