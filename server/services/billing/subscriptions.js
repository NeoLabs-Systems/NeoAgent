'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');
const { getStripeClient } = require('./stripe_client');
const { getPlan, getFreePlan } = require('./plans');
const trialGuard = require('./trial_guard');
const billingEmail = require('./billing_email');

function isoNow() {
  return new Date().toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
}

function getUserById(userId) {
  return db.prepare('SELECT id, email, display_name, username FROM users WHERE id = ?').get(userId);
}

function stripeTs(ts) {
  if (!ts) return null;
  return new Date(ts * 1000).toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
}

// Returns the user's active subscription joined with plan data.
// If admin set billing_override_plan_id, that plan is used regardless of user_subscriptions.
function getActiveSubscription(userId) {
  const user = db.prepare('SELECT billing_override_plan_id FROM users WHERE id = ?').get(userId);
  if (user?.billing_override_plan_id) {
    const plan = getPlan(user.billing_override_plan_id);
    if (plan) {
      return {
        id: null,
        user_id: userId,
        plan_id: plan.id,
        plan,
        status: 'active',
        trial_ends_at: null,
        cancel_at_period_end: false,
        stripe_subscription_id: null,
      };
    }
  }

  const row = db.prepare(`
    SELECT s.*, p.name AS plan_name, p.description AS plan_description,
           p.price_cents, p.currency, p.interval, p.stripe_price_id,
           p.token_limit_4h, p.token_limit_weekly,
           p.allowed_models_json, p.features_json
    FROM user_subscriptions s
    JOIN billing_plans p ON p.id = s.plan_id
    WHERE s.user_id = ?
    ORDER BY
      CASE s.status WHEN 'active' THEN 0 WHEN 'trialing' THEN 1 WHEN 'past_due' THEN 2 ELSE 3 END,
      s.updated_at DESC
    LIMIT 1
  `).get(userId);

  if (!row) return null;

  return {
    ...row,
    cancel_at_period_end: Boolean(row.cancel_at_period_end),
    plan: {
      id: row.plan_id,
      name: row.plan_name,
      description: row.plan_description,
      price_cents: row.price_cents,
      currency: row.currency,
      interval: row.interval,
      stripe_price_id: row.stripe_price_id,
      token_limit_4h: row.token_limit_4h,
      token_limit_weekly: row.token_limit_weekly,
      allowed_models: tryParseJson(row.allowed_models_json, []),
      features: tryParseJson(row.features_json, []),
    },
  };
}

// Ensure a Stripe customer exists for this user; create if not.
async function getOrCreateStripeCustomer(userId) {
  const user = getUserById(userId);
  if (!user) throw new Error('User not found.');

  const existing = db.prepare('SELECT stripe_customer_id FROM billing_customers WHERE user_id = ?').get(userId);
  if (existing?.stripe_customer_id) return existing.stripe_customer_id;

  const stripe = getStripeClient();
  const customer = await stripe.customers.create({
    email: user.email || undefined,
    name: user.display_name || user.username || undefined,
    metadata: { neoagent_user_id: String(userId) },
  });

  const now = isoNow();
  db.prepare(`
    INSERT INTO billing_customers (user_id, stripe_customer_id, created_at, updated_at)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(user_id) DO UPDATE SET stripe_customer_id = excluded.stripe_customer_id, updated_at = excluded.updated_at
  `).run(userId, customer.id, now, now);

  return customer.id;
}

function createFreeSubscription(userId) {
  const freePlan = getFreePlan();
  if (!freePlan) return null;

  const id = randomUUID();
  const now = isoNow();
  // INSERT OR IGNORE makes this idempotent under concurrent calls — the unique
  // constraint on (user_id, active status) is enforced by the application layer,
  // but concurrent requests could both reach this point; ignore the second attempt.
  const info = db.prepare(`
    INSERT OR IGNORE INTO user_subscriptions
      (id, user_id, plan_id, stripe_subscription_id, status, created_at, updated_at)
    SELECT ?, ?, ?, NULL, 'active', ?, ?
    WHERE NOT EXISTS (
      SELECT 1 FROM user_subscriptions WHERE user_id = ? AND status IN ('active', 'trialing')
    )
  `).run(id, userId, freePlan.id, now, now, userId);

  if (info.changes > 0) {
    applyRateLimitsFromSubscription(userId);
  }
  return getActiveSubscription(userId);
}

