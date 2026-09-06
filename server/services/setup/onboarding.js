'use strict';

const crypto = require('crypto');
const os = require('os');

const db = require('../../db/database');
const {
  SETUP_COMPLETION_SECTIONS,
} = require('../../../lib/setup/contract');
const { getDeploymentPolicy } = require('../../utils/deployment');
const { getVersionInfo } = require('../../utils/version');
const { ENV_FILE, upsertEnvValue } = require('../../../runtime/paths');

const CONTROL_CHAR_PATTERN = new RegExp(
  '[' + String.fromCharCode(0) + '-' + String.fromCharCode(31) + String.fromCharCode(127) + ']',
  'g',
);

function normalizeDisplayName(value) {
  const normalized = String(value || '')
    .replace(CONTROL_CHAR_PATTERN, '')
    .trim()
    .slice(0, 80);
  return normalized || 'NeoAgent';
}

function ensureInstance() {
  let row = db.prepare(
    'SELECT instance_id, display_name, created_at, updated_at FROM neoagent_instance WHERE singleton_id = 1',
  ).get();
  if (row) return row;

  const instanceId = crypto.randomUUID();
  const displayName = normalizeDisplayName(
    process.env.NEOAGENT_INSTANCE_NAME || os.hostname(),
  );
  db.prepare(`
    INSERT OR IGNORE INTO neoagent_instance (singleton_id, instance_id, display_name)
    VALUES (1, ?, ?)
  `).run(instanceId, displayName);
  row = db.prepare(
    'SELECT instance_id, display_name, created_at, updated_at FROM neoagent_instance WHERE singleton_id = 1',
  ).get();
  return row;
}

function userCount() {
  return Number(db.prepare('SELECT COUNT(*) AS count FROM users').get().count);
}

function getSetupHandshake() {
  const instance = ensureInstance();
  const version = getVersionInfo();
  const policy = getDeploymentPolicy();
  const hasUser = userCount() > 0;
  return {
    product: 'NeoAgent',
    protocolVersion: 1,
    serverVersion: version.packageVersion,
    instanceId: instance.instance_id,
    displayName: instance.display_name,
    deploymentProfile: policy.profile,
    claimed: hasUser,
    pairingSupported: true,
    capabilities: ['qr-login'],
  };
}

function getSetupProgress() {
  const profile = process.env.NEOAGENT_SETUP_PROFILE === 'full'
    ? 'full'
    : 'quick';
  const completed = new Set(
    String(process.env.NEOAGENT_SETUP_COMPLETED_SECTIONS || 'core')
      .split(',')
      .map((section) => section.trim())
      .filter((section) => SETUP_COMPLETION_SECTIONS.includes(section)),
  );
  return {
    schemaVersion: 1,
    profile,
    completedSections: SETUP_COMPLETION_SECTIONS.filter(
      (section) => completed.has(section),
    ),
    openSections: SETUP_COMPLETION_SECTIONS.filter(
      (section) => !completed.has(section),
    ),
    complete: SETUP_COMPLETION_SECTIONS.every((section) => completed.has(section)),
  };
}

function markSetupSectionComplete(sectionId) {
  const section = String(sectionId || '').trim();
  if (!SETUP_COMPLETION_SECTIONS.includes(section)) return getSetupProgress();
  const completed = new Set(
    String(process.env.NEOAGENT_SETUP_COMPLETED_SECTIONS || 'core')
      .split(',')
      .map((item) => item.trim())
      .filter((item) => SETUP_COMPLETION_SECTIONS.includes(item)),
  );
  completed.add(section);
  const value = SETUP_COMPLETION_SECTIONS.filter((item) => completed.has(item)).join(',');
  process.env.NEOAGENT_SETUP_COMPLETED_SECTIONS = value;
  upsertEnvValue(ENV_FILE, 'NEOAGENT_SETUP_COMPLETED_SECTIONS', value);
  return getSetupProgress();
}

module.exports = {
  ensureInstance,
  getSetupHandshake,
  getSetupProgress,
  markSetupSectionComplete,
};
