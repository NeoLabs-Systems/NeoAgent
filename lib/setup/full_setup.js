'use strict';

const crypto = require('crypto');
const fs = require('fs');

const {
  ENV_FILE,
  ensureRuntimeDirs,
  getDefaultVmBaseImageUrl,
} = require('../../runtime/paths');
const { parseEnv } = require('../../runtime/env');
const { parseReleaseChannel } = require('../../runtime/release_channel');
const { parseDeploymentMode } = require('../../server/utils/deployment');
const {
  DEFAULT_NEOAGENT_PORT,
  SETUP_RESUME_VALUE_KEYS,
  SETUP_WIZARD_SECTIONS,
} = require('./contract');
const { writeEnvUpdatesAtomic } = require('./env_file');
const {
  INTEGRATION_FIELDS,
  PROVIDER_FIELDS,
  SECTION_COMPLETION_KEYS,
  VOICE_FIELDS,
} = require('./full_setup_fields');
const { runSetupWizard } = require('./wizard');

function randomSecret() {
  return crypto.randomBytes(32).toString('base64url');
}

function readEnvironment() {
  const raw = fs.existsSync(ENV_FILE) ? fs.readFileSync(ENV_FILE, 'utf8') : '';
  return {
    raw,
    values: Object.fromEntries(parseEnv(raw).entries()),
  };
}

function normalizeBoolean(value, label) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['true', '1', 'yes', 'on'].includes(normalized)) return 'true';
  if (['false', '0', 'no', 'off'].includes(normalized)) return 'false';
  const error = new Error(`${label} must be true or false.`);
  error.code = 'SETUP_VALUE_INVALID';
  throw error;
}

function parseSectionChoice(value, canGoBack) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'q' || normalized === 'quit') return 'cancel';
  if (canGoBack && (normalized === 'b' || normalized === 'back')) return 'back';
  if (normalized === 'n' || normalized === 'no') return 'skip';
  return 'next';
}

async function promptFields(fields, draft, { ask, askSecret }) {
  for (const field of fields) {
    const fallback = draft[field.key] || field.defaultValue || '';
    draft[field.key] = field.secret
      ? await askSecret(field.label, fallback)
      : await ask(field.label, fallback);
  }
}

function sectionConfigured(draft, sectionId) {
  return (SECTION_COMPLETION_KEYS[sectionId] || [])
    .some((key) => String(draft[key] || '').trim());
}

function mappedCompletedSections(sectionIds) {
  const completed = new Set(sectionIds);
  if (completed.has('core')) completed.add('network');
  completed.delete('review');
  return [...completed];
}

function extractResumeValues(draft) {
  return Object.fromEntries(
    SETUP_RESUME_VALUE_KEYS
      .filter((key) => draft[key] !== undefined && draft[key] !== null)
      .map((key) => [key, String(draft[key])]),
  );
}

function prepareFullSetupResume(state) {
  if (!state || typeof state !== 'object') {
    return {
      startSectionId: null,
      completedSections: [],
      initialValues: {},
    };
  }
  const initialValues = extractResumeValues(state.resumeValues || {});
  const hasCompletedCore = Boolean(initialValues.PORT);
  const stage = String(state.stage || '');
  const startSectionId = stage === 'core' || !hasCompletedCore
    ? 'core'
    : 'providers';
  return {
    startSectionId,
    completedSections: hasCompletedCore ? ['core', 'network'] : [],
    initialValues,
  };
}

async function promptCore(draft, io, suggestedPort, canGoBack) {
  io.heading('Installation and network');
  const portRaw = await io.ask(
    'Server port',
    draft.PORT || String(suggestedPort || DEFAULT_NEOAGENT_PORT),
  );
  const port = Number(portRaw);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    const error = new Error('Server port must be an integer between 1 and 65535.');
    error.code = 'SETUP_PORT_INVALID';
    throw error;
  }
  draft.PORT = String(port);
  draft.PUBLIC_URL = await io.ask('Public base URL', draft.PUBLIC_URL || '');
  const secureDefault = draft.SECURE_COOKIES
    || (draft.PUBLIC_URL.startsWith('https://') ? 'true' : 'false');
  draft.SECURE_COOKIES = normalizeBoolean(
    await io.ask('Secure cookies (true/false)', secureDefault),
    'Secure cookies',
  );
  draft.TRUST_PROXY = normalizeBoolean(
    await io.ask(
      'Trust reverse proxy headers (true/false)',
      draft.TRUST_PROXY || draft.SECURE_COOKIES,
    ),
    'Trust reverse proxy headers',
  );
  draft.NEOAGENT_DEPLOYMENT_MODE = parseDeploymentMode(await io.ask(
    'Deployment mode (self_hosted/managed)',
    draft.NEOAGENT_DEPLOYMENT_MODE || 'self_hosted',
  ));
  draft.NEOAGENT_RELEASE_CHANNEL = parseReleaseChannel(await io.ask(
    'Release channel (stable/beta)',
    draft.NEOAGENT_RELEASE_CHANNEL || 'stable',
  )) || 'stable';
  draft.ALLOWED_ORIGINS = await io.ask(
    'Allowed CORS origins',
    draft.ALLOWED_ORIGINS || '',
  );
  const choice = await io.ask(
    canGoBack
      ? 'Continue, go back, or cancel? (Y/b/q)'
      : 'Continue or cancel? (Y/q)',
    'Y',
  );
  return { action: parseSectionChoice(choice, canGoBack) };
}

