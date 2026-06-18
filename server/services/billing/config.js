'use strict';

function isBillingEnabled() {
  const v = process.env.NEOAGENT_BILLING_ENABLED;
  return v === '1' || v === 'true';
}

function getStripeConfig() {
  return {
    secretKey: process.env.STRIPE_SECRET_KEY,
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
    publicKey: process.env.STRIPE_PUBLISHABLE_KEY,
    trialDays: parseInt(process.env.BILLING_TRIAL_DAYS || '14', 10),
  };
}

module.exports = { isBillingEnabled, getStripeConfig };
