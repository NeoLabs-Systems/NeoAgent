'use strict';

const rawContract = require('./contract.json');

function validateStringList(value, field) {
  if (
    !Array.isArray(value)
    || value.length === 0
    || value.some((item) => typeof item !== 'string' || !item.trim())
    || new Set(value).size !== value.length
  ) {
    throw new Error(`Invalid setup contract field: ${field}.`);
  }
  return Object.freeze(value.map((item) => item.trim()));
}

function loadSetupContract(value = rawContract) {
  if (Number(value?.schemaVersion) !== 1) {
    throw new Error('Unsupported setup contract schema version.');
  }
  const defaultPort = Number(value.defaultPort);
  if (!Number.isInteger(defaultPort) || defaultPort < 1 || defaultPort > 65535) {
    throw new Error('Invalid setup contract default port.');
  }
  if (!Array.isArray(value.profiles) || value.profiles.length < 2) {
    throw new Error('The setup contract requires setup profiles.');
  }
  const profiles = Object.freeze(Object.fromEntries(value.profiles.map((profile) => {
    const id = String(profile?.id || '').trim();
    const label = String(profile?.label || '').trim();
    const description = String(profile?.description || '').trim();
    if (!id || !label || !description) {
      throw new Error('Invalid setup profile in setup contract.');
    }
    return [id, Object.freeze({
      id,
      label,
      description,
      optionalCapabilities: Boolean(profile.optionalCapabilities),
    })];
  })));
  if (Object.keys(profiles).length !== value.profiles.length) {
    throw new Error('Duplicate setup profile in setup contract.');
  }
  if (!Array.isArray(value.wizardSections) || value.wizardSections.length === 0) {
    throw new Error('The setup contract requires wizard sections.');
  }
  const wizardSections = Object.freeze(value.wizardSections.map((section) => {
    const id = String(section?.id || '').trim();
    const label = String(section?.label || '').trim();
    if (!id || !label) {
      throw new Error('Invalid setup wizard section in setup contract.');
    }
    return Object.freeze({ id, label, optional: Boolean(section.optional) });
  }));
  if (new Set(wizardSections.map((section) => section.id)).size !== wizardSections.length) {
    throw new Error('Duplicate setup wizard section in setup contract.');
  }
  const runtimeTargets = Object.freeze(Object.fromEntries(
    Object.entries(value.runtimeTargets || {}).map(([platform, architectures]) => [
      platform,
      validateStringList(architectures, `runtimeTargets.${platform}`),
    ]),
  ));
  return Object.freeze({
    schemaVersion: 1,
    defaultPort,
    profiles,
    completionSections: validateStringList(
      value.completionSections,
      'completionSections',
    ),
    wizardSections,
    eventStages: validateStringList(value.eventStages, 'eventStages'),
    resumeValueKeys: validateStringList(
      value.resumeValueKeys,
      'resumeValueKeys',
    ),
    runtimeTargets,
  });
}

const SETUP_CONTRACT = loadSetupContract();

module.exports = {
  DEFAULT_NEOAGENT_PORT: SETUP_CONTRACT.defaultPort,
  SETUP_COMPLETION_SECTIONS: SETUP_CONTRACT.completionSections,
  SETUP_CONTRACT,
  SETUP_EVENT_STAGES: SETUP_CONTRACT.eventStages,
  SETUP_PROFILES: SETUP_CONTRACT.profiles,
  SETUP_RESUME_VALUE_KEYS: SETUP_CONTRACT.resumeValueKeys,
  SETUP_WIZARD_SECTIONS: SETUP_CONTRACT.wizardSections,
  loadSetupContract,
};
