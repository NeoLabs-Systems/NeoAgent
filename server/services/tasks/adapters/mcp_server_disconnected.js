'use strict';

const { normalizeTrimmedText } = require('../security');
const { summaryParts } = require('./shared');

const FAILED_STATUSES = new Set(['error', 'auth_required']);

// Only a server that was running and then failed counts: its reconnect
// attempts fail again and again, and those are not new outages.
module.exports = {
  type: 'mcp_server_disconnected',
  label: 'MCP Server Failed',
  configHint: '{ serverId?: one MCP server, otherwise any }',
  async validateConfig(config = {}) {
    return { serverId: normalizeTrimmedText(config.serverId || config.server_id, 100) };
  },
  summarize(config = {}) {
    return summaryParts('MCP server failed', [config.serverId]);
  },
  event: {
    source: 'mcp',
    name: 'server_status',
    matches(config, event) {
      return FAILED_STATUSES.has(event.status)
        && event.previousStatus === 'running'
        && (!config.serverId || String(config.serverId) === String(event.serverId));
    },
    toPayload(event) {
      return {
        fingerprint: `mcp:${event.serverId}:${event.changedAt}`,
        timestamp: event.changedAt,
        context: {
          triggerEvent: {
            provider: 'mcp',
            event: 'server_failed',
            serverId: event.serverId,
            serverName: event.serverName,
            status: event.status,
            error: event.error,
          },
        },
      };
    },
  },
};
