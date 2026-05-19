const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const db = require('../../db/database');
const {
  getEmbedding,
  cosineSimilarity,
  serializeEmbedding,
  deserializeEmbedding,
  keywordSimilarity
} = require('./embeddings');
const { getMemoryStorageDecision } = require('./policy');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const {
  decryptLocalValue,
  encryptLocalValue,
  isLocalEncryptedValue,
} = require('../../utils/local_secrets');

async function getActiveProvider(userId, agentId = null) {
  try {
    const { getSupportedModels } = require('../ai/models');
    const { getAiSettings } = require('../ai/settings');
    const models = await getSupportedModels(userId, agentId);
    const aiSettings = getAiSettings(userId, agentId);
    const defaultChatModel = aiSettings.default_chat_model || null;
    const enabledIds = Array.isArray(aiSettings.enabled_models) ? aiSettings.enabled_models : null;

    const modelId = defaultChatModel && defaultChatModel !== 'auto'
      ? defaultChatModel
      : (Array.isArray(enabledIds) && enabledIds.length > 0 ? enabledIds[0] : null);

    if (modelId) {
      const def = models.find(m => m.id === modelId && m.available !== false);
      if (def) return def.provider;
    }
  } catch { }
  return null;
}

const DATA_DIR = AGENT_DATA_DIR;
const SHARED_API_KEYS_FILE = path.join(DATA_DIR, 'API_KEYS.json');
const SHARED_DAILY_DIR = path.join(DATA_DIR, 'daily');
const MEMORY_DIR = path.join(DATA_DIR, 'memory');
const SKILLS_DIR = path.join(DATA_DIR, 'skills');
const USERS_DIR = path.join(DATA_DIR, 'users');

// Memory categories / v2 types
const CATEGORIES = [
  'identity',
  'preferences',
  'projects',
  'contacts',
  'events',
  'tasks',
  'episodic',
  'assistant_self',
  'user_fact',
  'preference',
  'personality',
];

// Core memory keys (always injected into every prompt)
const CORE_KEYS = ['user_profile', 'preferences', 'ai_personality'];

const CATEGORY_ALIASES = {
  user_fact: 'identity',
  preference: 'preferences',
  personality: 'assistant_self',
};

function normalizeMemoryCategory(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (CATEGORY_ALIASES[normalized]) return CATEGORY_ALIASES[normalized];
  return CATEGORIES.includes(normalized) ? normalized : 'episodic';
}

function normalizeScope(input, fallbackAgentId) {
  const raw = input && typeof input === 'object' && !Array.isArray(input) ? input : {};
  const scopeType = String(raw.scopeType || raw.type || 'agent').trim().toLowerCase();
  const scopeId = String(raw.scopeId || raw.id || '').trim() || null;
  switch (scopeType) {
    case 'conversation':
    case 'task':
    case 'channel':
    case 'shared':
      return { scopeType, scopeId };
    default:
      return { scopeType: 'agent', scopeId: fallbackAgentId || null };
  }
}

function normalizeSourceRef(input = {}) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    return { sourceType: null, sourceId: null, sourceLabel: null };
  }
  return {
    sourceType: String(input.sourceType || input.type || '').trim().slice(0, 48) || null,
    sourceId: String(input.sourceId || input.id || '').trim().slice(0, 128) || null,
    sourceLabel: String(input.sourceLabel || input.label || '').trim().slice(0, 160) || null,
  };
}

function parseJsonObject(value, fallback = {}) {
  if (!value) return { ...fallback };
  if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
    return { ...value };
  }
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : { ...fallback };
  } catch {
    return { ...fallback };
  }
}

function parseJsonArray(value, fallback = []) {
  if (Array.isArray(value)) return [...value];
  try {
    const parsed = JSON.parse(String(value || '[]'));
    return Array.isArray(parsed) ? parsed : [...fallback];
  } catch {
    return [...fallback];
  }
}

function computeFreshnessMultiplier(row) {
  const staleAfterDays = Number(row?.stale_after_days);
  if (!Number.isFinite(staleAfterDays) || staleAfterDays <= 0) return 1;
  const updatedAt = Date.parse(row?.updated_at || row?.created_at || '');
  if (!Number.isFinite(updatedAt)) return 1;
  const ageDays = Math.max(0, (Date.now() - updatedAt) / (1000 * 60 * 60 * 24));
  if (ageDays <= staleAfterDays) return 1;
  return Math.max(0.35, 1 - ((ageDays - staleAfterDays) / Math.max(staleAfterDays, 1)) * 0.2);
}

function serializeMemoryRow(row) {
  const metadata = parseJsonObject(row?.metadata_json, {});
  return {
    id: row.id,
    category: normalizeMemoryCategory(row.category),
    content: row.content,
    importance: Number(row.importance || 0),
    access_count: Number(row.access_count || 0),
    archived: Number(row.archived || 0),
    created_at: row.created_at,
    updated_at: row.updated_at,
    sourceRef: {
      sourceType: row.source_type || null,
      sourceId: row.source_id || null,
      sourceLabel: row.source_label || null,
    },
    scope: {
      scopeType: row.scope_type || 'agent',
      scopeId: row.scope_id || null,
    },
    staleAfterDays: row.stale_after_days == null ? null : Number(row.stale_after_days),
    metadata,
  };
}

function parseStringSetting(value) {
  if (typeof value !== 'string') return '';
  try {
    const parsed = JSON.parse(value);
    return typeof parsed === 'string' ? parsed : value;
  } catch {
    return value;
  }
}

function buildFtsQuery(query) {
  const tokens = String(query || '')
    .match(/[\p{L}\p{N}_-]{2,}/gu) || [];
  if (!tokens.length) return null;
  return tokens.map((token) => `${token.replace(/"/g, '')}*`).join(' AND ');
}

function stripHighlight(text) {
  return String(text || '').replace(/<\/?mark>/g, '');
}

function buildExcerpt(text, query) {
  const raw = stripHighlight(text);
  const needle = String(query || '').trim().toLowerCase();
  if (!raw) return '';
  if (!needle) return raw.slice(0, 220);

  const pos = raw.toLowerCase().indexOf(needle);
  if (pos === -1) return raw.slice(0, 220);

  const start = Math.max(0, pos - 80);
  const end = Math.min(raw.length, pos + needle.length + 140);
  const prefix = start > 0 ? '...' : '';
  const suffix = end < raw.length ? '...' : '';
  return `${prefix}${raw.slice(start, end)}${suffix}`;
}

function tokenizeRecallQuery(query) {
  return (String(query || '').toLowerCase().match(/[\p{L}\p{N}_-]{3,}/gu) || [])
    .slice(0, 12);
}

function normalizeStringArray(value, maxItems = 24, maxLength = 160) {
  return [...new Set(
    (Array.isArray(value) ? value : [])
      .map((item) => String(item || '').trim().slice(0, maxLength))
      .filter(Boolean)
  )].slice(0, maxItems);
}

function scoreSchedulerRunMatch(queryTokens, title, finalResponse) {
  if (!queryTokens.length) return 0;
  const haystack = `${String(title || '')} ${String(finalResponse || '')}`.toLowerCase();
  let score = 0;
  for (const token of queryTokens) {
    if (haystack.includes(token)) score += 1;
  }
  return score;
}

class MemoryManager {
  constructor() {
    this._ensureDirs();
  }

