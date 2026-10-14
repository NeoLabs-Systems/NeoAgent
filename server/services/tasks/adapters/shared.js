'use strict';

const {
  ensureOwnedIntegrationConnection,
  normalizeTrimmedText,
} = require('../security');

const MINUTE_MS = 60 * 1000;
const OWNER_REPO_PATTERN = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

// The connection fields every integration trigger stores, checked against the
// agent's own connected account.
function connectionConfig(config, context, providerKey, appKey) {
  const connection = ensureOwnedIntegrationConnection(context.integrationManager, {
    userId: context.userId,
    agentId: context.agentId,
    connectionId: config.connectionId || config.connection_id,
    providerKey,
    appKey,
  });
  return {
    connectionId: connection.id,
    accountEmail: connection.account_email || null,
  };
}

function requiredText(value, maxLength, message) {
  const text = normalizeTrimmedText(value, maxLength);
  if (!text) throw new Error(message);
  return text;
}

function optionalNumber(value) {
  if (value === null || value === undefined || String(value).trim() === '') return null;
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) throw new Error(`"${value}" is not a number.`);
  return numeric;
}

function boundedInteger(value, fallback, min, max) {
  const numeric = Math.round(Number(value));
  return Number.isFinite(numeric) ? Math.max(min, Math.min(numeric, max)) : fallback;
}

function ownerRepo(config) {
  const repo = normalizeTrimmedText(config.repo || config.owner_repo, 200);
  if (!OWNER_REPO_PATTERN.test(repo)) {
    throw new Error('GitHub repository is required in the format "owner/repo".');
  }
  return repo;
}

// Ordered cursors compare as plain strings, so a timestamp leads and is always
// written the same way.
function timeCursor(value, id) {
  const ms = typeof value === 'number' ? value : Date.parse(String(value || ''));
  if (!Number.isFinite(ms)) return null;
  return `${new Date(ms).toISOString()}|${id}`;
}

function sequenceCursor(value) {
  const digits = String(value || '').replace(/\D/g, '');
  return digits ? digits.padStart(16, '0') : null;
}

function listFrom(result, keys = []) {
  if (Array.isArray(result)) return result;
  for (const key of keys) {
    if (Array.isArray(result?.[key])) return result[key];
    if (Array.isArray(result?.result?.[key])) return result.result[key];
  }
  return Array.isArray(result?.result) ? result.result : [];
}

function sortByTimestamp(left, right) {
  return String(left.timestamp).localeCompare(String(right.timestamp));
}

function summaryParts(label, parts) {
  return [label, ...parts.filter(Boolean)].join(' · ');
}

module.exports = {
  MINUTE_MS,
  boundedInteger,
  connectionConfig,
  listFrom,
  optionalNumber,
  ownerRepo,
  requiredText,
  sequenceCursor,
  sortByTimestamp,
  summaryParts,
  timeCursor,
};
