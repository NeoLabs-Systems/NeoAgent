const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { resolvePublicBaseUrl } = require('../services/integrations/env');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');

function getIntegrationManager(req) {
  return req.app?.locals?.integrationManager;
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function getTrustedPostMessageOrigin(req) {
  try {
    return new URL(resolvePublicBaseUrl()).origin;
  } catch {
    return `${req.protocol}://${req.get('host')}`;
  }
}

router.get('/oauth/callback', async (req, res) => {
  const state = String(req.query.state || '');
  const code = String(req.query.code || '');
  const error = String(req.query.error || '');
  const trustedOrigin = JSON.stringify(getTrustedPostMessageOrigin(req));

  if (!state) return res.status(400).send('Missing state parameter');
  if (error) {
    const safeError = escapeHtml(error);
    return res.status(400).send(`
      <html><body>
      <script>
        if (window.opener) {
          window.opener.postMessage({ type: 'integration_oauth_error', error: ${JSON.stringify(error)} }, ${trustedOrigin});
          window.close();
        }
      </script>
      <p>Authentication failed: ${safeError}</p>
      </body></html>
    `);
  }

  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const result = await manager.finishOAuth(state, code);
    const payload = JSON.stringify({
      type: 'integration_oauth_success',
      provider: result.provider,
      appId: result.appId,
      connectionId: result.connectionId,
      accountEmail: result.accountEmail,
    });
    res.send(`
      <html><body>
      <script>
        if (window.opener) {
          window.opener.postMessage(${payload}, ${trustedOrigin});
          window.close();
        } else {
          window.location.href = '/?page=skills';
        }
      </script>
      <p>Authentication successful. You can close this window.</p>
      </body></html>
    `);
  } catch (err) {
    const message = sanitizeError(err);
    const safeMessage = escapeHtml(message);
    res.status(500).send(`
      <html><body>
      <script>
        if (window.opener) {
          window.opener.postMessage({ type: 'integration_oauth_error', error: ${JSON.stringify(message)} }, ${trustedOrigin});
          window.close();
        }
      </script>
      <p>Authentication failed: ${safeMessage}</p>
      </body></html>
    `);
  }
});

router.use(requireAuth);

router.get('/', (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    res.json(manager.listProviders(req.session.userId, agentId));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/:provider/connect', async (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const result = await manager.beginOAuth(
      req.session.userId,
      req.params.provider,
      {
        appKey: req.body?.appId,
        agentId: resolveAgentId(req.session.userId, getAgentIdFromRequest(req)),
      },
    );
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.post('/:provider/disconnect', async (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const result = await manager.disconnect(
      req.session.userId,
      req.params.provider,
      {
        connectionId: req.body?.connectionId,
        agentId: resolveAgentId(req.session.userId, getAgentIdFromRequest(req)),
      },
    );
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.get('/:provider/tools/status', (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    res.json(manager.getToolStatus(req.session.userId, req.params.provider, agentId));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
