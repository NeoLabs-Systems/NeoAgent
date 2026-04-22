const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { validateRemoteMcpEndpoint } = require('../services/runtime/mcp');
const { getAgentIdFromRequest, isMainAgent, resolveAgentId } = require('../services/agents/manager');
const { resolvePublicBaseUrl } = require('../services/integrations/env');

const MCP_OAUTH_STATE_RE = /^(\d+)::[a-f0-9]{32}$/;

function getTrustedPostMessageOrigin(req) {
  try {
    return new URL(resolvePublicBaseUrl()).origin;
  } catch {
    return `${req.protocol}://${req.get('host')}`;
  }
}

router.use(requireAuth);

// List configured MCP servers
router.get('/', (req, res) => {
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const includeLegacyMainServers = isMainAgent(req.session.userId, agentId);
  const servers = includeLegacyMainServers
    ? db.prepare(
      `SELECT * FROM mcp_servers
       WHERE user_id = ?
         AND (agent_id = ? OR agent_id IS NULL)
       ORDER BY name ASC`
    ).all(req.session.userId, agentId)
    : db.prepare(
      `SELECT * FROM mcp_servers
       WHERE user_id = ? AND agent_id = ?
       ORDER BY name ASC`
    ).all(req.session.userId, agentId);
  const mcpClient = req.app.locals.mcpClient;
  const liveStatuses = mcpClient.getStatus(req.session.userId, { agentId });

  const result = servers.map(s => ({
    id: s.id,
    name: s.name,
    command: s.command,
    config: JSON.parse(s.config || '{}'),
    agentId: s.agent_id || null,
    enabled: !!s.enabled,
    status: liveStatuses[s.id]?.status || 'stopped',
    toolCount: liveStatuses[s.id]?.toolCount || 0
  }));

  res.json(result);
});

