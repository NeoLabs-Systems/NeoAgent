'use strict';

const {
  cleanLine,
  persistEnv,
  readEnvBool,
  readEnvInt,
  maskSecret,
} = require('./env_config');
const { httpError } = require('../../utils/http_error');
const { JEV_POLICIES, getJevPolicy } = require('../ai/jev');

function assertOptionalUrl(value, field) {
  if (!value) return;
  try {
    new URL(value);
  } catch {
    throw httpError(400, `${field} must be a valid URL.`);
  }
}

function assertBoolean(value, field) {
  if (typeof value !== 'boolean') throw httpError(400, `${field} must be a boolean.`);
}

// Parses an integer setting and enforces its lower bound.
function parseMinInt(value, min, field) {
  const parsed = parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < min) throw httpError(400, `${field} must be ≥ ${min}.`);
  return parsed;
}

// --- General ---

function getGeneralSettings() {
  return {
    settings: {
      publicUrl: process.env.PUBLIC_URL || '',
      secureCookies: readEnvBool('SECURE_COOKIES', false),
      allowedOrigins: process.env.ALLOWED_ORIGINS || '',
      meshtasticEnabled: readEnvBool('MESHTASTIC_ENABLED', true),
      memoryIngestionIntervalMs: readEnvInt('NEOAGENT_MEMORY_INGESTION_INTERVAL_MS', 600000),
    },
  };
}

function updateGeneralSettings(body = {}) {
  const publicUrl = cleanLine(body.publicUrl);
  assertOptionalUrl(publicUrl, 'publicUrl');
  const allowedOrigins = cleanLine(body.allowedOrigins);
  const intervalMs = parseMinInt(body.memoryIngestionIntervalMs, 1000, 'memoryIngestionIntervalMs');
  assertBoolean(body.secureCookies, 'secureCookies');
  assertBoolean(body.meshtasticEnabled, 'meshtasticEnabled');

  persistEnv('PUBLIC_URL', publicUrl);
  persistEnv('SECURE_COOKIES', body.secureCookies ? 'true' : 'false');
  persistEnv('ALLOWED_ORIGINS', allowedOrigins);
  persistEnv('MESHTASTIC_ENABLED', body.meshtasticEnabled ? 'true' : 'false');
  persistEnv('NEOAGENT_MEMORY_INGESTION_INTERVAL_MS', intervalMs);
  return { ok: true };
}

// --- Cloud VM runtime ---

function getVmSettings() {
  return {
    settings: {
      vmBaseImageUrl: process.env.NEOAGENT_VM_BASE_IMAGE_URL || '',
      vmBaseImage: process.env.NEOAGENT_VM_BASE_IMAGE || '',
      vmMemoryMb: readEnvInt('NEOAGENT_VM_MEMORY_MB', 4096),
      vmCpus: readEnvInt('NEOAGENT_VM_CPUS', 2),
    },
  };
}

function updateVmSettings(body = {}) {
  const vmBaseImageUrl = cleanLine(body.vmBaseImageUrl);
  const vmBaseImage = cleanLine(body.vmBaseImage);
  assertOptionalUrl(vmBaseImageUrl, 'vmBaseImageUrl');
  const vmMemoryMb = parseMinInt(body.vmMemoryMb, 512, 'vmMemoryMb');
  const vmCpus = parseMinInt(body.vmCpus, 1, 'vmCpus');

  persistEnv('NEOAGENT_VM_BASE_IMAGE_URL', vmBaseImageUrl);
  persistEnv('NEOAGENT_VM_BASE_IMAGE', vmBaseImage);
  persistEnv('NEOAGENT_VM_MEMORY_MB', vmMemoryMb);
  persistEnv('NEOAGENT_VM_CPUS', vmCpus);
  return { ok: true };
}

// --- Stripe / billing setup ---

function getBillingSetup() {
  const secretKey = process.env.STRIPE_SECRET_KEY || '';
  return {
    settings: {
      billingEnabled: readEnvBool('NEOAGENT_BILLING_ENABLED', false),
      stripePublishableKey: process.env.STRIPE_PUBLISHABLE_KEY || '',
      stripeSecretKeyConfigured: Boolean(secretKey),
      stripeSecretKeyHint: maskSecret(secretKey, 7),
      stripeWebhookSecretConfigured: Boolean(process.env.STRIPE_WEBHOOK_SECRET),
      trialDays: readEnvInt('BILLING_TRIAL_DAYS', 14),
    },
  };
}

// Blank secret fields keep the stored secret.
function updateBillingSetup(body = {}) {
  assertBoolean(body.billingEnabled, 'billingEnabled');
  const publishableKey = cleanLine(body.stripePublishableKey);
  const secretKey = cleanLine(body.stripeSecretKey);
  const webhookSecret = cleanLine(body.stripeWebhookSecret);
  const trialDays = parseMinInt(body.trialDays, 0, 'trialDays');

  persistEnv('NEOAGENT_BILLING_ENABLED', body.billingEnabled ? 'true' : 'false');
  persistEnv('STRIPE_PUBLISHABLE_KEY', publishableKey);
  if (secretKey) persistEnv('STRIPE_SECRET_KEY', secretKey);
  if (webhookSecret) persistEnv('STRIPE_WEBHOOK_SECRET', webhookSecret);
  persistEnv('BILLING_TRIAL_DAYS', trialDays);
  return { ok: true };
}

// --- Jev ---

// Agents can also bring their own OpenRouter key, so a missing server key
// only means agents without one cannot use Jev.
function getJevSettings() {
  return {
    policy: getJevPolicy(),
    serverOpenRouterKey: Boolean(process.env.OPENROUTER_API_KEY),
  };
}

// `agent` is the default, so it clears the variable instead of writing it.
function setJevPolicy(policy) {
  if (!JEV_POLICIES.includes(policy)) {
    throw httpError(400, `policy must be one of: ${JEV_POLICIES.join(', ')}.`);
  }
  persistEnv('NEOAGENT_JEV', policy === 'agent' ? '' : policy);
  return { ok: true, policy };
}

// --- Sign-up ---

function getAccessSettings() {
  return { signupEnabled: process.env.NEOAGENT_ALLOW_SIGNUP !== 'false' };
}

// Anything but an explicit `false` turns sign-up on.
function setSignupEnabled(enabled) {
  const signupEnabled = enabled !== false;
  persistEnv('NEOAGENT_ALLOW_SIGNUP', signupEnabled ? 'true' : 'false');
  return { ok: true, signupEnabled };
}

module.exports = {
  getGeneralSettings,
  updateGeneralSettings,
  getVmSettings,
  updateVmSettings,
  getBillingSetup,
  updateBillingSetup,
  getAccessSettings,
  setSignupEnabled,
  getJevSettings,
  setJevPolicy,
};
