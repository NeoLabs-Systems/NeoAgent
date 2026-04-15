'use strict';

const DEFAULT_ACCESS_MODE = 'read_write';
const ALLOWED_ACCESS_MODES = new Set(['read_write', 'read_only']);

function normalizeAccessMode(value, fallback = DEFAULT_ACCESS_MODE) {
  const normalized = String(value || '').trim().toLowerCase();
  return ALLOWED_ACCESS_MODES.has(normalized) ? normalized : fallback;
}

function parseConnectionMetadata(metadataJson) {
  if (!metadataJson) return {};
  if (typeof metadataJson === 'object' && metadataJson !== null && !Array.isArray(metadataJson)) {
    return metadataJson;
  }
  try {
    const parsed = JSON.parse(String(metadataJson));
    return parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : {};
  } catch {
    return {};
  }
}

function getConnectionAccessMode(connectionRow) {
  const metadata = parseConnectionMetadata(connectionRow?.metadata_json || '{}');
  return normalizeAccessMode(metadata.access_mode, DEFAULT_ACCESS_MODE);
}

function withConnectionAccessMode(metadataInput, accessMode) {
  const metadata = parseConnectionMetadata(metadataInput);
  return {
    ...metadata,
    access_mode: normalizeAccessMode(accessMode),
  };
}

function isWriteLikeToolName(toolName) {
  const name = String(toolName || '').trim().toLowerCase();
  if (!name) return false;
  return /(create|update|delete|send|write|modify|append|upload|insert|replace|remove|set|post|patch|put|share|comment|archive|revoke|disconnect|connect|cancel|approve)/.test(
    name,
  );
}

module.exports = {
  DEFAULT_ACCESS_MODE,
  normalizeAccessMode,
  parseConnectionMetadata,
  getConnectionAccessMode,
  withConnectionAccessMode,
  isWriteLikeToolName,
};