  _ensureDirs() {
    for (const dir of [DATA_DIR, USERS_DIR, SHARED_DAILY_DIR, MEMORY_DIR, SKILLS_DIR]) {
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    }
    if (!fs.existsSync(SHARED_API_KEYS_FILE)) fs.writeFileSync(SHARED_API_KEYS_FILE, '{}', 'utf-8');
  }

  _userDir(userId) {
    const segment = String(userId || 'shared');
    const resolved = path.resolve(path.join(USERS_DIR, segment));
    if (!resolved.startsWith(path.resolve(USERS_DIR) + path.sep) && resolved !== path.resolve(USERS_DIR)) {
      throw new Error('Invalid user directory path');
    }
    return resolved;
  }

  _ensureUserDirs(userId) {
    const userDir = this._userDir(userId);
    const dailyDir = path.join(userDir, 'daily');
    fs.mkdirSync(userDir, { recursive: true });
    fs.mkdirSync(dailyDir, { recursive: true });
    return { userDir, dailyDir };
  }

  _userApiKeysPath(userId) {
    if (userId == null) return SHARED_API_KEYS_FILE;
    const { userDir } = this._ensureUserDirs(userId);
    return path.join(userDir, 'API_KEYS.json');
  }

  _userDailyDir(userId) {
    if (userId == null) return SHARED_DAILY_DIR;
    return this._ensureUserDirs(userId).dailyDir;
  }

  _agentId(userId, options = {}) {
    return resolveAgentId(userId, options?.agentId || options?.agent_id || null);
  }

  getAssistantBehaviorNotes(userId, options = {}) {
    if (userId == null) return '';
    const agentId = this._agentId(userId, options);
    const row = db.prepare('SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?')
      .get(userId, agentId, 'assistant_behavior_notes')
      || (isMainAgent(userId, agentId)
        ? db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
          .get(userId, 'assistant_behavior_notes')
        : null);
    return parseStringSetting(row?.value);
  }

