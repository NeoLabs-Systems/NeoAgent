'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  buildEnvironmentUpdates,
  extractResumeValues,
  prepareFullSetupResume,
} = require('../../../lib/setup/full_setup');

test('full setup resume state excludes secrets and re-enters sensitive sections', () => {
  const resumeValues = extractResumeValues({
    PORT: '4444',
    PUBLIC_URL: 'https://neoagent.example',
    OPENAI_BASE_URL: 'https://api.example/v1',
    OPENAI_API_KEY: 'must-not-be-persisted',
    GOOGLE_OAUTH_CLIENT_SECRET: 'must-not-be-persisted',
  });
  assert.deepEqual(resumeValues, {
    PORT: '4444',
    PUBLIC_URL: 'https://neoagent.example',
    OPENAI_BASE_URL: 'https://api.example/v1',
  });

  assert.deepEqual(prepareFullSetupResume({
    stage: 'review',
    completedSections: ['core', 'providers', 'integrations', 'voice'],
    resumeValues,
  }), {
    startSectionId: 'providers',
    completedSections: ['core', 'network'],
    initialValues: resumeValues,
  });
});

test('full setup restarts core when resumable core values are unavailable', () => {
  assert.deepEqual(prepareFullSetupResume({
    stage: 'integrations',
    completedSections: ['core', 'providers'],
  }), {
    startSectionId: 'core',
    completedSections: [],
    initialValues: {},
  });
});

test('full setup environment plan preserves identity and omits blank options', () => {
  const updates = buildEnvironmentUpdates({
    PORT: '4444',
    SECURE_COOKIES: 'false',
    TRUST_PROXY: 'false',
    SESSION_SECRET: 'existing-session-secret',
    NEOAGENT_VM_GUEST_TOKEN: 'existing-guest-token',
    ADMIN_PASSWORD: 'existing-admin-password',
    OPENAI_API_KEY: '',
  });
  assert.equal(updates.SESSION_SECRET, 'existing-session-secret');
  assert.equal(updates.NEOAGENT_VM_GUEST_TOKEN, 'existing-guest-token');
  assert.equal(updates.ADMIN_PASSWORD, 'existing-admin-password');
  assert.equal(updates.OPENAI_API_KEY, undefined);
  assert.equal(updates.PUBLIC_URL, undefined);
});