// Add a new MCP server
router.post('/', (req, res) => {
  try {
    const { name, command, config, enabled } = req.body;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    if (!name || !command) return res.status(400).json({ error: 'name and command are required' });
    const endpoint = validateRemoteMcpEndpoint(command);

    const result = db.prepare('INSERT INTO mcp_servers (user_id, agent_id, name, command, config, enabled) VALUES (?, ?, ?, ?, ?, ?)')
      .run(req.session.userId, agentId, name, endpoint, JSON.stringify(config || {}), enabled !== false ? 1 : 0);

    res.status(201).json({ id: result.lastInsertRowid, name, command: endpoint });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

// Update an MCP server
router.put('/:id', (req, res) => {
  try {
    const server = db.prepare('SELECT * FROM mcp_servers WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
    if (!server) return res.status(404).json({ error: 'Server not found' });

    const { name, command, config, enabled } = req.body;
    const agentId = (req.body.agentId !== undefined || req.body.agent_id !== undefined)
      ? resolveAgentId(req.session.userId, getAgentIdFromRequest(req))
      : (server.agent_id || resolveAgentId(req.session.userId, null));
    const endpoint = command ? validateRemoteMcpEndpoint(command) : server.command;
    db.prepare('UPDATE mcp_servers SET agent_id = ?, name = ?, command = ?, config = ?, enabled = ? WHERE id = ?')
      .run(agentId, name || server.name, endpoint, JSON.stringify(config || JSON.parse(server.config)), enabled !== undefined ? (enabled ? 1 : 0) : server.enabled, server.id);

    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

// Delete an MCP server
router.delete('/:id', async (req, res) => {
  const server = db.prepare('SELECT * FROM mcp_servers WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!server) return res.status(404).json({ error: 'Server not found' });

  const mcpClient = req.app.locals.mcpClient;
  await mcpClient.stopServer(server.id).catch(() => { });

  db.prepare('DELETE FROM mcp_servers WHERE id = ?').run(server.id);
  res.json({ success: true });
});

// Start an MCP server
router.post('/:id/start', async (req, res) => {
  try {
    const server = db.prepare('SELECT * FROM mcp_servers WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
    if (!server) return res.status(404).json({ error: 'Server not found' });

    const mcpClient = req.app.locals.mcpClient;
    const result = await mcpClient.startServer(server.id, server.command, server.name, req.session.userId, { agentId: server.agent_id });
    const tools = await mcpClient.listTools(server.id, req.session.userId);

    res.json({ ...result, tools });
  } catch (err) {
    if (err.message && err.message.startsWith('OAUTH_REDIRECT:')) {
      const url = err.message.substring(15);
      return res.json({ status: 'oauth_redirect', url });
    }
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Stop an MCP server
router.post('/:id/stop', async (req, res) => {
  try {
    // Verify ownership before stopping
    const server = db.prepare('SELECT id FROM mcp_servers WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
    if (!server) return res.status(404).json({ error: 'Server not found' });
    const mcpClient = req.app.locals.mcpClient;
    await mcpClient.stopServer(req.params.id);
    res.json({ status: 'stopped' });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Get tools from a specific server
router.get('/:id/tools', async (req, res) => {
  try {
    // Verify ownership before listing tools
    const server = db.prepare('SELECT id FROM mcp_servers WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
    if (!server) return res.status(404).json({ error: 'Server not found' });
    const mcpClient = req.app.locals.mcpClient;
    const tools = await mcpClient.listTools(req.params.id, req.session.userId);
    res.json(tools);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// OAuth Callback
router.get('/oauth/callback', async (req, res) => {
  const { code, state, error } = req.query;
  if (!state) return res.status(400).send('Missing state parameter');
  if (!error && !code) return res.status(400).send('Missing code parameter');
  if (error) return res.status(400).send(`OAuth Error: ${error}`);

  const stateMatch = String(state).match(MCP_OAUTH_STATE_RE);
  if (!stateMatch) return res.status(400).send('Invalid state format');

  const serverId = Number.parseInt(stateMatch[1], 10);
  if (!Number.isInteger(serverId) || serverId <= 0) {
    return res.status(400).send('Invalid state format');
  }

  const server = db.prepare('SELECT id FROM mcp_servers WHERE id = ? AND user_id = ?').get(serverId, req.session.userId);
  if (!server) return res.status(404).send('Server not found');

  const mcpClient = req.app.locals.mcpClient;
  const trustedOrigin = JSON.stringify(getTrustedPostMessageOrigin(req));

  try {
    await mcpClient.finishOAuth(serverId, code);
    // Render a simple script that closes the popup or redirects parent
    res.send(`
      <html><body>
      <script>
        if (window.opener) {
          window.opener.postMessage({ type: 'mcp_oauth_success', serverId: ${serverId} }, ${trustedOrigin});
          window.close();
        } else {
          window.location.href = '/?page=mcp';
        }
      </script>
      <p>Authentication successful. You can close this window.</p>
      </body></html>
    `);
  } catch (err) {
    res.status(500).send(`Failed to finish OAuth: ${sanitizeError(err)}`);
  }
});

// Get all tools from all running servers
router.get('/tools/all', (req, res) => {
  const mcpClient = req.app.locals.mcpClient;
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  res.json(mcpClient.getAllTools(req.session.userId, { agentId }));
});

// Call a tool
router.post('/tools/call', async (req, res) => {
  try {
    const { serverId, toolName, args } = req.body;
    if (!serverId || !toolName) return res.status(400).json({ error: 'serverId and toolName required' });
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const server = db.prepare('SELECT id FROM mcp_servers WHERE id = ? AND user_id = ? AND agent_id = ?')
      .get(serverId, req.session.userId, agentId);
    if (!server) return res.status(404).json({ error: 'Server not found' });

    const mcpClient = req.app.locals.mcpClient;
    const result = await mcpClient.callTool(serverId, toolName, args || {}, req.session.userId);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
