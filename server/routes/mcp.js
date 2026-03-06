const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

// List configured MCP servers
router.get('/', (req, res) => {
  const servers = db.prepare('SELECT * FROM mcp_servers WHERE user_id = ? ORDER BY name ASC').all(req.session.userId);
  const mcpClient = req.app.locals.mcpClient;
  const liveStatuses = mcpClient.getStatus();

  const result = servers.map(s => ({
    id: s.id,
    name: s.name,
    command: s.command,
    config: JSON.parse(s.config || '{}'),
    enabled: !!s.enabled,
    status: liveStatuses[s.id]?.status || 'stopped',
    toolCount: liveStatuses[s.id]?.toolCount || 0
  }));

  res.json(result);
});

// Add a new MCP server
router.post('/', (req, res) => {
  const { name, command, config, enabled } = req.body;
  if (!name || !command) return res.status(400).json({ error: 'name and command are required' });

  const result = db.prepare('INSERT INTO mcp_servers (user_id, name, command, config, enabled) VALUES (?, ?, ?, ?, ?)')
    .run(req.session.userId, name, command, JSON.stringify(config || {}), enabled !== false ? 1 : 0);

  res.status(201).json({ id: result.lastInsertRowid, name, command });
});

// Update an MCP server
router.put('/:id', (req, res) => {
  const server = db.prepare('SELECT * FROM mcp_servers WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!server) return res.status(404).json({ error: 'Server not found' });

  const { name, command, config, enabled } = req.body;
  db.prepare('UPDATE mcp_servers SET name = ?, command = ?, config = ?, enabled = ? WHERE id = ?')
    .run(name || server.name, command || server.command, JSON.stringify(config || JSON.parse(server.config)), enabled !== undefined ? (enabled ? 1 : 0) : server.enabled, server.id);

  res.json({ success: true });
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
    const result = await mcpClient.startServer(server.id, server.command, server.name);
    const tools = await mcpClient.listTools(server.id);

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
    const tools = await mcpClient.listTools(req.params.id);
    res.json(tools);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// OAuth Callback
router.get('/oauth/callback', async (req, res) => {
  const { code, state, error } = req.query;
  if (!state) return res.status(400).send('Missing state parameter');
  if (error) return res.status(400).send(`OAuth Error: ${error}`);

  const [serverIdStr] = state.split('::');
  if (!serverIdStr) return res.status(400).send('Invalid state format');

  const serverId = parseInt(serverIdStr, 10);
  const mcpClient = req.app.locals.mcpClient;

  try {
    await mcpClient.finishOAuth(serverId, code);
    // Render a simple script that closes the popup or redirects parent
    res.send(`
      <html><body>
      <script>
        if (window.opener) {
          window.opener.postMessage({ type: 'mcp_oauth_success', serverId: ${serverId} }, '*');
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
  res.json(mcpClient.getAllTools());
});

// Call a tool
router.post('/tools/call', async (req, res) => {
  try {
    const { serverId, toolName, args } = req.body;
    if (!serverId || !toolName) return res.status(400).json({ error: 'serverId and toolName required' });

    const mcpClient = req.app.locals.mcpClient;
    const result = await mcpClient.callTool(serverId, toolName, args || {});
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
