'use strict';

const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { requireBilling } = require('../middleware/requireBilling');
const { getStripeConfig } = require('../services/billing/config');
const { listPlans } = require('../services/billing/plans');
const subs = require('../services/billing/subscriptions');
const { getStripeClient } = require('../services/billing/stripe_client');

function isValidHttpsUrl(value) {
  try {
    const u = new URL(value);
    return u.protocol === 'https:' || u.protocol === 'http:';
  } catch {
    return false;
  }
}

router.use(requireBilling);

// Public — pricing page needs this without login.
router.get('/plans', (req, res) => {
  try {
    res.json({ plans: listPlans() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// All remaining routes require authentication.
router.use(requireAuth);

router.get('/', (req, res) => {
  try {
    const userId = req.session.userId;
    const subscription = subs.getActiveSubscription(userId);
    const { publicKey } = getStripeConfig();
    res.json({ subscription, stripePublishableKey: publicKey || null });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/checkout', async (req, res) => {
  try {
    const { planId, successUrl, cancelUrl } = req.body;
    if (!planId || !successUrl || !cancelUrl) {
      return res.status(400).json({ error: 'planId, successUrl and cancelUrl are required.' });
    }
    if (!isValidHttpsUrl(successUrl) || !isValidHttpsUrl(cancelUrl)) {
      return res.status(400).json({ error: 'successUrl and cancelUrl must be valid URLs.' });
    }
    const url = await subs.createCheckoutSession(req.session.userId, planId, successUrl, cancelUrl);
    res.json({ url });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.post('/portal', async (req, res) => {
  try {
    const { returnUrl } = req.body;
    if (!returnUrl) return res.status(400).json({ error: 'returnUrl is required.' });
    if (!isValidHttpsUrl(returnUrl)) {
      return res.status(400).json({ error: 'returnUrl must be a valid URL.' });
    }
    const url = await subs.createCustomerPortalSession(req.session.userId, returnUrl);
    res.json({ url });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.post('/trial', async (req, res) => {
  try {
    const { planId, deviceFingerprint } = req.body;
    if (!planId) return res.status(400).json({ error: 'planId is required.' });
    const ip = req.ip || req.socket?.remoteAddress;
    const result = await subs.startTrial(req.session.userId, planId, { ip, deviceFp: deviceFingerprint });
    res.json({ subscription: result.subscription });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.post('/cancel', async (req, res) => {
  try {
    await subs.cancelSubscription(req.session.userId);
    res.json({ ok: true });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

router.get('/invoices', async (req, res) => {
  try {
    const stripe = getStripeClient();
    const userId = req.session.userId;
    const customer = db
      .prepare('SELECT stripe_customer_id FROM billing_customers WHERE user_id = ?')
      .get(userId);
    if (!customer?.stripe_customer_id) return res.json({ invoices: [] });
    const list = await stripe.invoices.list({ customer: customer.stripe_customer_id, limit: 12 });
    const invoices = list.data.map((inv) => ({
      id: inv.id,
      amount_paid: inv.amount_paid,
      currency: inv.currency,
      status: inv.status,
      created: inv.created,
      hosted_invoice_url: inv.hosted_invoice_url,
      invoice_pdf: inv.invoice_pdf,
    }));
    res.json({ invoices });
  } catch (err) {
    res.status(err.statusCode || 500).json({ error: err.message });
  }
});

module.exports = router;
