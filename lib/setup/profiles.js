'use strict';

const fs = require('fs');
const net = require('net');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const {
  DEFAULT_NEOAGENT_PORT,
  SETUP_PROFILES,
  SETUP_RESUME_VALUE_KEYS,
} = require('./contract');

const SETUP_SCHEMA_VERSION = 1;
const setupResumeValueKeys = new Set(SETUP_RESUME_VALUE_KEYS);

function normalizeSetupProfile(value, fallback = 'quick') {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'quick' || normalized === 'quickstart') return 'quick';
  if (normalized === 'full' || normalized === 'complete') return 'full';
  return fallback;
}

function parseSetupArguments(args = []) {
  const values = Array.from(args, (value) => String(value));
  let requestedProfile = null;
  if (values.includes('--quick')) requestedProfile = 'quick';
  if (values.includes('--full')) {
    if (requestedProfile) {
      const error = new Error('Choose either --quick or --full, not both.');
      error.code = 'SETUP_PROFILE_CONFLICT';
      throw error;
    }
    requestedProfile = 'full';
  }
  return {
    profile: requestedProfile,
    resume: values.includes('--resume'),
    json: values.includes('--json'),
    nonInteractive: values.includes('--non-interactive'),
    runtimePackage: values.includes('--runtime-package'),
    deferOptionalSections: values.includes('--defer-optional-sections'),
  };
}

function safeSetupState(state = {}) {
  const resumeValues = Object.fromEntries(
    Object.entries(state.resumeValues || {})
      .filter(([key, value]) => (
        setupResumeValueKeys.has(key)
        && value !== undefined
        && value !== null
        && String(value).length <= 4096
      ))
      .map(([key, value]) => [key, String(value)]),
  );
  return {
    schemaVersion: SETUP_SCHEMA_VERSION,
    runId: String(state.runId || crypto.randomUUID()),
    profile: normalizeSetupProfile(state.profile),
    stage: String(state.stage || 'choose-profile'),
    status: String(state.status || 'pending'),
    completedSections: Array.isArray(state.completedSections)
      ? state.completedSections.map((section) => String(section))
      : [],
    resumeValues,
    updatedAt: new Date().toISOString(),
  };
}

function writeSetupState(stateFile, state) {
  const normalized = safeSetupState(state);
  const directory = path.dirname(stateFile);
  const temporary = path.join(
    directory,
    `.${path.basename(stateFile)}.${process.pid}.${crypto.randomBytes(6).toString('hex')}.tmp`,
  );
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(temporary, `${JSON.stringify(normalized, null, 2)}\n`, {
    encoding: 'utf8',
    mode: 0o600,
    flag: 'wx',
  });
  fs.renameSync(temporary, stateFile);
  return normalized;
}

function readSetupState(stateFile) {
  try {
    const value = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
    if (Number(value?.schemaVersion) !== SETUP_SCHEMA_VERSION) return null;
    return safeSetupState(value);
  } catch {
    return null;
  }
}

function clearSetupState(stateFile) {
  fs.rmSync(stateFile, { force: true });
}

function isPortAvailable(port, host = '127.0.0.1') {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.unref();
    server.once('error', () => resolve(false));
    server.listen({ port, host, exclusive: true }, () => {
      server.close(() => resolve(true));
    });
  });
}

async function findAvailablePort(
  preferredPort = DEFAULT_NEOAGENT_PORT,
  options = {},
) {
  const preferred = Number(preferredPort);
  const start = Number.isInteger(preferred) && preferred > 0 && preferred <= 65535
    ? preferred
    : DEFAULT_NEOAGENT_PORT;
  const attempts = Number.isInteger(options.attempts) && options.attempts > 0
    ? options.attempts
    : 100;
  for (let offset = 0; offset < attempts && start + offset <= 65535; offset += 1) {
    const candidate = start + offset;
    if (await isPortAvailable(candidate, options.host || '127.0.0.1')) {
      return candidate;
    }
  }
  const error = new Error(`No available port was found from ${start}.`);
  error.code = 'SETUP_PORT_UNAVAILABLE';
  throw error;
}

function createInstallPlan({
  profile = 'quick',
  port,
  platform = process.platform,
  existingInstallation = false,
  runtimePackage = false,
  deferredOptionalSections = false,
} = {}) {
  const normalizedProfile = normalizeSetupProfile(profile);
  const normalizedPort = Number(port);
  if (!Number.isInteger(normalizedPort) || normalizedPort < 1 || normalizedPort > 65535) {
    const error = new Error('The setup plan requires a valid server port.');
    error.code = 'SETUP_PORT_INVALID';
    throw error;
  }
  return Object.freeze({
    schemaVersion: SETUP_SCHEMA_VERSION,
    profile: normalizedProfile,
    platform,
    architecture: os.arch(),
    port: normalizedPort,
    existingInstallation: Boolean(existingInstallation),
    runtimePackage: Boolean(runtimePackage),
    deferredOptionalSections: Boolean(deferredOptionalSections),
    installOptionalCapabilities: SETUP_PROFILES[normalizedProfile].optionalCapabilities,
  });
}

module.exports = {
  SETUP_PROFILES,
  SETUP_SCHEMA_VERSION,
  clearSetupState,
  createInstallPlan,
  findAvailablePort,
  isPortAvailable,
  normalizeSetupProfile,
  parseSetupArguments,
  readSetupState,
  safeSetupState,
  writeSetupState,
};