  setAssistantBehaviorNotes(userId, content, options = {}) {
    if (userId == null) return;
    const agentId = this._agentId(userId, options);
    db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
    ).run(userId, agentId, 'assistant_behavior_notes', String(content || ''));
  }

  getAssistantSelfState(userId, options = {}) {
    if (userId == null) {
      return { identity: {}, focus: {} };
    }
    const agentId = this._agentId(userId, options);
    const row = db.prepare(
      'SELECT identity_json, focus_json, updated_at FROM assistant_self_state WHERE user_id = ? AND agent_id = ?'
    ).get(userId, agentId);
    return {
      identity: parseJsonObject(row?.identity_json, {}),
      focus: parseJsonObject(row?.focus_json, {}),
      updatedAt: row?.updated_at || null,
    };
  }

  updateAssistantSelfState(userId, patch = {}, options = {}) {
    if (userId == null) return this.getAssistantSelfState(userId, options);
    const agentId = this._agentId(userId, options);
    const current = this.getAssistantSelfState(userId, { agentId });
    const nextIdentity = {
      ...current.identity,
      ...parseJsonObject(patch.identity, {}),
    };
    const nextFocus = {
      ...current.focus,
      ...parseJsonObject(patch.focus, {}),
    };
    db.prepare(
      `INSERT INTO assistant_self_state (user_id, agent_id, identity_json, focus_json, updated_at)
       VALUES (?, ?, ?, ?, datetime('now'))
       ON CONFLICT(user_id, agent_id) DO UPDATE SET
         identity_json = excluded.identity_json,
         focus_json = excluded.focus_json,
         updated_at = excluded.updated_at`
    ).run(
      userId,
      agentId,
      JSON.stringify(nextIdentity),
      JSON.stringify(nextFocus),
    );
    return this.getAssistantSelfState(userId, { agentId });
  }

  listIngestionJobs(userId, { agentId = null, sourceType = null, providerKey = null, limit = 25 } = {}) {
    const scopedAgentId = this._agentId(userId, { agentId });
    let sql = `SELECT *
               FROM memory_ingestion_jobs
               WHERE user_id = ? AND agent_id = ?`;
    const params = [userId, scopedAgentId];
    if (sourceType) {
      sql += ' AND source_type = ?';
      params.push(String(sourceType).trim());
    }
    if (providerKey) {
      sql += ' AND provider_key = ?';
      params.push(String(providerKey).trim());
    }
    sql += ' ORDER BY updated_at DESC LIMIT ?';
    params.push(Math.max(1, Math.min(Number(limit) || 25, 100)));
    return db.prepare(sql).all(...params).map((row) => ({
      id: row.id,
      sourceType: row.source_type,
      providerKey: row.provider_key || null,
      connectionId: row.connection_id == null ? null : Number(row.connection_id),
      status: row.status || 'pending',
      freshnessPolicy: parseJsonObject(row.freshness_policy_json, {}),
      cursor: parseJsonObject(row.cursor_json, {}),
      summary: parseJsonObject(row.summary_json, {}),
      metadata: parseJsonObject(row.metadata_json, {}),
      documentCount: Number(row.document_count || 0),
      error: row.error_text || null,
      startedAt: row.started_at || null,
      completedAt: row.completed_at || null,
      nextSyncAt: row.next_sync_at || null,
      updatedAt: row.updated_at || null,
    }));
  }

  recordIngestionJob(userId, job = {}, options = {}) {
    const scopedAgentId = this._agentId(userId, options);
    const jobId = String(job.id || uuidv4()).trim();
    db.prepare(
      `INSERT INTO memory_ingestion_jobs (
        id, user_id, agent_id, source_type, provider_key, connection_id, status,
        freshness_policy_json, cursor_json, summary_json, metadata_json, document_count,
        error_text, started_at, completed_at, next_sync_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, datetime('now')), ?, ?, datetime('now'), datetime('now'))
      ON CONFLICT(id) DO UPDATE SET
        status = excluded.status,
        freshness_policy_json = excluded.freshness_policy_json,
        cursor_json = excluded.cursor_json,
        summary_json = excluded.summary_json,
        metadata_json = excluded.metadata_json,
        document_count = excluded.document_count,
        error_text = excluded.error_text,
        completed_at = excluded.completed_at,
        next_sync_at = excluded.next_sync_at,
        updated_at = excluded.updated_at`
    ).run(
      jobId,
      userId,
      scopedAgentId,
      String(job.sourceType || '').trim() || 'unknown',
      String(job.providerKey || '').trim(),
      Number.isInteger(Number(job.connectionId)) && Number(job.connectionId) > 0 ? Number(job.connectionId) : null,
      String(job.status || 'completed').trim() || 'completed',
      JSON.stringify(parseJsonObject(job.freshnessPolicy, {})),
      JSON.stringify(parseJsonObject(job.cursor, {})),
      JSON.stringify(parseJsonObject(job.summary, {})),
      JSON.stringify(parseJsonObject(job.metadata, {})),
      Number(job.documentCount) || 0,
      String(job.error || '').trim() || null,
      job.startedAt || null,
      job.completedAt || null,
      job.nextSyncAt || null,
    );
    return jobId;
  }

  upsertIngestionDocument(userId, document = {}, options = {}) {
    const scopedAgentId = this._agentId(userId, options);
    const providerKey = String(document.providerKey || '').trim();
    const connectionId = Number.isInteger(Number(document.connectionId)) && Number(document.connectionId) > 0
      ? Number(document.connectionId)
      : 0;
    const sourceType = String(document.sourceType || '').trim() || 'unknown';
    const externalObjectId = String(document.externalObjectId || '').trim();
    const content = String(document.content || '').trim();
    if (!externalObjectId || !content) {
      throw new Error('Ingestion documents require externalObjectId and content.');
    }

    const existing = db.prepare(
      `SELECT id, metadata_json
       FROM memory_ingestion_documents
       WHERE user_id = ? AND agent_id = ? AND source_type = ? AND provider_key = ? AND connection_id = ? AND external_object_id = ?`
    ).get(userId, scopedAgentId, sourceType, providerKey, connectionId, externalObjectId);

    const docId = existing?.id || uuidv4();
    const nextMetadata = {
      ...parseJsonObject(existing?.metadata_json, {}),
      ...parseJsonObject(document.metadata, {}),
    };

    db.prepare(
      `INSERT INTO memory_ingestion_documents (
        id, user_id, agent_id, source_type, normalized_type, provider_key, connection_id,
        external_object_id, source_account, title, content, summary, salience, source_timestamp,
        metadata_json, payload_json, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
      ON CONFLICT(id) DO UPDATE SET
        normalized_type = excluded.normalized_type,
        source_account = excluded.source_account,
        title = excluded.title,
        content = excluded.content,
        summary = excluded.summary,
        salience = excluded.salience,
        source_timestamp = excluded.source_timestamp,
        metadata_json = excluded.metadata_json,
        payload_json = excluded.payload_json,
        updated_at = excluded.updated_at`
    ).run(
      docId,
      userId,
      scopedAgentId,
      sourceType,
      String(document.normalizedType || sourceType).trim() || sourceType,
      providerKey,
      connectionId,
      externalObjectId,
      String(document.sourceAccount || '').trim() || null,
      String(document.title || '').trim() || null,
      content,
      String(document.summary || '').trim() || null,
      Math.max(1, Math.min(10, Number(document.salience) || 5)),
      document.sourceTimestamp || null,
      JSON.stringify(nextMetadata),
      JSON.stringify(parseJsonObject(document.payload, {})),
    );

    return docId;
  }

  listIngestionDocuments(userId, { agentId = null, sourceType = null, providerKey = null, limit = 40 } = {}) {
    const scopedAgentId = this._agentId(userId, { agentId });
    let sql = `SELECT *
               FROM memory_ingestion_documents
               WHERE user_id = ? AND agent_id = ?`;
    const params = [userId, scopedAgentId];
    if (sourceType) {
      sql += ' AND source_type = ?';
      params.push(String(sourceType).trim());
    }
    if (providerKey) {
      sql += ' AND provider_key = ?';
      params.push(String(providerKey).trim());
    }
    sql += ' ORDER BY updated_at DESC LIMIT ?';
    params.push(Math.max(1, Math.min(Number(limit) || 40, 200)));
    return db.prepare(sql).all(...params).map((row) => ({
      id: row.id,
      sourceType: row.source_type,
      normalizedType: row.normalized_type,
      providerKey: row.provider_key || null,
      connectionId: row.connection_id ? Number(row.connection_id) : null,
      externalObjectId: row.external_object_id,
      sourceAccount: row.source_account || null,
      title: row.title || null,
      content: row.content,
      summary: row.summary || null,
      salience: Number(row.salience || 0),
      sourceTimestamp: row.source_timestamp || null,
      metadata: parseJsonObject(row.metadata_json, {}),
      payload: parseJsonObject(row.payload_json, {}),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));
  }

  getIngestionOverview(userId, { agentId = null, limit = 12 } = {}) {
    const jobs = this.listIngestionJobs(userId, { agentId, limit });
    const byProvider = new Map();
    for (const job of jobs) {
      const providerKey = job.providerKey || `local:${job.sourceType}`;
      if (!byProvider.has(providerKey)) {
        byProvider.set(providerKey, {
          providerKey,
          sourceTypes: new Set(),
          status: job.status,
          lastRefreshAt: job.completedAt || job.updatedAt || null,
          nextRefreshAt: job.nextSyncAt || null,
          documentCount: 0,
          error: job.error || null,
        });
      }
      const current = byProvider.get(providerKey);
      current.sourceTypes.add(job.sourceType);
      current.documentCount += job.documentCount;
      if (current.status !== 'failed' && job.status === 'failed') current.status = 'failed';
      if (!current.error && job.error) current.error = job.error;
    }
    return Array.from(byProvider.values()).map((item) => ({
      providerKey: item.providerKey,
      sourceTypes: Array.from(item.sourceTypes),
      status: item.status,
      lastRefreshAt: item.lastRefreshAt,
      nextRefreshAt: item.nextRefreshAt,
      documentCount: item.documentCount,
      error: item.error,
    }));
  }

  materializeKnowledgeViews(userId, { agentId = null } = {}) {
    const scopedAgentId = this._agentId(userId, { agentId });
    const memories = this.listMemories(userId, { limit: 200, agentId: scopedAgentId });
    const documents = this.listIngestionDocuments(userId, { limit: 200, agentId: scopedAgentId });
    const views = [];

    const topicGroups = new Map();
    for (const memory of memories) {
      const key = memory.category || 'episodic';
      if (!topicGroups.has(key)) topicGroups.set(key, []);
      topicGroups.get(key).push(memory);
    }
    for (const [topic, items] of topicGroups.entries()) {
      const summary = items.slice(0, 4).map((item) => `- ${item.content}`).join('\n');
      views.push({
        viewType: 'topic',
        subjectKey: topic,
        title: topic.replace(/_/g, ' '),
        summary: summary.slice(0, 320),
        markdownText: `# ${topic}\n\n${summary}`,
        sourceMemoryIds: items.map((item) => item.id),
        sourceDocumentIds: [],
        metadata: {
          itemCount: items.length,
          category: topic,
        },
      });
    }

    const accountGroups = new Map();
    for (const doc of documents) {
      const accountKey = `${doc.providerKey || 'local'}:${doc.sourceAccount || 'default'}`;
      if (!accountGroups.has(accountKey)) accountGroups.set(accountKey, []);
      accountGroups.get(accountKey).push(doc);
    }
    for (const [accountKey, items] of accountGroups.entries()) {
      const lead = items[0];
      const lines = items.slice(0, 4).map((item) => `- ${item.title || item.normalizedType}: ${item.summary || item.content}`);
      views.push({
        viewType: 'account',
        subjectKey: accountKey,
        title: `${lead.providerKey || 'local'} ${lead.sourceAccount || 'account'}`,
        summary: lines.join('\n').slice(0, 320),
        markdownText: `# ${lead.providerKey || 'local'} / ${lead.sourceAccount || 'account'}\n\n${lines.join('\n')}`,
        sourceMemoryIds: [],
        sourceDocumentIds: items.map((item) => item.id),
        metadata: {
          providerKey: lead.providerKey || null,
          sourceAccount: lead.sourceAccount || null,
          itemCount: items.length,
        },
      });
    }

    const recentTimeline = [...documents]
      .sort((left, right) => String(right.updatedAt || '').localeCompare(String(left.updatedAt || '')))
      .slice(0, 8);
    if (recentTimeline.length > 0) {
      views.push({
        viewType: 'timeline',
        subjectKey: 'recent',
        title: 'Recent knowledge changes',
        summary: recentTimeline.map((item) => `${item.title || item.normalizedType}: ${item.summary || item.content}`).join(' | ').slice(0, 320),
        markdownText: `# Recent knowledge changes\n\n${recentTimeline.map((item) => `- ${item.title || item.normalizedType}: ${item.summary || item.content}`).join('\n')}`,
        sourceMemoryIds: [],
        sourceDocumentIds: recentTimeline.map((item) => item.id),
        metadata: {
          itemCount: recentTimeline.length,
        },
      });
    }

    const projectMemories = memories.filter((memory) => memory.category === 'projects');
    for (const memory of projectMemories.slice(0, 12)) {
      views.push({
        viewType: 'project',
        subjectKey: memory.id,
        title: memory.content.split(/[.!?\n]/)[0].slice(0, 120) || 'Project',
        summary: memory.content.slice(0, 320),
        markdownText: `# ${memory.content.split(/[.!?\n]/)[0].slice(0, 120) || 'Project'}\n\n${memory.content}`,
        sourceMemoryIds: [memory.id],
        sourceDocumentIds: [],
        metadata: {
          importance: memory.importance,
        },
      });
    }

    const personMemories = memories.filter((memory) => ['contacts', 'identity'].includes(memory.category));
    for (const memory of personMemories.slice(0, 12)) {
      views.push({
        viewType: 'person',
        subjectKey: memory.id,
        title: memory.content.split(/[.!?\n]/)[0].slice(0, 120) || 'Person',
        summary: memory.content.slice(0, 320),
        markdownText: `# ${memory.content.split(/[.!?\n]/)[0].slice(0, 120) || 'Person'}\n\n${memory.content}`,
        sourceMemoryIds: [memory.id],
        sourceDocumentIds: [],
        metadata: {
          category: memory.category,
        },
      });
    }

    for (const view of views) {
      const existing = db.prepare(
        `SELECT id FROM materialized_knowledge_views
         WHERE user_id = ? AND agent_id = ? AND view_type = ? AND subject_key = ?`
      ).get(userId, scopedAgentId, view.viewType, view.subjectKey);
      const viewId = existing?.id || uuidv4();
      db.prepare(
        `INSERT INTO materialized_knowledge_views (
          id, user_id, agent_id, view_type, subject_key, title, summary, markdown_text,
          source_memory_ids_json, source_document_ids_json, metadata_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          summary = excluded.summary,
          markdown_text = excluded.markdown_text,
          source_memory_ids_json = excluded.source_memory_ids_json,
          source_document_ids_json = excluded.source_document_ids_json,
          metadata_json = excluded.metadata_json,
          updated_at = excluded.updated_at`
      ).run(
        viewId,
        userId,
        scopedAgentId,
        view.viewType,
        view.subjectKey,
        view.title,
        view.summary,
        view.markdownText,
        JSON.stringify(normalizeStringArray(view.sourceMemoryIds, 48, 64)),
        JSON.stringify(normalizeStringArray(view.sourceDocumentIds, 48, 64)),
        JSON.stringify(parseJsonObject(view.metadata, {})),
      );
    }

    return this.listKnowledgeViews(userId, { agentId: scopedAgentId, limit: 64 });
  }

  listKnowledgeViews(userId, { agentId = null, viewType = null, limit = 40 } = {}) {
    const scopedAgentId = this._agentId(userId, { agentId });
    let sql = `SELECT *
               FROM materialized_knowledge_views
               WHERE user_id = ? AND agent_id = ?`;
    const params = [userId, scopedAgentId];
    if (viewType) {
      sql += ' AND view_type = ?';
      params.push(String(viewType).trim());
    }
    sql += ' ORDER BY updated_at DESC LIMIT ?';
    params.push(Math.max(1, Math.min(Number(limit) || 40, 100)));
    return db.prepare(sql).all(...params).map((row) => ({
      id: row.id,
      viewType: row.view_type,
      subjectKey: row.subject_key,
      title: row.title,
      summary: row.summary || '',
      markdownText: row.markdown_text || '',
      sourceMemoryIds: normalizeStringArray(parseJsonArray(row.source_memory_ids_json)),
      sourceDocumentIds: normalizeStringArray(parseJsonArray(row.source_document_ids_json)),
      metadata: parseJsonObject(row.metadata_json, {}),
      updatedAt: row.updated_at || null,
    }));
  }

  listRecentKnowledgeChanges(userId, { agentId = null, limit = 8 } = {}) {
    const docs = this.listIngestionDocuments(userId, { agentId, limit });
    const views = this.listKnowledgeViews(userId, { agentId, limit });
    const changes = [
      ...docs.map((doc) => ({
        kind: 'document',
        id: doc.id,
        title: doc.title || doc.normalizedType,
        summary: doc.summary || doc.content,
        sourceType: doc.sourceType,
        providerKey: doc.providerKey,
        updatedAt: doc.updatedAt,
      })),
      ...views.map((view) => ({
        kind: 'view',
        id: view.id,
        title: view.title,
        summary: view.summary,
        sourceType: view.viewType,
        providerKey: view.metadata?.providerKey || null,
        updatedAt: view.updatedAt,
      })),
    ];
    return changes
      .sort((left, right) => String(right.updatedAt || '').localeCompare(String(left.updatedAt || '')))
      .slice(0, Math.max(1, Math.min(Number(limit) || 8, 24)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Semantic Memories (SQLite + embeddings)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Save a new memory. Deduplicates if an existing memory is very similar.
   * Returns the memory id (new or existing).
   */
  async saveMemory(userId, content, category = 'episodic', importance = 5, options = {}) {
    const agentId = this._agentId(userId, options);
    const decision = getMemoryStorageDecision(content);
    if (!decision.allow) return null;
    content = decision.normalized;
    category = normalizeMemoryCategory(category);
    importance = Math.max(1, Math.min(10, Number(importance) || 5));
    const scope = normalizeScope(options.scope, agentId);
    const sourceRef = normalizeSourceRef(options.sourceRef);
    const staleAfterDays = Number.isFinite(Number(options.staleAfterDays))
      ? Math.max(1, Number(options.staleAfterDays))
      : null;
    const metadata = parseJsonObject(options.metadata, {});

    const embedding = await getEmbedding(content, await getActiveProvider(userId, agentId));

    // Dedup check: compare against existing non-archived memories in the same scope
    const existing = db.prepare(
      `SELECT id, content, embedding, metadata_json
       FROM memories
       WHERE user_id = ? AND agent_id = ? AND archived = 0
         AND COALESCE(scope_type, 'agent') = ?
         AND COALESCE(scope_id, '') = COALESCE(?, '')`
    ).all(userId, agentId, scope.scopeType, scope.scopeId);

    for (const mem of existing) {
      let sim = 0;
      if (embedding && mem.embedding) {
        const memVec = deserializeEmbedding(mem.embedding);
        if (memVec) sim = cosineSimilarity(embedding, memVec);
      } else {
        sim = keywordSimilarity(content, mem.content);
      }

      if (sim > 0.85) {
        // Very similar — update in place if new content is longer, otherwise skip
        if (content.length > mem.content.length) {
          const mergedMetadata = {
            ...parseJsonObject(mem.metadata_json, {}),
            ...metadata,
          };
          db.prepare(
            `UPDATE memories SET content = ?, importance = MAX(importance, ?), embedding = ?,
             source_type = COALESCE(?, source_type), source_id = COALESCE(?, source_id),
             source_label = COALESCE(?, source_label), stale_after_days = COALESCE(?, stale_after_days),
             metadata_json = ?,
             updated_at = datetime('now') WHERE id = ?`
          ).run(
            content,
            importance,
            embedding ? serializeEmbedding(embedding) : mem.embedding,
            sourceRef.sourceType,
            sourceRef.sourceId,
            sourceRef.sourceLabel,
            staleAfterDays,
            JSON.stringify(mergedMetadata),
            mem.id,
          );
          return mem.id;
        }
        return mem.id; // already covered, skip
      }
    }

    // Save new
    const id = uuidv4();
    db.prepare(
      `INSERT INTO memories (
        id, user_id, agent_id, category, scope_type, scope_id, source_type, source_id, source_label,
        stale_after_days, metadata_json, content, importance, embedding
      )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      id,
      userId,
      agentId,
      category,
      scope.scopeType,
      scope.scopeId,
      sourceRef.sourceType,
      sourceRef.sourceId,
      sourceRef.sourceLabel,
      staleAfterDays,
      JSON.stringify(metadata),
      content,
      importance,
      embedding ? serializeEmbedding(embedding) : null,
    );

    return id;
  }

  /**
   * Semantic search over memories. Returns top-K most relevant.
   * Falls back to keyword search if embeddings unavailable.
   */
  async recallMemory(userId, query, topK = 6, options = {}) {
    if (!query || !query.trim()) return [];
    const agentId = this._agentId(userId, options);
    const scope = normalizeScope(options.scope, agentId);

    const all = db.prepare(
      `SELECT id, category, content, importance, embedding, access_count, created_at, updated_at,
              scope_type, scope_id, source_type, source_id, source_label, stale_after_days, metadata_json
       FROM memories
       WHERE user_id = ? AND agent_id = ? AND archived = 0
         AND (
           (COALESCE(scope_type, 'agent') = ? AND COALESCE(scope_id, '') = COALESCE(?, ''))
           OR COALESCE(scope_type, 'agent') = 'shared'
         )
       ORDER BY updated_at DESC`
    ).all(userId, agentId, scope.scopeType, scope.scopeId);

    if (!all.length) return [];

    const queryVec = await getEmbedding(query, await getActiveProvider(userId, agentId));

    const scored = all.map(mem => {
      let score = 0;
      if (queryVec && mem.embedding) {
        const memVec = deserializeEmbedding(mem.embedding);
        if (memVec) {
          score = cosineSimilarity(queryVec, memVec);
          // Boost by importance (1–10 → up to +50% weight)
          score = score * (0.5 + mem.importance / 20);
        }
      }
      const lexicalScore = keywordSimilarity(query, mem.content) * 0.7;
      score = Math.max(score, lexicalScore);
      score *= computeFreshnessMultiplier(mem);
      return { ...mem, score };
    });

    const results = scored
      .filter(m => m.score > 0.2)
      .sort((a, b) => b.score - a.score)
      .slice(0, topK);

    // Update access counts
    if (results.length) {
      const ids = results.map(r => r.id);
      const placeholders = ids.map(() => '?').join(',');
      db.prepare(`UPDATE memories SET access_count = access_count + 1 WHERE id IN (${placeholders})`).run(...ids);
    }

    return results.map((row) => ({
      ...serializeMemoryRow(row),
      score: row.score,
    }));
  }

  /**
   * List memories (for UI). Supports category filter + pagination.
   */
  listMemories(userId, { category, limit = 50, offset = 0, includeArchived = false, agentId = null } = {}) {
    const scopedAgentId = this._agentId(userId, { agentId });
    let sql = `SELECT id, category, content, importance, access_count, archived, created_at, updated_at,
                      scope_type, scope_id, source_type, source_id, source_label, stale_after_days, metadata_json
               FROM memories WHERE user_id = ? AND agent_id = ? AND archived = ?`;
    const params = [userId, scopedAgentId, includeArchived ? 1 : 0];
    if (category && !CATEGORIES.includes(category)) {
      category = 'episodic';
    }
    if (category) {
      sql += ` AND category = ?`;
      params.push(normalizeMemoryCategory(category));
    }
    sql += ` ORDER BY importance DESC, updated_at DESC LIMIT ? OFFSET ?`;
    params.push(limit, offset);
    return db.prepare(sql).all(...params).map(serializeMemoryRow);
  }

  /**
   * Update a memory's content and/or importance.
   */
  async updateMemory(id, { content, importance, category }) {
    const mem = db.prepare(`SELECT * FROM memories WHERE id = ?`).get(id);
    if (!mem) return null;

    const newContent = content ?? mem.content;
    const newImportance = importance != null ? Math.max(1, Math.min(10, Number(importance))) : mem.importance;
    const newCategory = category ? normalizeMemoryCategory(category) : mem.category;

    let newEmbed = mem.embedding;
    if (content && content !== mem.content) {
      const vec = await getEmbedding(newContent, await getActiveProvider(null));
      newEmbed = vec ? serializeEmbedding(vec) : mem.embedding;
    }

    db.prepare(
      `UPDATE memories SET content = ?, importance = ?, category = ?, embedding = ?,
       updated_at = datetime('now') WHERE id = ?`
    ).run(newContent, newImportance, newCategory, newEmbed, id);

    return serializeMemoryRow(db.prepare(
      `SELECT * FROM memories WHERE id = ?`
    ).get(id));
  }

  /**
   * Delete a memory permanently.
   */
  deleteMemory(id) {
    return this.deleteMemories([id]) > 0;
  }

  deleteMemories(ids, userId = null) {
    const uniqueIds = [...new Set(
      (Array.isArray(ids) ? ids : [])
        .map((id) => String(id || '').trim())
        .filter(Boolean)
    )];
    if (!uniqueIds.length) return 0;
    const placeholders = uniqueIds.map(() => '?').join(', ');
    const result = userId != null
      ? db.prepare(`DELETE FROM memories WHERE id IN (${placeholders}) AND user_id = ?`).run(...uniqueIds, userId)
      : db.prepare(`DELETE FROM memories WHERE id IN (${placeholders})`).run(...uniqueIds);
    return result.changes || 0;
  }

  /**
   * Archive / un-archive a memory.
   */
  archiveMemory(id, archived = true) {
    return this.archiveMemories([id], archived) > 0;
  }

  archiveMemories(ids, archived = true, userId = null) {
    const uniqueIds = [...new Set(
      (Array.isArray(ids) ? ids : [])
        .map((id) => String(id || '').trim())
        .filter(Boolean)
    )];
    if (!uniqueIds.length) return 0;
    const placeholders = uniqueIds.map(() => '?').join(', ');
    const result = userId != null
      ? db.prepare(
          `UPDATE memories SET archived = ? WHERE id IN (${placeholders}) AND user_id = ?`
        ).run(archived ? 1 : 0, ...uniqueIds, userId)
      : db.prepare(
          `UPDATE memories SET archived = ? WHERE id IN (${placeholders})`
        ).run(archived ? 1 : 0, ...uniqueIds);
    return result.changes || 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core Memory (always-injected key-value pairs)
  // ─────────────────────────────────────────────────────────────────────────

  getCoreMemory(userId, options = {}) {
    const agentId = this._agentId(userId, options);
    const rows = db.prepare(`SELECT key, value FROM core_memory WHERE user_id = ? AND agent_id = ?`).all(userId, agentId);
    const result = {};
    for (const row of rows) {
      try { result[row.key] = JSON.parse(row.value); } catch { result[row.key] = row.value; }
    }
    return result;
  }

  updateCore(userId, key, value, options = {}) {
    const agentId = this._agentId(userId, options);
    const strVal = typeof value === 'object' ? JSON.stringify(value) : String(value);
    db.prepare(
      `INSERT INTO core_memory (user_id, agent_id, key, value, updated_at)
       VALUES (?, ?, ?, ?, datetime('now'))
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`
    ).run(userId, agentId, key, strVal);
  }

  deleteCore(userId, key, options = {}) {
    const agentId = this._agentId(userId, options);
    db.prepare(`DELETE FROM core_memory WHERE user_id = ? AND agent_id = ? AND key = ?`).run(userId, agentId, key);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Conversation State
  // ─────────────────────────────────────────────────────────────────────────

  ensureConversation(userId, {
    platform = 'web',
    platformChatId = null,
    title = 'Conversation',
    sessionKey = null,
    agentId = null,
  } = {}) {
    const scopedAgentId = this._agentId(userId, { agentId });
    const existing = db.prepare(
      'SELECT id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND COALESCE(platform_chat_id, \'\') = COALESCE(?, \'\')'
    ).get(userId, scopedAgentId, platform, platformChatId);

    if (existing?.id) return existing.id;

    const conversationId = uuidv4();
    let migratedSummary = '';
    if (platform === 'web') {
      const agent = db.prepare('SELECT slug FROM agents WHERE user_id = ? AND id = ?')
        .get(userId, scopedAgentId);
      if (agent?.slug === 'main') {
        const legacySummary = db.prepare(
          'SELECT value FROM user_settings WHERE user_id = ? AND key = ?'
        ).get(userId, 'web_chat_summary');
        migratedSummary = typeof legacySummary?.value === 'string'
          ? (() => {
              try { return JSON.parse(legacySummary.value); } catch { return legacySummary.value; }
            })()
          : '';
      }
    }

    db.prepare(
      `INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title, session_key, summary, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`
    ).run(
      conversationId,
      userId,
      scopedAgentId,
      platform,
      platformChatId,
      title,
      sessionKey,
      migratedSummary || null
    );

    return conversationId;
  }

  getDefaultWebConversationId(userId, options = {}) {
    const agentId = this._agentId(userId, options);
    return this.ensureConversation(userId, {
      platform: 'web',
      platformChatId: 'primary',
      title: 'Web chat',
      sessionKey: 'web:primary',
      agentId,
    });
  }

  getConversationState(conversationId) {
    const row = db.prepare(
      'SELECT working_state_json, last_verified_facts_json FROM conversations WHERE id = ?'
    ).get(conversationId);

    let workingState = null;
    let lastVerifiedFacts = [];
    try {
      workingState = row?.working_state_json ? JSON.parse(row.working_state_json) : null;
    } catch {
      workingState = null;
    }
    try {
      lastVerifiedFacts = row?.last_verified_facts_json ? JSON.parse(row.last_verified_facts_json) : [];
    } catch {
      lastVerifiedFacts = [];
    }

    return {
      ...(workingState && typeof workingState === 'object' ? workingState : {}),
      last_verified_facts: Array.isArray(lastVerifiedFacts) ? lastVerifiedFacts : [],
    };
  }

  updateConversationState(conversationId, state = {}) {
    const payload = state && typeof state === 'object' && !Array.isArray(state) ? state : {};
    const verifiedFacts = Array.isArray(payload.last_verified_facts) ? payload.last_verified_facts : [];

    db.prepare(
      `UPDATE conversations
       SET working_state_json = ?, last_verified_facts_json = ?, updated_at = datetime('now')
       WHERE id = ?`
    ).run(
      JSON.stringify(payload),
      JSON.stringify(verifiedFacts),
      conversationId
    );
  }

  buildConversationStateMessage(conversationId) {
    if (!conversationId) return null;
    const state = this.getConversationState(conversationId);
    if (!state || Object.keys(state).length === 0) return null;

    const sections = [];
    if (state.summary) sections.push(`Summary: ${state.summary}`);
    if (Array.isArray(state.open_commitments) && state.open_commitments.length) {
      sections.push(`Open commitments:\n- ${state.open_commitments.join('\n- ')}`);
    }
    if (Array.isArray(state.unresolved_questions) && state.unresolved_questions.length) {
      sections.push(`Unresolved questions:\n- ${state.unresolved_questions.join('\n- ')}`);
    }
    if (Array.isArray(state.referenced_entities) && state.referenced_entities.length) {
      sections.push(`Referenced entities: ${state.referenced_entities.join(', ')}`);
    }
    if (Array.isArray(state.last_verified_facts) && state.last_verified_facts.length) {
      sections.push(`Last verified facts:\n- ${state.last_verified_facts.join('\n- ')}`);
    }

    if (sections.length === 0) return null;
    return `[Thread working state]\n${sections.join('\n\n')}`;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API_KEYS.json
  // ─────────────────────────────────────────────────────────────────────────

  readApiKeys(userId = null) {
    const filePath = this._userApiKeysPath(userId);
    if (!fs.existsSync(filePath)) {
      if (userId != null && fs.existsSync(SHARED_API_KEYS_FILE)) {
        fs.copyFileSync(SHARED_API_KEYS_FILE, filePath);
      } else {
        return {};
      }
    }
    try {
      const parsed = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return {};
      }

      let shouldMigrate = false;
      const normalized = {};

      for (const [service, rawValue] of Object.entries(parsed)) {
        const value = String(rawValue || '');
        if (!value) {
          normalized[service] = '';
          continue;
        }

        if (!isLocalEncryptedValue(value)) shouldMigrate = true;
        normalized[service] = decryptLocalValue(value);
      }

      if (shouldMigrate) {
        this.writeApiKeys(normalized, userId);
      }

      return normalized;
    } catch {
      return {};
    }
  }

  writeApiKeys(keys, userId = null) {
    const encrypted = {};
    for (const [service, rawValue] of Object.entries(keys || {})) {
      const value = String(rawValue || '');
      encrypted[service] = value ? encryptLocalValue(value) : '';
    }
    fs.writeFileSync(this._userApiKeysPath(userId), JSON.stringify(encrypted, null, 2), 'utf-8');
  }

  setApiKey(service, key, userId = null) {
    const keys = this.readApiKeys(userId);
    keys[service] = key;
    this.writeApiKeys(keys, userId);
  }

  getApiKey(service, userId = null) {
    return this.readApiKeys(userId)[service] || null;
  }

  deleteApiKey(service, userId = null) {
    const keys = this.readApiKeys(userId);
    delete keys[service];
    this.writeApiKeys(keys, userId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Daily Logs
  // ─────────────────────────────────────────────────────────────────────────

  _dailyPath(date, userId = null) {
    const d = date ? (date instanceof Date ? date : new Date(date)) : new Date();
    const name = d.toISOString().split('T')[0] + '.md';
    return path.join(this._userDailyDir(userId), name);
  }

  readDailyLog(date, userId = null) {
    const fp = this._dailyPath(date, userId);
    if (!fs.existsSync(fp)) return '';
    return fs.readFileSync(fp, 'utf-8');
  }

  appendDailyLog(entry, date, userId = null) {
    const fp = this._dailyPath(date, userId);
    const timestamp = new Date().toLocaleTimeString('en-US', { hour12: false });
    const line = `\n- [${timestamp}] ${entry}`;
    fs.appendFileSync(fp, line, 'utf-8');
    return line.trim();
  }

  listDailyLogs(limit = 7, userId = null) {
    const dailyDir = this._userDailyDir(userId);
    if (userId != null && fs.existsSync(SHARED_DAILY_DIR) && (!fs.existsSync(dailyDir) || fs.readdirSync(dailyDir).length === 0)) {
      for (const entry of fs.readdirSync(SHARED_DAILY_DIR)) {
        if (!entry.endsWith('.md')) continue;
        const dest = path.join(dailyDir, entry);
        if (!fs.existsSync(dest)) {
          fs.copyFileSync(path.join(SHARED_DAILY_DIR, entry), dest);
        }
      }
    }
    if (!fs.existsSync(dailyDir)) return [];
    return fs.readdirSync(dailyDir)
      .filter(f => f.endsWith('.md'))
      .sort().reverse().slice(0, limit)
      .map(f => ({
        date: f.replace('.md', ''),
        content: fs.readFileSync(path.join(dailyDir, f), 'utf-8')
      }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Conversation History (DB-backed)
  // ─────────────────────────────────────────────────────────────────────────

  saveConversation(userId, agentRunId, role, content, metadata = {}) {
    const agentId = this._agentId(userId, metadata);
    db.prepare('INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)')
      .run(userId, agentId, agentRunId, role, content, JSON.stringify(metadata));
  }

  getConversation(agentRunId, limit = 100) {
    return db.prepare('SELECT * FROM conversation_history WHERE agent_run_id = ? ORDER BY created_at ASC LIMIT ?')
      .all(agentRunId, limit);
  }

  getRecentConversations(userId, limit = 20, options = {}) {
    const agentId = this._agentId(userId, options);
    const rows = db.prepare(`
      SELECT
        c.id,
        c.title,
        c.platform,
        c.platform_chat_id,
        c.summary,
        c.working_state_json,
        c.updated_at,
        (
          SELECT content
          FROM conversation_messages cm
          WHERE cm.conversation_id = c.id
          ORDER BY cm.created_at DESC, cm.id DESC
          LIMIT 1
        ) AS latest_content
      FROM conversations c
      WHERE c.user_id = ? AND c.agent_id = ?
      ORDER BY datetime(c.updated_at) DESC
      LIMIT ?
    `).all(userId, agentId, limit);

    if (rows.length === 0) {
      const fallback = db.prepare(`
        SELECT
          ar.id AS run_id,
          ar.title,
          ar.created_at,
          ar.completed_at,
          ar.status,
          (
            SELECT content
            FROM conversation_history ch
            WHERE ch.agent_run_id = ar.id
            ORDER BY ch.created_at DESC
            LIMIT 1
          ) AS latest_content
        FROM agent_runs ar
        WHERE ar.user_id = ? AND ar.agent_id = ?
        ORDER BY COALESCE(ar.completed_at, ar.created_at) DESC
        LIMIT ?
      `).all(userId, agentId, limit);

      return fallback.map((row) => {
        const summary = buildExcerpt(row.latest_content, '') || 'No summary available.';
        return {
          id: row.run_id,
          title: row.title || 'web conversation',
          platform: 'web',
          platformChatId: null,
          updatedAt: row.completed_at || row.created_at,
          summary,
          preview: summary,
        };
      });
    }

    return rows.map((row) => {
      let workingState = null;
      try {
        workingState = row.working_state_json ? JSON.parse(row.working_state_json) : null;
      } catch {
        workingState = null;
      }

      const summary = row.summary
        || workingState?.summary
        || buildExcerpt(row.latest_content, '');

      return {
        id: row.id,
        title: row.title || `${row.platform || 'chat'} conversation`,
        platform: row.platform || 'web',
        platformChatId: row.platform_chat_id || null,
        updatedAt: row.updated_at,
        summary: summary || 'No summary available.',
        preview: summary || 'No summary available.',
      };
    });
  }

  searchConversations(userId, query, options = {}) {
    const agentId = this._agentId(userId, options);
    const ftsQuery = buildFtsQuery(query);
    const maxHits = Math.max(6, Math.min(Number(options.limit) || 24, 60));
    if (!ftsQuery) return [];

    let webHits = [];
    let messageHits = [];
    try {
      webHits = db.prepare(`
        SELECT
          'web' AS source,
          ch.id AS message_id,
          COALESCE(ch.agent_run_id, 'web:' || ch.id) AS session_id,
          COALESCE(ar.title, 'Web chat') AS title,
          ch.role,
          ch.created_at,
          snippet(conversation_history_fts, 0, '<mark>', '</mark>', ' ... ', 16) AS snippet,
          bm25(conversation_history_fts) AS score
        FROM conversation_history_fts
        JOIN conversation_history ch ON ch.id = conversation_history_fts.rowid
        LEFT JOIN agent_runs ar ON ar.id = ch.agent_run_id
        WHERE conversation_history_fts MATCH ? AND ch.user_id = ? AND ch.agent_id = ?
        ORDER BY score
        LIMIT ?
      `).all(ftsQuery, userId, agentId, maxHits);

      messageHits = db.prepare(`
        SELECT
          'message' AS source,
          m.id AS message_id,
          COALESCE(m.run_id, m.platform || ':' || COALESCE(m.platform_chat_id, m.id)) AS session_id,
          COALESCE(ar.title, json_extract(m.metadata, '$.senderName'), m.platform_chat_id, m.platform, 'Message thread') AS title,
          m.role,
          m.created_at,
          m.platform,
          snippet(messages_fts, 0, '<mark>', '</mark>', ' ... ', 16) AS snippet,
          bm25(messages_fts) AS score
        FROM messages_fts
        JOIN messages m ON m.id = messages_fts.rowid
        LEFT JOIN agent_runs ar ON ar.id = m.run_id
        WHERE messages_fts MATCH ? AND m.user_id = ? AND m.agent_id = ?
        ORDER BY score
        LIMIT ?
      `).all(ftsQuery, userId, agentId, maxHits);
    } catch {
      const likeQuery = `%${String(query || '').trim()}%`;
      webHits = db.prepare(`
        SELECT
          'web' AS source,
          ch.id AS message_id,
          COALESCE(ch.agent_run_id, 'web:' || ch.id) AS session_id,
          COALESCE(ar.title, 'Web chat') AS title,
          ch.role,
          ch.created_at,
          ch.content AS snippet,
          0 AS score
        FROM conversation_history ch
        LEFT JOIN agent_runs ar ON ar.id = ch.agent_run_id
        WHERE ch.user_id = ? AND ch.agent_id = ? AND ch.content LIKE ?
        ORDER BY ch.created_at DESC
        LIMIT ?
      `).all(userId, agentId, likeQuery, maxHits);

      messageHits = db.prepare(`
        SELECT
          'message' AS source,
          m.id AS message_id,
          COALESCE(m.run_id, m.platform || ':' || COALESCE(m.platform_chat_id, m.id)) AS session_id,
          COALESCE(ar.title, json_extract(m.metadata, '$.senderName'), m.platform_chat_id, m.platform, 'Message thread') AS title,
          m.role,
          m.created_at,
          m.platform,
          m.content AS snippet,
          0 AS score
        FROM messages m
        LEFT JOIN agent_runs ar ON ar.id = m.run_id
        WHERE m.user_id = ? AND m.agent_id = ? AND m.content LIKE ?
        ORDER BY m.created_at DESC
        LIMIT ?
      `).all(userId, agentId, likeQuery, maxHits);
    }

    const grouped = new Map();
    for (const hit of [...webHits, ...messageHits]) {
      const key = `${hit.source}:${hit.session_id}`;
      if (!grouped.has(key)) {
        grouped.set(key, {
          sessionId: hit.session_id,
          source: hit.source,
          title: hit.title || 'Untitled session',
          platform: hit.platform || 'web',
          createdAt: hit.created_at,
          score: Number(hit.score || 0),
          matches: []
        });
      }

      const group = grouped.get(key);
      group.score = Math.min(group.score, Number(hit.score || 0));
      group.createdAt = hit.created_at > group.createdAt ? hit.created_at : group.createdAt;
      if (group.matches.length < 3) {
        group.matches.push({
          role: hit.role,
          createdAt: hit.created_at,
          excerpt: buildExcerpt(hit.snippet, query)
        });
      }
    }

    return Array.from(grouped.values())
      .sort((a, b) => a.score - b.score || String(b.createdAt).localeCompare(String(a.createdAt)))
      .slice(0, Math.max(1, Math.min(Number(options.sessions) || 8, 12)))
      .map((session) => ({
        ...session,
        matchCount: session.matches.length,
        summary: session.matches.map((match) => `${match.role}: ${match.excerpt}`).join('\n')
      }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Generic write/read (used by engine.js legacy paths)
  // ─────────────────────────────────────────────────────────────────────────

  write(target, content, mode = 'append', userId = null) {
    switch (target) {
      case 'daily':
        return { line: this.appendDailyLog(content, undefined, userId), target: 'daily' };
      case 'api_keys':
        try {
          const parsed = JSON.parse(content);
          for (const [k, v] of Object.entries(parsed)) this.setApiKey(k, v, userId);
          return { success: true, target: 'api_keys' };
        } catch {
          return { error: 'Invalid JSON for api_keys' };
        }
      default:
        return { error: `Unknown target: ${target}` };
    }
  }

  read(target, options = {}) {
    const userId = options.userId ?? null;
    switch (target) {
      case 'daily':
        return { content: this.readDailyLog(options.date ? new Date(options.date) : undefined, userId) };
      case 'all_daily':
        return { logs: this.listDailyLogs(7, userId) };
      case 'api_keys':
        return { keys: Object.keys(this.readApiKeys(userId)) };
      default:
        return { error: `Unknown target: ${target}` };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Context Builder — async, takes (userId, query) for semantic recall
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Build the static system-prompt context: assistant behavior notes + core memory.
   * No dynamic data (logs, recalled memories) — those are injected as
   * messages at the right position in the messages array by the engine.
   */
  async buildContext(userId = null, options = {}) {
    let ctx = '';
    const agentId = this._agentId(userId, options);

    const behaviorNotes = this.getAssistantBehaviorNotes(userId, { agentId });
    if (behaviorNotes) {
      ctx += `## Assistant Behavior Notes\n`;
      ctx += `These are durable preferences for how the assistant should usually behave. Follow system rules and the active user request first.\n`;
      ctx += `${behaviorNotes}\n\n`;
    }

    if (userId != null) {
      const selfState = this.getAssistantSelfState(userId, { agentId });
      if (Object.keys(selfState.identity || {}).length || Object.keys(selfState.focus || {}).length) {
        ctx += `## Assistant Self State\n`;
        if (Object.keys(selfState.identity || {}).length) {
          ctx += `Identity: ${JSON.stringify(selfState.identity)}\n`;
        }
        if (Object.keys(selfState.focus || {}).length) {
          ctx += `Focus: ${JSON.stringify(selfState.focus)}\n`;
        }
        ctx += '\n';
      }
    }

    // 2. Core memory — always-relevant user facts
    if (userId != null) {
      const core = this.getCoreMemory(userId, { agentId });
      const filteredCore = Object.fromEntries(
        Object.entries(core).filter(([key]) => key !== 'active_context')
      );
      if (Object.keys(filteredCore).length > 0) {
        ctx += `## Core Memory\n`;
        for (const [key, val] of Object.entries(filteredCore)) {
          const display = typeof val === 'object' ? JSON.stringify(val, null, 2) : val;
          ctx += `**${key}**: ${display}\n`;
        }
        ctx += '\n';
      }
    }

    return ctx;
  }

  /**
   * Returns a recalled-memory block string for a given query,
   * to be injected as a system message in the messages array.
   * Returns null if nothing relevant found.
   */
  async buildRecallMessage(userId, query, options = {}) {
    if (!userId || !query || !query.trim()) return null;
    try {
      const agentId = this._agentId(userId, options);
      const sections = [];
      const recalled = await this.recallMemory(userId, query, 5, { agentId });
      if (recalled.length) {
        const memoryLines = recalled.map(m => {
          const badge = m.category !== 'episodic' ? ` [${m.category}]` : '';
          return `- ${m.content}${badge}`;
        });
        sections.push(`Relevant memory:\n${memoryLines.join('\n')}`);
      }

      const queryTokens = tokenizeRecallQuery(query);
      if (queryTokens.length) {
        const recentTaskRuns = db.prepare(
          `SELECT title, final_response, completed_at
           FROM agent_runs
           WHERE user_id = ? AND agent_id = ? AND trigger_source IN ('schedule', 'tasks') AND status = 'completed'
           ORDER BY completed_at DESC, created_at DESC
           LIMIT 12`
        ).all(userId, agentId);

        const taskMatches = recentTaskRuns
          .map((run) => ({
            ...run,
            score: scoreSchedulerRunMatch(queryTokens, run.title, run.final_response),
          }))
          .filter((run) => run.score > 0)
          .slice(0, 3);

        if (taskMatches.length) {
          const taskLines = taskMatches.map((run) => {
            const when = run.completed_at ? String(run.completed_at) : 'unknown time';
            const title = String(run.title || 'task').replace(/\s+/g, ' ').trim();
            const outcome = buildExcerpt(String(run.final_response || ''), query) || String(run.final_response || '').slice(0, 180);
            return `- ${when}: ${title} -> ${outcome || '(no final response stored)'}`;
          });
          sections.push(`Relevant recent task runs:\n${taskLines.join('\n')}`);
        }
      }

      if (!sections.length) return null;
      return `[Recalled context — relevant background for the current message]\n${sections.join('\n\n')}`;
    } catch {
      return null;
    }
  }

  readMemory(userId = null) {
    return this.read('all_daily', { userId });
  }

  searchMemory(query, userId = null, options = {}) {
    return this.recallMemory(userId, query, 6, options);
  }
}

module.exports = { MemoryManager, CATEGORIES, CORE_KEYS };
