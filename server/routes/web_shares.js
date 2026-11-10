'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { publicBaseUrlForRequest } = require('../utils/public_url');
const { getTerminalEnv, TERMINAL_ENV_HOST } = require('../utils/deployment');
const { isWebSharingAllowed, isWebSharingEnabled, listShares, stopSharingWebPage } = require('../services/web_shares');

const router = express.Router();

router.use(requireAuth);

// The pages the agent shares from the owner's computer, for the settings page.
router.get('/', (req, res) => {
  const userId = req.session.userId;
  // With the admin's switch off there is nothing to show or turn on.
  if (!isWebSharingAllowed()) return res.json({ allowed: false });
  return res.json({
    allowed: true,
    enabled: isWebSharingEnabled(userId),
    supported: getTerminalEnv() !== TERMINAL_ENV_HOST,
    computerRunning: Boolean(req.app.locals.runtimeManager?.runningGuestForUser?.(userId)),
    shares: listShares(userId, { baseUrl: publicBaseUrlForRequest(req) }),
  });
});

router.delete('/:id', (req, res) => {
  const result = stopSharingWebPage({ userId: req.session.userId, ref: req.params.id });
  if (result.error) return res.status(404).json({ error: 'Shared page not found.' });
  return res.json({ stopped: true });
});

module.exports = router;