async function promptOptionalSection(section, fields, draft, io, canGoBack) {
  io.heading(section.label);
  const choice = await io.ask(
    `Configure ${section.label.toLowerCase()} now? (Y/n${canGoBack ? '/b' : ''}/q)`,
    'Y',
  );
  const action = parseSectionChoice(choice, canGoBack);
  if (action !== 'next') {
    return {
      action,
      completed: sectionConfigured(draft, section.id),
    };
  }
  await promptFields(fields, draft, io);
  const navigation = await io.ask('Continue, go back, or cancel? (Y/b/q)', 'Y');
  return {
    action: parseSectionChoice(navigation, true),
    completed: sectionConfigured(draft, section.id),
  };
}

function countConfigured(draft, keys) {
  return keys.filter((key) => String(draft[key] || '').trim()).length;
}

async function promptReview(draft, io) {
  io.heading('Review');
  io.logInfo(`Port: ${draft.PORT}`);
  io.logInfo(`Network: ${draft.PUBLIC_URL ? 'remote address configured' : 'local/private'}`);
  io.logInfo(
    `AI providers: ${countConfigured(draft, SECTION_COMPLETION_KEYS.providers)} configured`,
  );
  io.logInfo(
    `Integrations: ${countConfigured(draft, SECTION_COMPLETION_KEYS.integrations)} configured`,
  );
  io.logInfo(`Voice: ${sectionConfigured(draft, 'voice') ? 'configured' : 'not configured'}`);
  const choice = await io.ask('Apply this setup, go back, or cancel? (Y/b/q)', 'Y');
  return { action: parseSectionChoice(choice, true) };
}

function buildEnvironmentUpdates(draft) {
  const optionalValue = (value) => (
    String(value || '').trim() ? value : undefined
  );
  return {
    NODE_ENV: 'production',
    PORT: draft.PORT,
    PUBLIC_URL: optionalValue(draft.PUBLIC_URL),
    SECURE_COOKIES: draft.SECURE_COOKIES,
    TRUST_PROXY: draft.TRUST_PROXY,
    SESSION_SECRET: draft.SESSION_SECRET || randomSecret(),
    NEOAGENT_PROFILE: draft.NEOAGENT_PROFILE || 'prod',
    NEOAGENT_DEPLOYMENT_MODE: draft.NEOAGENT_DEPLOYMENT_MODE || 'self_hosted',
    NEOAGENT_RELEASE_CHANNEL: draft.NEOAGENT_RELEASE_CHANNEL || 'stable',
    NEOAGENT_SETUP_CLAIM_REQUIRED: draft.NEOAGENT_SETUP_CLAIM_REQUIRED || 'true',
    NEOAGENT_VM_BASE_IMAGE_URL:
      draft.NEOAGENT_VM_BASE_IMAGE_URL || getDefaultVmBaseImageUrl(),
    NEOAGENT_VM_MEMORY_MB: draft.NEOAGENT_VM_MEMORY_MB || '4096',
    NEOAGENT_VM_CPUS: draft.NEOAGENT_VM_CPUS || '2',
    NEOAGENT_VM_GUEST_TOKEN: draft.NEOAGENT_VM_GUEST_TOKEN || randomSecret(),
    ADMIN_USERNAME: draft.ADMIN_USERNAME || 'admin',
    ADMIN_PASSWORD: draft.ADMIN_PASSWORD || randomSecret(),
    ALLOWED_ORIGINS: optionalValue(draft.ALLOWED_ORIGINS),
    ...Object.fromEntries(
      [...PROVIDER_FIELDS, ...INTEGRATION_FIELDS, ...VOICE_FIELDS]
        .map((field) => [field.key, optionalValue(draft[field.key])]),
    ),
  };
}

async function runFullSetup({
  suggestedPort = null,
  startSectionId = null,
  completedSections = [],
  initialValues = {},
  onTransition = async () => {},
  io,
} = {}) {
  if (!io?.ask || !io?.askSecret) {
    throw new TypeError('runFullSetup requires interactive setup I/O.');
  }
  ensureRuntimeDirs();
  const environment = readEnvironment();
  const draft = { ...environment.values, ...initialValues };
  io.heading('Full setup');
  io.logInfo('Values are validated before any configuration is changed.');

  const result = await runSetupWizard({
    sections: SETUP_WIZARD_SECTIONS,
    startSectionId,
    completedSections: completedSections.filter((section) => section !== 'network'),
    runSection: async (section, state) => {
      if (section.id === 'core') {
        return promptCore(draft, io, suggestedPort, state.canGoBack);
      }
      if (section.id === 'providers') {
        return promptOptionalSection(
          section,
          PROVIDER_FIELDS,
          draft,
          io,
          state.canGoBack,
        );
      }
      if (section.id === 'integrations') {
        return promptOptionalSection(
          section,
          INTEGRATION_FIELDS,
          draft,
          io,
          state.canGoBack,
        );
      }
      if (section.id === 'voice') {
        return promptOptionalSection(
          section,
          VOICE_FIELDS,
          draft,
          io,
          state.canGoBack,
        );
      }
      return promptReview(draft, io);
    },
    onTransition: async (state) => onTransition({
      ...state,
      completedSections: mappedCompletedSections(state.completedSections),
      resumeValues: extractResumeValues(draft),
    }),
  });

  writeEnvUpdatesAtomic(
    ENV_FILE,
    environment.raw,
    buildEnvironmentUpdates(draft),
  );
  io.logOk(`Saved validated configuration to ${ENV_FILE}`);
  return {
    completedSections: mappedCompletedSections(result.completedSections),
    skippedSections: result.skippedSections,
  };
}

module.exports = {
  buildEnvironmentUpdates,
  extractResumeValues,
  prepareFullSetupResume,
  runFullSetup,
};
