'use strict';

const { compactTextPayload } = require('../ai/preModelCompaction');
const { parseJsonObject } = require('../../utils/text');

const SOURCE_TYPES = Object.freeze([
  'email',
  'calendar',
  'chat',
  'docs',
  'tickets',
  'repos',
  'files',
  'crm',
  'payments',
  'notes',
]);

const INTEGRATION_SOURCE_TYPES = Object.freeze({
  google_workspace: Object.freeze({
    gmail: Object.freeze(['email']),
    calendar: Object.freeze(['calendar']),
    drive: Object.freeze(['files']),
    docs: Object.freeze(['docs']),
    sheets: Object.freeze(['docs', 'files']),
  }),
  microsoft_365: Object.freeze({
    outlook: Object.freeze(['email']),
    calendar: Object.freeze(['calendar']),
    onedrive: Object.freeze(['files']),
    teams: Object.freeze(['chat']),
  }),
  github: Object.freeze({
    repos: Object.freeze(['repos', 'tickets']),
  }),
  slack: Object.freeze({
    slack: Object.freeze(['chat']),
  }),
  whatsapp: Object.freeze({
    personal: Object.freeze(['chat']),
  }),
  notion: Object.freeze({
    notion: Object.freeze(['notes', 'docs']),
  }),
  trello: Object.freeze({
    trello: Object.freeze(['tickets']),
  }),
});

function safeTrim(value, maxLength = 240) {
  return String(value || '').trim().slice(0, maxLength);
}

function normalizeSourceType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return SOURCE_TYPES.includes(normalized) ? normalized : 'notes';
}

function normalizeDocument(raw = {}, defaults = {}) {
  const sourceType = normalizeSourceType(raw.sourceType || defaults.sourceType);
  const externalObjectId = safeTrim(raw.externalObjectId || raw.id || raw.sourceId, 180);
  const contentSource = raw.content ?? raw.text ?? raw.body ?? '';
  const content = safeTrim(contentSource, 12000);
  if (!externalObjectId || !content) {
    throw new Error('Normalized memory documents require externalObjectId and content.');
  }
  const compacted = compactTextPayload(content, { maxChars: 2400, maxLines: 50 });
  return {
    sourceType,
    normalizedType: normalizeSourceType(raw.normalizedType || raw.memoryType || sourceType),
    providerKey: safeTrim(raw.providerKey || defaults.providerKey, 80),
    connectionId: Number.isInteger(Number(raw.connectionId ?? defaults.connectionId))
      ? Number(raw.connectionId ?? defaults.connectionId)
      : 0,
    externalObjectId,
    sourceAccount: safeTrim(raw.sourceAccount || defaults.sourceAccount, 180),
    title: safeTrim(raw.title || raw.subject || raw.name || externalObjectId, 220),
    content,
    summary: safeTrim(raw.summary || compacted.text, 1200),
    salience: Math.max(1, Math.min(10, Number(raw.salience) || 5)),
    sourceTimestamp: safeTrim(raw.sourceTimestamp || raw.updatedAt || raw.createdAt, 80) || null,
    metadata: {
      ...parseJsonObject(raw.metadata, {}),
      compaction: compacted.metrics,
    },
    payload: parseJsonObject(raw.payload, {}),
  };
}

function sourceTypesForConnection(providerKey, appKey) {
  const providerMap = INTEGRATION_SOURCE_TYPES[String(providerKey || '').trim()] || {};
  return Array.from(providerMap[String(appKey || '').trim()] || []);
}

function buildCoverageForConnection(connection, latestJob, dataDomains) {
  const supported = dataDomains.length > 0;
  return {
    supported,
    contributesToMemory: supported,
    contributesToTaskExecution: String(connection.status || '') === 'connected',
    status: latestJob?.status || (supported ? 'ready' : 'not_supported'),
    dataDomains,
    lastRefreshAt: latestJob?.completedAt || latestJob?.updatedAt || null,
    documentCount: Number(latestJob?.documentCount || 0),
    error: latestJob?.error || null,
  };
}

module.exports = {
  SOURCE_TYPES,
  buildCoverageForConnection,
  normalizeDocument,
  normalizeSourceType,
  parseJsonObject,
  safeTrim,
  sourceTypesForConnection,
};
