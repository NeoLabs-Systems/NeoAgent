const express = require('express');
const QRCode = require('qrcode');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { resolvePublicBaseUrl } = require('../services/integrations/env');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');

const INTEGRATION_STATE_RE = /^[a-f0-9]{48}$/;
const AUTH_PROVIDER_STATE_RE = /^auth_[a-f0-9]{48}$/;

function getIntegrationManager(req) {
  return req.app?.locals?.integrationManager;
}

function getAuthProviderManager(req) {
  return req.app?.locals?.authProviderManager;
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
  const isAuthProviderState = state.startsWith('auth_');

  if (!state) return res.status(400).send('Missing state parameter');
  if (isAuthProviderState && !AUTH_PROVIDER_STATE_RE.test(state)) {
    return res.status(400).send('Invalid OAuth state parameter');
  }
  if (!isAuthProviderState && !INTEGRATION_STATE_RE.test(state)) {
    return res.status(400).send('Invalid OAuth state parameter');
  }
  if (!error && !code) {
    return res.status(400).send('Missing code parameter');
  }
  if (error) {
    if (isAuthProviderState) {
      getAuthProviderManager(req)?.failAuthorization(state, error);
    }
    const safeError = escapeHtml(error);
    return res.status(400).send(`
      <html><body>
      <script>
        if (window.opener) {
          window.opener.postMessage({ type: ${JSON.stringify(isAuthProviderState ? 'auth_oauth_error' : 'integration_oauth_error')}, error: ${JSON.stringify(error)} }, ${trustedOrigin});
          window.close();
        }
      </script>
      <p>Authentication failed: ${safeError}</p>
      </body></html>
    `);
  }

  try {
    if (isAuthProviderState) {
      const authProviderManager = getAuthProviderManager(req);
      if (!authProviderManager) {
        throw new Error('Auth provider manager is not available on app.locals.authProviderManager.');
      }
      const result = await authProviderManager.finishAuthorization(state, code);
      const payload = JSON.stringify({
        type: 'auth_oauth_success',
        provider: result.provider,
        mode: result.action,
        email: result.email,
      });
      return res.send(`
        <html><body>
        <script>
          if (window.opener) {
            window.opener.postMessage(${payload}, ${trustedOrigin});
            window.close();
          } else {
            window.location.href = '/';
          }
        </script>
        <p>Authentication successful. You can close this window.</p>
        </body></html>
      `);
    }

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
    if (isAuthProviderState) {
      getAuthProviderManager(req)?.failAuthorization(state, message);
    }
    res.status(500).send(`
      <html><body>
      <script>
        if (window.opener) {
          window.opener.postMessage({ type: ${JSON.stringify(isAuthProviderState ? 'auth_oauth_error' : 'integration_oauth_error')}, error: ${JSON.stringify(message)} }, ${trustedOrigin});
          window.close();
        }
      </script>
      <p>Authentication failed: ${safeMessage}</p>
      </body></html>
    `);
  }
});

router.use(requireAuth);

router.get('/qr-image', async (req, res) => {
  try {
    const data = String(req.query.data || '').trim();
    if (!data) {
      return res.status(400).send('Missing QR data.');
    }
    const svg = await QRCode.toString(data, {
      errorCorrectionLevel: 'M',
      margin: 1,
      type: 'svg',
      width: 320,
    });
    res.setHeader('Content-Type', 'image/svg+xml; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store, max-age=0');
    return res.send(svg);
  } catch (err) {
    return res.status(400).send(escapeHtml(sanitizeError(err)));
  }
});