async function startTrial(userId, planId, { ip, deviceFp } = {}) {
  const plan = getPlan(planId);
  if (!plan) throw Object.assign(new Error('Plan not found.'), { statusCode: 404 });
  if (plan.price_cents === 0) throw Object.assign(new Error('Free plans do not have trials.'), { statusCode: 400 });

  const user = getUserById(userId);
  trialGuard.runChecks(userId, user?.email, { ip, deviceFp });

  const stripe = getStripeClient();
  const { trialDays } = require('./config').getStripeConfig();
  const customerId = await getOrCreateStripeCustomer(userId);

  const stripeSub = await stripe.subscriptions.create({
    customer: customerId,
    items: [{ price: plan.stripe_price_id }],
    trial_period_days: trialDays,
    payment_behavior: 'default_incomplete',
    expand: ['latest_invoice.payment_intent'],
  });

  const id = randomUUID();
  const now = isoNow();
  try {
    db.prepare(`
      INSERT INTO user_subscriptions
        (id, user_id, plan_id, stripe_subscription_id, status, trial_ends_at,
         current_period_start, current_period_end, created_at, updated_at)
      VALUES (?, ?, ?, ?, 'trialing', ?, ?, ?, ?, ?)
    `).run(
      id, userId, planId, stripeSub.id,
      stripeTs(stripeSub.trial_end),
      stripeTs(stripeSub.current_period_start),
      stripeTs(stripeSub.current_period_end),
      now, now,
    );
  } catch (localErr) {
    // Local insert failed — cancel the Stripe subscription to avoid an orphan.
    try { await stripe.subscriptions.cancel(stripeSub.id); } catch { /* best effort */ }
    throw localErr;
  }

  recordEvent(userId, id, 'trial_started', null, { plan_id: planId });
  trialGuard.recordFingerprints(userId, { ip, email: user?.email, deviceFp });
  applyRateLimitsFromSubscription(userId);

  return { subscription: getActiveSubscription(userId), stripeSubscription: stripeSub };
}

async function createCheckoutSession(userId, planId, successUrl, cancelUrl) {
  const plan = getPlan(planId);
  if (!plan) throw Object.assign(new Error('Plan not found.'), { statusCode: 404 });
  if (!plan.stripe_price_id) throw Object.assign(new Error('Plan has no Stripe price configured.'), { statusCode: 400 });

  const stripe = getStripeClient();
  const customerId = await getOrCreateStripeCustomer(userId);

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: 'subscription',
    line_items: [{ price: plan.stripe_price_id, quantity: 1 }],
    success_url: successUrl,
    cancel_url: cancelUrl,
    metadata: { neoagent_user_id: String(userId), plan_id: planId },
  });

  return session.url;
}

async function createCustomerPortalSession(userId, returnUrl) {
  const stripe = getStripeClient();
  const customerId = await getOrCreateStripeCustomer(userId);

  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: returnUrl,
  });

  return session.url;
}

async function cancelSubscription(userId) {
  const sub = getActiveSubscription(userId);
  if (!sub?.stripe_subscription_id) {
    throw Object.assign(new Error('No active Stripe subscription to cancel.'), { statusCode: 400 });
  }

  const stripe = getStripeClient();
  await stripe.subscriptions.update(sub.stripe_subscription_id, { cancel_at_period_end: true });

  const now = isoNow();
  db.prepare(
    'UPDATE user_subscriptions SET cancel_at_period_end = 1, updated_at = ? WHERE id = ?',
  ).run(now, sub.id);

  recordEvent(userId, sub.id, 'subscription_cancel_requested', null, {});
}

// Called from webhook handlers to sync the user's rate limits from their current plan.
function applyRateLimitsFromSubscription(userId) {
  const sub = getActiveSubscription(userId);
  if (!sub) return;
  const { token_limit_4h, token_limit_weekly } = sub.plan;
  db.prepare(
    'UPDATE users SET rate_limit_4h = ?, rate_limit_weekly = ? WHERE id = ?',
  ).run(token_limit_4h ?? null, token_limit_weekly ?? null, userId);
}

// Find a user by their Stripe customer ID.
function findUserByStripeCustomer(stripeCustomerId) {
  const row = db.prepare('SELECT user_id FROM billing_customers WHERE stripe_customer_id = ?').get(stripeCustomerId);
  return row?.user_id ?? null;
}

