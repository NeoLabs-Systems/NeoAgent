'use strict';

const db = require('../../db/database');

const DEFAULT_FEED_LIMIT = 50;
const MAX_FEED_LIMIT = 200;
const DEFAULT_PROMPT_CONTEXT_LIMIT = 6;
const MAX_PROMPT_CONTEXT_LIMIT = 12;

function parseJson(value, fallback = {}) {
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

function safeJson(value) {
  try {
    return JSON.stringify(value || {});
  } catch {
    return '{}';
  }
}

function normalizeTimestamp(value, fallback = new Date().toISOString()) {
  const text = String(value || '').trim();
  if (!text) return fallback;
  const parsed = new Date(text);
  return Number.isFinite(parsed.getTime()) ? parsed.toISOString() : fallback;
}

function normalizeText(value, maxLength = 1000) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (!text) return '';
  return text.length > maxLength ? text.slice(0, maxLength) : text;
}

function queryTerms(value) {
  return Array.from(new Set(
    normalizeText(value, 240)
      .toLowerCase()
      .split(/[^a-z0-9]+/i)
      .map((term) => term.trim())
      .filter((term) => term.length >= 4)
  ));
}

function formatPromptTimestamp(value) {
  const parsed = new Date(String(value || ''));
  if (!Number.isFinite(parsed.getTime())) {
    return String(value || '').slice(0, 16);
  }
  return parsed.toISOString().slice(0, 16).replace('T', ' ');
}

function toFeedItem(row) {
  return {
    id: Number(row.id),
    sourceKind: String(row.source_kind || ''),
    eventKind: String(row.event_kind || ''),
    occurredAt: row.occurred_at,
    title: String(row.title || ''),
    summary: String(row.summary || ''),
    agentId: row.agent_id || null,
    sourceId: row.source_id || null,
    metadata: parseJson(row.metadata_json),
  };
}

class TimelineService {
  constructor(options = {}) {
    this.db = options.db || db;
    this.io = options.io || null;
  }

  _emitUpdated(userId) {
    if (!userId || !this.io?.to) return;
    this.io.to(`user:${userId}`).emit('timeline:updated', {
      timestamp: new Date().toISOString(),
    });
  }

