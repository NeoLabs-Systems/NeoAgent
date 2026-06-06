'use strict';

const { compactTextPayload } = require('../ai/preModelCompaction');

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

const FRESHNESS_POLICIES = Object.freeze({
  email: Object.freeze({ intervalMinutes: 60, staleAfterDays: 14 }),
  calendar: Object.freeze({ intervalMinutes: 180, staleAfterDays: 30 }),
  chat: Object.freeze({ intervalMinutes: 60, staleAfterDays: 14 }),
  docs: Object.freeze({ intervalMinutes: 360, staleAfterDays: 60 }),
  tickets: Object.freeze({ intervalMinutes: 120, staleAfterDays: 30 }),
  repos: Object.freeze({ intervalMinutes: 180, staleAfterDays: 45 }),
  files: Object.freeze({ intervalMinutes: 360, staleAfterDays: 60 }),
  crm: Object.freeze({ intervalMinutes: 240, staleAfterDays: 45 }),
  payments: Object.freeze({ intervalMinutes: 360, staleAfterDays: 90 }),
  notes: Object.freeze({ intervalMinutes: 360, staleAfterDays: 90 }),
});

const SOURCE_MEMORY_CATEGORIES = Object.freeze({
  email: 'episodic',
  calendar: 'events',
  chat: 'episodic',
  docs: 'projects',
  tickets: 'tasks',
  repos: 'projects',
  files: 'episodic',
  crm: 'contacts',
  payments: 'events',
  notes: 'episodic',
});

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

function parseJsonObject(value, fallback = {}) {
  if (!value) return { ...fallback };
  if (typeof value === 'object' && !Array.isArray(value)) return { ...value };
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : { ...fallback };
  } catch {
    return { ...fallback };
  }
}

function normalizeSourceType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return SOURCE_TYPES.includes(normalized) ? normalized : 'notes';
}

function getFreshnessPolicy(sourceType) {
  const normalized = normalizeSourceType(sourceType);
  return { ...FRESHNESS_POLICIES[normalized] };
}

function nextSyncFromPolicy(policy, now = Date.now()) {
  const intervalMinutes = Math.max(15, Number(policy?.intervalMinutes) || 360);
  return new Date(now + intervalMinutes * 60 * 1000).toISOString();
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

function buildCoverageForConnection(connection, latestJob = null) {
  const dataDomains = sourceTypesForConnection(connection.provider_key, connection.app_key);
  const supported = dataDomains.length > 0;
  return {
    supported,
    contributesToMemory: supported,
    contributesToTaskExecution: String(connection.status || '') === 'connected',
    status: latestJob?.status || (supported ? 'ready' : 'not_supported'),
    dataDomains,
    lastRefreshAt: latestJob?.completedAt || latestJob?.updatedAt || null,
    nextRefreshAt: latestJob?.nextSyncAt || null,
    documentCount: Number(latestJob?.documentCount || 0),
    error: latestJob?.error || null,
  };
}

module.exports = {
  FRESHNESS_POLICIES,
  SOURCE_MEMORY_CATEGORIES,
  SOURCE_TYPES,
  buildCoverageForConnection,
  getFreshnessPolicy,
  nextSyncFromPolicy,
  normalizeDocument,
  normalizeSourceType,
  parseJsonObject,
  safeTrim,
  sourceTypesForConnection,
};
