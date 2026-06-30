'use strict';

const express = require('express');
const router = express.Router();
const { isBillingEnabled, getStripeConfig } = require('../services/billing/config');
const { getStripeClient } = require('../services/billing/stripe_client');
const { handleWebhookEvent } = require('../services/billing/subscriptions');

// Raw body required for Stripe signature verification — applied inline.
router.post('/', express.raw({ type: 'application/json' }), async (req, res) => {
  if (!isBillingEnabled()) return res.status(404).json({ error: 'Billing is not enabled.' });

  const sig = req.headers['stripe-signature'];
  if (!sig) {
    return res.status(400).json({ error: 'Missing stripe-signature header.' });
  }

  const { webhookSecret } = getStripeConfig();
  if (!webhookSecret) {
    console.warn('[billing] STRIPE_WEBHOOK_SECRET is not set; rejecting webhook.');
    return res.status(500).json({ error: 'Webhook secret not configured.' });
  }

  let event;
  try {
    const stripe = getStripeClient();
    event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
  } catch (err) {
    console.warn('[billing] Webhook signature verification failed:', err.message);
    return res.status(400).json({ error: `Webhook error: ${err.message}` });
  }

  try {
    await handleWebhookEvent(event);
  } catch (err) {
    console.error('[billing] Webhook handler error:', err);
    // Still return 200 so Stripe does not retry immediately for handler bugs.
  }

  res.json({ received: true });
});

module.exports = router;
