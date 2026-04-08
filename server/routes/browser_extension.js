const express = require('express');
const path = require('path');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { createZipFromDirectory } = require('../services/browser/extension/zip');

const router = express.Router();
const EXTENSION_DIR = path.join(__dirname, '..', '..', 'extensions', 'chrome-browser');
const EXTENSION_MANIFEST = require('../../extensions/chrome-browser/manifest.json');

function getRegistry(req) {
  const registry = req.app?.locals?.browserExtensionRegistry;
  if (!registry) {
    throw new Error('Browser extension registry is not available.');
  }
  return registry;
}

function baseUrlFor(req) {
  const configured = process.env.NEOAGENT_PUBLIC_URL || process.env.PUBLIC_URL || '';
  if (configured) return configured.replace(/\/+$/, '');
  return `${req.protocol}://${req.get('host')}`;
}

function approvalUrlFor(req, pairingId) {
  return `${baseUrlFor(req)}/api/browser-extension/pairing/${encodeURIComponent(pairingId)}/approve`;
}

function extensionConfigFor(req) {
  return `export const DEFAULT_SERVER_URL = ${JSON.stringify(baseUrlFor(req))};\n`;
}

router.post('/pairing/request', (req, res) => {
  try {
    const pairing = getRegistry(req).createPairingRequest({
      extensionName: req.body?.extensionName,
      userAgent: req.get('user-agent') || null,
    });
    res.json({
      ...pairing,
      approvalUrl: approvalUrlFor(req, pairing.pairingId),
      serverUrl: baseUrlFor(req),
    });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/latest', (req, res) => {
  res.json({
    name: EXTENSION_MANIFEST.name,
    version: EXTENSION_MANIFEST.version,
    minimumChromeVersion: EXTENSION_MANIFEST.minimum_chrome_version,
    downloadUrl: `${baseUrlFor(req)}/api/browser-extension/download`,
  });
});

router.get('/pairing/:pairingId/approve', requireAuth, (req, res) => {
  try {
    const row = getRegistry(req).getPairingRequest(req.params.pairingId);
    if (!row) return res.status(404).send('Pairing request not found.');
    const expired = Date.parse(row.expires_at) <= Date.now();
    if (expired) return res.status(410).send('Pairing request expired. Start pairing again from the extension.');
    if (row.status === 'claimed') return res.send('This browser extension is already paired.');
    if (row.status === 'approved') return res.send('Extension approved. Return to the extension to finish pairing.');
    if (row.status !== 'pending') {
      return res.status(409).send('Pairing request is not pending.');
    }
    const action = `/api/browser-extension/pairing/${encodeURIComponent(req.params.pairingId)}/approve`;
    res.type('html').send(`<!doctype html>
<html>
<head><meta charset="utf-8"><title>Pair NeoAgent Browser Extension</title></head>
<body style="font-family: system-ui, sans-serif; margin: 2rem; max-width: 42rem;">
  <h1>Pair NeoAgent Browser Extension</h1>
  <p>Approve this Chrome extension to control the connected browser for your NeoAgent account.</p>
  <form method="post" action="${action}">
    <button type="submit" style="font: inherit; padding: .7rem 1rem;">Approve Extension</button>
  </form>
</body>
</html>`);
  } catch (err) {
    res.status(500).send(sanitizeError(err));
  }
});

router.post('/pairing/:pairingId/approve', requireAuth, (req, res) => {
  try {
    const result = getRegistry(req).approvePairing(req.params.pairingId, req.session.userId);
    if (String(req.get('accept') || '').includes('text/html')) {
      return res.type('html').send('<!doctype html><p>Extension approved. Return to the extension to finish pairing.</p>');
    }
    res.json(result);
  } catch (err) {
    res.status(err.status || 500).json({ error: sanitizeError(err) });
  }
});

router.post('/pairing/:pairingId/claim', (req, res) => {
  try {
    const result = getRegistry(req).claimPairing(req.params.pairingId, req.body?.pairingSecret, {
      extensionName: req.body?.extensionName,
      userAgent: req.get('user-agent') || null,
    });
    res.json(result);
  } catch (err) {
    res.status(err.status || 500).json({ error: sanitizeError(err) });
  }
});

router.get('/status', requireAuth, (req, res) => {
  try {
    res.json(getRegistry(req).getStatus(req.session.userId));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/revoke', requireAuth, (req, res) => {
  try {
    res.json(getRegistry(req).revoke(req.session.userId, req.body?.tokenId || null));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/download', requireAuth, (req, res) => {
  try {
    const zip = createZipFromDirectory(EXTENSION_DIR, {
      overrides: {
        'config.mjs': extensionConfigFor(req),
      },
    });
    res.setHeader('content-type', 'application/zip');
    res.setHeader('content-disposition', 'attachment; filename="neoagent-chrome-browser-extension.zip"');
    res.send(zip);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
