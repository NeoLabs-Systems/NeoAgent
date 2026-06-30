'use strict';

const { isBillingEnabled } = require('./config');

// Lazy-load to avoid circular dependencies at startup.
function sendServiceEmail() {
  return require('../account/service_email').sendServiceEmail;
}

function isEmailAvailable() {
  try {
    return require('../account/service_email').isServiceEmailConfigured();
  } catch {
    return false;
  }
}

function fmtDate(tsOrSeconds) {
  if (!tsOrSeconds) return 'unknown';
  const ms = typeof tsOrSeconds === 'number' && tsOrSeconds < 1e12
    ? tsOrSeconds * 1000
    : Number(tsOrSeconds);
  return new Date(ms).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
}

async function send(user, message) {
  if (!isBillingEnabled() || !isEmailAvailable()) return;
  if (!user?.email) return;
  try {
    await sendServiceEmail()(user.email, message);
  } catch {
    // Best-effort; billing emails are non-critical.
  }
}

async function sendTrialStarted(user, plan, trialEndTs) {
  await send(user, {
    subject: `Your ${plan?.name || 'trial'} trial has started`,
    heading: 'Trial started',
    body: `Your free trial of the ${plan?.name || 'plan'} plan is now active.`,
    details: [{ label: 'Trial ends', value: fmtDate(trialEndTs) }],
  });
}

async function sendTrialEnding(user, plan, trialEndTs) {
  await send(user, {
    subject: `Your ${plan?.name || ''} trial ends soon`,
    heading: 'Trial ending soon',
    body: `Your free trial of the ${plan?.name || 'plan'} plan will end on ${fmtDate(trialEndTs)}. Add a payment method to continue without interruption.`,
    details: [{ label: 'Trial ends', value: fmtDate(trialEndTs) }],
  });
}

async function sendSubscriptionStarted(user, plan) {
  await send(user, {
    subject: `Welcome to ${plan?.name || 'your subscription'}`,
    heading: 'Subscription active',
    body: `Your ${plan?.name || 'subscription'} plan is now active.`,
  });
}

async function sendSubscriptionRenewed(user, plan) {
  await send(user, {
    subject: `Your ${plan?.name || 'subscription'} has been renewed`,
    heading: 'Subscription renewed',
    body: `Your ${plan?.name || 'subscription'} plan has been successfully renewed.`,
  });
}

async function sendPaymentFailed(user, plan, nextRetryAt) {
  const details = nextRetryAt
    ? [{ label: 'Next retry', value: fmtDate(nextRetryAt) }]
    : [];
  await send(user, {
    subject: 'Payment failed — action required',
    heading: 'Payment failed',
    body: `We were unable to charge your payment method for the ${plan?.name || 'subscription'} plan. Please update your billing details to avoid losing access.`,
    details,
  });
}

async function sendSubscriptionCanceled(user, plan) {
  await send(user, {
    subject: `Your ${plan?.name || 'subscription'} has been canceled`,
    heading: 'Subscription canceled',
    body: `Your ${plan?.name || 'subscription'} plan has been canceled. You may resubscribe at any time.`,
  });
}

async function sendPlanChanged(user, _oldPlan, newPlan) {
  await send(user, {
    subject: `Your plan has changed to ${newPlan?.name || 'a new plan'}`,
    heading: 'Plan updated',
    body: `Your subscription has been updated to the ${newPlan?.name || 'new'} plan.`,
  });
}

module.exports = {
  sendTrialStarted,
  sendTrialEnding,
  sendSubscriptionStarted,
  sendSubscriptionRenewed,
  sendPaymentFailed,
  sendSubscriptionCanceled,
  sendPlanChanged,
};