router.get('/:provider/connect/:sessionId', (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const session = manager.getConnectionSession(
      req.session.userId,
      req.params.provider,
      req.params.sessionId,
      agentId,
    );
    if (!session) {
      return res.status(404).send('Connection session not found.');
    }
    const provider = manager.getProvider(req.params.provider);
    const providerLabel = provider?.label || req.params.provider;
    const appLabel = provider?.getApp?.(session.appKey)?.label || session.appKey || 'account';
    const trustedOrigin = JSON.stringify(getTrustedPostMessageOrigin(req));
    const statusUrl = `/api/integrations/${encodeURIComponent(req.params.provider)}/connect/${encodeURIComponent(req.params.sessionId)}/status?agentId=${encodeURIComponent(agentId)}`;
    res.send(`
      <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>Connect ${escapeHtml(providerLabel)}</title>
          <style>
            body { font-family: ui-sans-serif, system-ui, sans-serif; background: #0b1220; color: #f8fafc; margin: 0; padding: 24px; }
            .card { max-width: 560px; margin: 0 auto; background: #111827; border: 1px solid #1f2937; border-radius: 20px; padding: 24px; }
            .muted { color: #94a3b8; }
            .pill { display: inline-block; padding: 6px 10px; border-radius: 999px; background: #1f2937; font-size: 12px; }
            img { display: block; margin: 24px auto; background: white; padding: 12px; border-radius: 16px; max-width: min(320px, 100%); }
            code { background: #0f172a; padding: 2px 6px; border-radius: 6px; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="pill">Official integration</div>
            <h1>Connect ${escapeHtml(providerLabel)}</h1>
            <p class="muted">Complete connection for ${escapeHtml(appLabel)}. This window closes automatically when linking is finished.</p>
            <div id="status" class="muted">Starting connection…</div>
            <img id="qr" alt="Integration QR code" style="display:none;" />
            <p class="muted">If this flow needs QR scan approval, the code will appear below.</p>
          </div>
          <script>
            const statusEl = document.getElementById('status');
            const qrEl = document.getElementById('qr');
            const statusUrl = ${JSON.stringify(statusUrl)};
            const trustedOrigin = ${trustedOrigin};
            const provider = ${JSON.stringify(req.params.provider)};
            const appId = ${JSON.stringify(session.appKey)};

            function notifyOpener(payload) {
              if (!window.opener) return;
              window.opener.postMessage(payload, trustedOrigin);
            }

            async function refresh() {
              const response = await fetch(statusUrl, { credentials: 'same-origin' });
              if (!response.ok) {
                statusEl.textContent = 'Connection session expired or is no longer available.';
                return;
              }
              const data = await response.json();
              const status = String(data.status || 'connecting');
              if (status === 'awaiting_qr' && data.qr) {
                statusEl.textContent = 'Scan this QR code to continue linking.';
                qrEl.src = '/api/integrations/qr-image?data=' + encodeURIComponent(data.qr);
                qrEl.style.display = 'block';
              } else if (status === 'connected') {
                qrEl.style.display = 'none';
                statusEl.textContent = 'Connected as ' + (data.accountEmail || 'your account') + '. Closing…';
                notifyOpener({
                  type: 'integration_oauth_success',
                  provider,
                  appId,
                  connectionId: data.connectionId || null,
                  accountEmail: data.accountEmail || null,
                });
                setTimeout(() => window.close(), 800);
                return;
              } else if (status === 'failed' || status === 'logged_out' || status === 'disconnected') {
                qrEl.style.display = 'none';
                statusEl.textContent = data.error || ('Connection ended with status: ' + status + '.');
                notifyOpener({
                  type: 'integration_oauth_error',
                  provider,
                  appId,
                  error: data.error || ('Connection ended with status: ' + status + '.'),
                });
                return;
              } else {
                statusEl.textContent = 'Waiting for the integration to finish linking…';
              }
              setTimeout(refresh, 1500);
            }
            refresh().catch((error) => {
              statusEl.textContent = error?.message || 'Could not load connection status.';
            });
          </script>
        </body>
      </html>
    `);
  } catch (err) {
    res.status(500).send(escapeHtml(sanitizeError(err)));
  }
});

router.get('/:provider/connect/:sessionId/status', (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    const session = manager.getConnectionSession(
      req.session.userId,
      req.params.provider,
      req.params.sessionId,
      agentId,
    );
    if (!session) {
      return res.status(404).json({ error: 'Connection session not found.' });
    }
    res.json(session);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

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

router.post('/:provider/access-mode', async (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const result = await manager.updateConnectionAccessMode(
      req.session.userId,
      req.params.provider,
      {
        connectionId: req.body?.connectionId,
        accessMode: req.body?.accessMode,
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

router.get('/:provider/config', (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const provider = manager.getProvider(req.params.provider);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${req.params.provider}`);
    }
    if (typeof provider.getUserConfig !== 'function') {
      return res.status(404).json({
        error: `${provider.label} does not support per-user configuration.`,
      });
    }
    const config = provider.getUserConfig({
      userId: req.session.userId,
      agentId: resolveAgentId(req.session.userId, getAgentIdFromRequest(req)),
    });
    res.json({
      provider: provider.key,
      config,
    });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.put('/:provider/config', async (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const provider = manager.getProvider(req.params.provider);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${req.params.provider}`);
    }
    if (typeof provider.saveUserConfig !== 'function') {
      return res.status(404).json({
        error: `${provider.label} does not support per-user configuration.`,
      });
    }
    const config = await provider.saveUserConfig({
      userId: req.session.userId,
      agentId: resolveAgentId(req.session.userId, getAgentIdFromRequest(req)),
      config: req.body?.config || req.body || {},
    });
    res.json({
      provider: provider.key,
      config,
      saved: true,
    });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.delete('/:provider/config', async (req, res) => {
  try {
    const manager = getIntegrationManager(req);
    if (!manager) {
      throw new Error('Official integration manager is not available on app.locals.integrationManager.');
    }
    const provider = manager.getProvider(req.params.provider);
    if (!provider) {
      throw new Error(`Unknown integration provider: ${req.params.provider}`);
    }
    if (typeof provider.clearUserConfig !== 'function') {
      return res.status(404).json({
        error: `${provider.label} does not support per-user configuration.`,
      });
    }
    await provider.clearUserConfig({
      userId: req.session.userId,
      agentId: resolveAgentId(req.session.userId, getAgentIdFromRequest(req)),
    });
    res.json({
      provider: provider.key,
      cleared: true,
    });
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
