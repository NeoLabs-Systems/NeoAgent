'use strict';

// MCP servers tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'mcp_add_server',
    persistent: true,
    group: 'mcp', stepType: 'mcp', access: 'write', sideEffect: 'config', stateScope: 'config', latencyClass: 'remote',
    capabilities: ['mcp', 'server', 'connect'],
    description: 'Register and optionally start a new MCP (Model Context Protocol) server connection. Use this when the user asks to connect a new MCP server or when you discover a useful one. The server will appear in the MCP Servers page and its tools will be available to you immediately if auto_start is true.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Human-readable name for this server (e.g. "filesystem", "brave-search")' },
        command: { type: 'string', description: 'The executable to run, e.g. "npx" or "/usr/local/bin/my-mcp-server"' },
        args: { type: 'array', items: { type: 'string' }, description: 'Command-line arguments, e.g. ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]' },
        env: { type: 'object', description: 'Extra environment variables to pass to the server process, e.g. { "BRAVE_API_KEY": "abc123" }' },
        auto_start: { type: 'boolean', description: 'Start the server immediately after registering (default true)' }
      },
      required: ['name', 'command']
    }
  },
  {
    name: 'mcp_list_servers',
    group: 'mcp', stepType: 'mcp', access: 'read', stateScope: 'config', latencyClass: 'local',
    capabilities: ['mcp', 'server', 'list'],
    description: 'List all registered MCP servers with their status and available tool counts.',
    parameters: { type: 'object', properties: {} }
  },
  {
    name: 'mcp_remove_server',
    group: 'mcp', stepType: 'mcp', access: 'write', sideEffect: 'config', stateScope: 'config', latencyClass: 'local',
    capabilities: ['mcp', 'server', 'remove'],
    description: 'Stop and remove an MCP server connection by its numeric ID (get IDs from mcp_list_servers).',
    parameters: {
      type: 'object',
      properties: {
        server_id: { type: 'number', description: 'The numeric ID of the MCP server to remove' }
      },
      required: ['server_id']
    }
  },
];
