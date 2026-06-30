'use strict';

const { isBillingEnabled, getStripeConfig } = require('./config');

let _client = null;

function getStripeClient() {
  if (!isBillingEnabled()) {
    throw new Error('Billing is not enabled.');
  }
  if (_client) return _client;
  const { secretKey } = getStripeConfig();
  if (!secretKey) {
    throw new Error('STRIPE_SECRET_KEY is not configured.');
  }
  const Stripe = require('stripe');
  _client = new Stripe(secretKey);
  return _client;
}

module.exports = { getStripeClient };
