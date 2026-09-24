'use strict';

const express = require('express');
const { proxyGitRequest } = require('../services/integrations/github/git_proxy');

const router = express.Router();

// Called by git inside guest computers, not by signed-in clients: each request
// is authorized by the per-command capability header the proxy checks.
router.use('/github.com', (req, res) => proxyGitRequest({
  integrationManager: req.app.locals.integrationManager,
  req,
  res,
}));

module.exports = router;