// Upsert a subscription row from a Stripe subscription object.
function upsertFromStripeSubscription(userId, stripeSub, overridePlanId = null) {
  const planId = overridePlanId || stripeSub.metadata?.plan_id;

  const existing = db.prepare(
    'SELECT id FROM user_subscriptions WHERE stripe_subscription_id = ?',
  ).get(stripeSub.id);

  const now = isoNow();
  const status = stripeSub.status;
  const trialEnd = stripeTs(stripeSub.trial_end);
  const periodStart = stripeTs(stripeSub.current_period_start);
  const periodEnd = stripeTs(stripeSub.current_period_end);
  const cancelAtPeriodEnd = stripeSub.cancel_at_period_end ? 1 : 0;
  const canceledAt = stripeSub.canceled_at ? stripeTs(stripeSub.canceled_at) : null;

  if (existing) {
    db.prepare(`
      UPDATE user_subscriptions
      SET status = ?, trial_ends_at = ?, current_period_start = ?, current_period_end = ?,
          cancel_at_period_end = ?, canceled_at = ?, updated_at = ?
          ${planId ? ', plan_id = ?' : ''}
      WHERE id = ?
    `).run(
      ...(planId
        ? [status, trialEnd, periodStart, periodEnd, cancelAtPeriodEnd, canceledAt, now, planId, existing.id]
        : [status, trialEnd, periodStart, periodEnd, cancelAtPeriodEnd, canceledAt, now, existing.id]),
    );
    return existing.id;
  }

  // planId is required to satisfy the FK on billing_plans(id).
  // Webhooks from subscriptions created outside NeoAgent (no metadata.plan_id)
  // cannot be inserted without a valid plan — skip rather than violate the constraint.
  if (!planId) return null;

  const id = randomUUID();
  db.prepare(`
    INSERT INTO user_subscriptions
      (id, user_id, plan_id, stripe_subscription_id, status, trial_ends_at,
       current_period_start, current_period_end, cancel_at_period_end, canceled_at, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(id, userId, planId, stripeSub.id, status, trialEnd, periodStart, periodEnd, cancelAtPeriodEnd, canceledAt, now, now);
  return id;
}

function recordEvent(userId, subscriptionId, eventType, stripeEventId, payload) {
  try {
    db.prepare(`
      INSERT OR IGNORE INTO subscription_events
        (user_id, subscription_id, event_type, stripe_event_id, payload_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(
      userId,
      subscriptionId,
      eventType,
      stripeEventId,
      JSON.stringify(payload || {}),
      isoNow(),
    );
  } catch {
    // Best-effort; never fail the caller.
  }
}

async function handleWebhookEvent(stripeEvent) {
  const obj = stripeEvent.data.object;

  switch (stripeEvent.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated': {
      const userId = findUserByStripeCustomer(obj.customer);
      if (!userId) return;

      const oldStatus = stripeEvent.type === 'customer.subscription.updated'
        ? stripeEvent.data.previous_attributes?.status
        : null;

      const subId = upsertFromStripeSubscription(userId, obj);
      applyRateLimitsFromSubscription(userId);

      const newStatus = obj.status;
      const user = getUserById(userId);
      const sub = getActiveSubscription(userId);

      if (oldStatus === 'trialing' && newStatus === 'active') {
        recordEvent(userId, subId, 'subscription_started', stripeEvent.id, { plan_id: sub?.plan_id });
        await billingEmail.sendSubscriptionStarted(user, sub?.plan).catch(() => {});
      } else if (newStatus === 'trialing' && !oldStatus) {
        recordEvent(userId, subId, 'trial_started', stripeEvent.id, { plan_id: sub?.plan_id });
        await billingEmail.sendTrialStarted(user, sub?.plan, obj.trial_end).catch(() => {});
      }

      if (stripeEvent.data.previous_attributes?.plan && newStatus === 'active') {
        recordEvent(userId, subId, 'plan_changed', stripeEvent.id, {});
        await billingEmail.sendPlanChanged(user, null, sub?.plan).catch(() => {});
      }
      break;
    }

    case 'customer.subscription.deleted': {
      const userId = findUserByStripeCustomer(obj.customer);
      if (!userId) return;
      upsertFromStripeSubscription(userId, obj);
      applyRateLimitsFromSubscription(userId);
      recordEvent(userId, null, 'subscription_canceled', stripeEvent.id, {});
      const user = getUserById(userId);
      const sub = getActiveSubscription(userId);
      await billingEmail.sendSubscriptionCanceled(user, sub?.plan).catch(() => {});
      break;
    }

    case 'invoice.payment_succeeded': {
      const userId = findUserByStripeCustomer(obj.customer);
      if (!userId) return;
      recordEvent(userId, null, 'payment_succeeded', stripeEvent.id, { amount: obj.amount_paid });
      if (obj.billing_reason === 'subscription_cycle') {
        const user = getUserById(userId);
        const sub = getActiveSubscription(userId);
        await billingEmail.sendSubscriptionRenewed(user, sub?.plan).catch(() => {});
      }
      break;
    }

    case 'invoice.payment_failed': {
      const userId = findUserByStripeCustomer(obj.customer);
      if (!userId) return;
      recordEvent(userId, null, 'payment_failed', stripeEvent.id, { amount: obj.amount_due });
      const user = getUserById(userId);
      const sub = getActiveSubscription(userId);
      const nextRetry = obj.next_payment_attempt
        ? new Date(obj.next_payment_attempt * 1000).toISOString()
        : null;
      await billingEmail.sendPaymentFailed(user, sub?.plan, nextRetry).catch(() => {});
      break;
    }

    case 'customer.subscription.trial_will_end': {
      const userId = findUserByStripeCustomer(obj.customer);
      if (!userId) return;
      recordEvent(userId, null, 'trial_ending', stripeEvent.id, { trial_end: obj.trial_end });
      const user = getUserById(userId);
      const sub = getActiveSubscription(userId);
      await billingEmail.sendTrialEnding(user, sub?.plan, obj.trial_end).catch(() => {});
      break;
    }

    default:
      break;
  }
}

