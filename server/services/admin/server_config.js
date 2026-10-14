'use strict';

const {
  cleanLine,
  persistEnv,
  readEnvBool,
  readEnvInt,
} = require('./env_config');
const { httpError } = require('../../utils/http_error');
const { getComputerResourceProfile } = require('../runtime/resource_profile');
const { getDeploymentPolicy } = require('../../utils/deployment');

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

  persistEnv('PUBLIC_URL', publicUrl);
  persistEnv('SECURE_COOKIES', body.secureCookies ? 'true' : 'false');
  persistEnv('ALLOWED_ORIGINS', allowedOrigins);
  persistEnv('NEOAGENT_MEMORY_INGESTION_INTERVAL_MS', intervalMs);
  return { ok: true };
}

// --- Cloud computers ---

// The memory and vCPU caps are upper limits: each computer gets less when the
// host is busy (see services/runtime/resource_profile.js).
function getVmSettings() {
  const profile = getComputerResourceProfile();
  return {
    settings: {
      vmBaseImage: process.env.NEOAGENT_VM_BASE_IMAGE || '',
      minMemoryMb: profile.minimumGuestMemoryMb,
      maxMemoryMb: profile.maximumGuestMemoryMb,
      maxCpus: profile.maximumGuestCpus,
    },
  };
}

function updateVmSettings(body = {}) {
  const vmBaseImage = cleanLine(body.vmBaseImage);
  const { minimumGuestMemoryMb } = getComputerResourceProfile();
  const maxMemoryMb = parseMinInt(body.maxMemoryMb, minimumGuestMemoryMb, 'maxMemoryMb');
  const maxCpus = parseMinInt(body.maxCpus, 1, 'maxCpus');

  persistEnv('NEOAGENT_VM_BASE_IMAGE', vmBaseImage);
  persistEnv('NEOAGENT_COMPUTER_MAX_MEMORY_MB', maxMemoryMb);
  persistEnv('NEOAGENT_COMPUTER_MAX_CPUS', maxCpus);
  return { ok: true };
}

// --- Sign-up ---

function getAccessSettings() {
  return { signupKeyRequired: getDeploymentPolicy().signupKeyRequired };
}

// Requiring a key turns open sign-up off; the keys themselves live in
// services/access/signup_keys.js.
function setSignupKeyRequired(required) {
  assertBoolean(required, 'keyRequired');
  persistEnv('NEOAGENT_ALLOW_SIGNUP', required ? 'false' : 'true');
  return { ok: true, signupKeyRequired: required };
}

module.exports = {
  getGeneralSettings,
  updateGeneralSettings,
  getVmSettings,
  updateVmSettings,
  getAccessSettings,
  setSignupKeyRequired,
};