  _insertEvent({
    userId,
    agentId = null,
    sourceKind,
    eventKind,
    occurredAt,
    title,
    summary = '',
    sourceId = null,
    groupKey = null,
    metadata = {},
  }) {
    const normalizedOccurredAt = normalizeTimestamp(occurredAt);
    const result = this.db.prepare(
      `INSERT INTO timeline_events (
         user_id, agent_id, source_kind, event_kind, occurred_at, title, summary, source_id, group_key, metadata_json
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      userId,
      agentId || null,
      String(sourceKind || '').trim(),
      String(eventKind || '').trim(),
      normalizedOccurredAt,
      normalizeText(title, 240),
      normalizeText(summary, 1000),
      sourceId == null ? null : String(sourceId),
      groupKey == null ? null : String(groupKey),
      safeJson(metadata),
    );
    const row = this.db.prepare(
      `SELECT id, user_id, agent_id, source_kind, event_kind, occurred_at, title, summary, source_id, group_key, metadata_json
       FROM timeline_events
       WHERE id = ?`
    ).get(result.lastInsertRowid);
    return row ? toFeedItem(row) : null;
  }

  listEvents(userId, options = {}) {
    const normalizedUserId = Number(userId);
    const limitRaw = Number.parseInt(options.limit, 10);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0
      ? Math.min(limitRaw, MAX_FEED_LIMIT)
      : DEFAULT_FEED_LIMIT;
    const beforeOccurredAt = String(options.beforeOccurredAt || '').trim();
    const beforeId = Number.parseInt(options.beforeId, 10);
    const agentId = String(options.agentId || '').trim();
    const sources = Array.isArray(options.sources)
      ? options.sources
          .map((value) => String(value || '').trim())
          .filter(Boolean)
      : [];

    const clauses = ['user_id = ?'];
    const params = [normalizedUserId];

    if (agentId) {
      clauses.push('agent_id = ?');
      params.push(agentId);
    }
    if (sources.length > 0) {
      clauses.push(`source_kind IN (${sources.map(() => '?').join(', ')})`);
      params.push(...sources);
    }
    if (beforeOccurredAt && Number.isFinite(beforeId) && beforeId > 0) {
      clauses.push('(occurred_at < ? OR (occurred_at = ? AND id < ?))');
      params.push(beforeOccurredAt, beforeOccurredAt, beforeId);
    }

    const rows = this.db.prepare(
      `SELECT id, user_id, agent_id, source_kind, event_kind, occurred_at, title, summary, source_id, group_key, metadata_json
       FROM timeline_events
       WHERE ${clauses.join(' AND ')}
       ORDER BY occurred_at DESC, id DESC
       LIMIT ?`
    ).all(...params, limit);
    return rows.map(toFeedItem);
  }

  buildPromptContext(userId, options = {}) {
    const limitRaw = Number.parseInt(options.limit, 10);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0
      ? Math.min(limitRaw, MAX_PROMPT_CONTEXT_LIMIT)
      : DEFAULT_PROMPT_CONTEXT_LIMIT;
    const sources = Array.isArray(options.sources) && options.sources.length > 0
      ? options.sources
      : ['screen', 'tasks', 'runs'];
    const query = String(options.query || '').trim();
    const preferAgentId = String(options.agentId || '').trim();
    const candidates = this.listEvents(userId, {
      limit: Math.max(limit * 3, limit),
      sources,
    });
    if (candidates.length === 0) {
      return '';
    }

    const terms = queryTerms(query);
    const scored = candidates.map((item, index) => {
      const metadata = item.metadata && typeof item.metadata === 'object'
        ? item.metadata
        : {};
      const haystack = [
        item.sourceKind,
        item.eventKind,
        item.title,
        item.summary,
        metadata.appName,
        metadata.windowTitle,
        metadata.deviceLabel,
        metadata.previewText,
        metadata.taskName,
      ].map((value) => normalizeText(value, 400).toLowerCase())
        .filter(Boolean)
        .join(' ');
      const matchCount = terms.reduce(
        (count, term) => count + (haystack.includes(term) ? 1 : 0),
        0,
      );
      const preferredAgent = preferAgentId && item.agentId === preferAgentId ? 1 : 0;
      return {
        item,
        index,
        score: matchCount + preferredAgent,
      };
    });

    const relevant = (terms.length > 0
      ? scored
          .sort((left, right) => (
            right.score - left.score
            || left.index - right.index
          ))
          .filter((entry) => entry.score > 0)
      : scored
    );
    const selectedEntries = (relevant.length > 0 ? relevant : scored)
      .slice(0, limit);
    const selected = selectedEntries
      .map((entry) => entry.item)
      .sort((left, right) => left.occurredAt.localeCompare(right.occurredAt));

    if (selected.length === 0) {
      return '';
    }

    const lines = selected.map((item) => this._formatPromptLine(item));
    return [
      'Recent timeline context (user-wide, recent activity only; use as soft situational context, not as authoritative proof):',
      ...lines,
    ].join('\n');
  }

  recordTaskLifecycle({
    userId,
    agentId = null,
    taskId,
    taskName,
    eventKind,
    occurredAt = null,
    runId = null,
    reason = null,
    error = null,
    triggerType = null,
    triggerSource = null,
  }) {
    const normalizedTaskId = Number.parseInt(taskId, 10);
    const normalizedName = normalizeText(taskName || `Task ${normalizedTaskId}`, 180)
      || `Task ${normalizedTaskId}`;
    const summary = normalizeText(error || reason || triggerType || '', 240);
    const item = this._insertEvent({
      userId,
      agentId,
      sourceKind: 'tasks',
      eventKind,
      occurredAt: occurredAt || new Date().toISOString(),
      title: normalizedName,
      summary,
      sourceId: Number.isFinite(normalizedTaskId) ? String(normalizedTaskId) : null,
      metadata: {
        taskId: Number.isFinite(normalizedTaskId) ? normalizedTaskId : null,
        taskName: normalizedName,
        runId: runId || null,
        reason: reason || null,
        error: error || null,
        triggerType: triggerType || null,
        triggerSource: triggerSource || null,
      },
    });
    this._emitUpdated(userId);
    return item;
  }

  recordRunLifecycle({
    userId,
    agentId = null,
    runId,
    title,
    eventKind,
    occurredAt = null,
    status = null,
    triggerSource = null,
    error = null,
  }) {
    const normalizedTitle = normalizeText(title || 'Untitled run', 180) || 'Untitled run';
    const summary = normalizeText(error || status || triggerSource || '', 240);
    const item = this._insertEvent({
      userId,
      agentId,
      sourceKind: 'runs',
      eventKind,
      occurredAt: occurredAt || new Date().toISOString(),
      title: normalizedTitle,
      summary,
      sourceId: runId ? String(runId) : null,
      metadata: {
        runId: runId || null,
        title: normalizedTitle,
        status: status || null,
        triggerSource: triggerSource || null,
        error: error || null,
      },
    });
    this._emitUpdated(userId);
    return item;
  }

  _formatPromptLine(item) {
    const metadata = item.metadata && typeof item.metadata === 'object'
      ? item.metadata
      : {};
    const when = formatPromptTimestamp(item.occurredAt);
    if (item.sourceKind === 'tasks') {
      const taskName = normalizeText(metadata.taskName || item.title, 120) || item.title;
      const runId = normalizeText(metadata.runId, 80);
      const summary = normalizeText(item.summary, 140);
      return `- [task ${when}] ${taskName} · ${item.eventKind}${runId ? ` · run ${runId}` : ''}${summary ? ` — ${summary}` : ''}`;
    }
    const runTitle = normalizeText(item.title, 120) || 'Untitled run';
    const summary = normalizeText(item.summary, 140);
    return `- [run ${when}] ${runTitle} · ${item.eventKind}${summary ? ` — ${summary}` : ''}`;
  }
}

module.exports = {
  TimelineService,
};