const VALID_SUBSCRIPTION_STATUSES = new Set(['active', 'trialing', 'past_due', 'canceled', 'paused']);

// Admin override: assign a plan directly without Stripe.
function adminSetSubscription(userId, planId, status = 'active') {
  if (!VALID_SUBSCRIPTION_STATUSES.has(status)) {
    throw Object.assign(new Error(`Invalid status "${status}".`), { statusCode: 400 });
  }
  const plan = getPlan(planId);
  if (!plan) throw Object.assign(new Error('Plan not found.'), { statusCode: 404 });

  const existing = db.prepare(
    'SELECT id FROM user_subscriptions WHERE user_id = ? AND stripe_subscription_id IS NULL ORDER BY created_at DESC LIMIT 1',
  ).get(userId);

  const now = isoNow();
  if (existing) {
    db.prepare('UPDATE user_subscriptions SET plan_id = ?, status = ?, updated_at = ? WHERE id = ?')
      .run(planId, status, now, existing.id);
  } else {
    const id = randomUUID();
    db.prepare(`
      INSERT INTO user_subscriptions
        (id, user_id, plan_id, stripe_subscription_id, status, created_at, updated_at)
      VALUES (?, ?, ?, NULL, ?, ?, ?)
    `).run(id, userId, planId, status, now, now);
  }

  applyRateLimitsFromSubscription(userId);
  return getActiveSubscription(userId);
}

// Revoke admin override and/or cancel manual subscription immediately.
function adminCancelSubscription(userId) {
  const now = isoNow();
  db.prepare("UPDATE users SET billing_override_plan_id = NULL WHERE id = ?").run(userId);
  db.prepare(
    "UPDATE user_subscriptions SET status = 'canceled', canceled_at = ?, updated_at = ? WHERE user_id = ? AND stripe_subscription_id IS NULL",
  ).run(now, now, userId);
  applyRateLimitsFromSubscription(userId);
}

// Run at startup to re-sync rate limits for all active subscribers (in case webhooks were missed).
function syncAllSubscriberRateLimits() {
  try {
    const rows = db.prepare(
      "SELECT DISTINCT user_id FROM user_subscriptions WHERE status IN ('active', 'trialing')",
    ).all();
    for (const { user_id } of rows) {
      try { applyRateLimitsFromSubscription(user_id); } catch { /* best effort */ }
    }
  } catch { /* best effort */ }
}

function tryParseJson(str, fallback) {
  try { return JSON.parse(str); } catch { return fallback; }
}

module.exports = {
  getActiveSubscription,
  createFreeSubscription,
  startTrial,
  createCheckoutSession,
  createCustomerPortalSession,
  cancelSubscription,
  applyRateLimitsFromSubscription,
  handleWebhookEvent,
  adminSetSubscription,
  adminCancelSubscription,
  syncAllSubscriberRateLimits,
  findUserByStripeCustomer,
};
