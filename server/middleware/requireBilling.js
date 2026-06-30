'use strict';

const { isBillingEnabled } = require('../services/billing/config');

function requireBilling(req, res, next) {
  if (!isBillingEnabled()) {
    return res.status(404).json({ error: 'Billing is not enabled on this server.' });
  }
  next();
}

module.exports = { requireBilling };
