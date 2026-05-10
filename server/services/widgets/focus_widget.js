'use strict';

const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');

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

function safeTrim(value, maxLength = 240) {
  return String(value || '').trim().slice(0, maxLength);
}

function formatRelativeTimestamp(value) {
  if (!value) return 'No recent activity';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return safeTrim(value, 80);
  return date.toISOString();
}

function buildAssistantFocusSnapshot(memoryManager, userId, agentId) {
  const scopedAgentId = resolveAgentId(userId, agentId);
  const selfState = memoryManager?.getAssistantSelfState?.(userId, { agentId: scopedAgentId }) || {
    identity: {},
    focus: {},
  };
  const tasks = db.prepare(
    `SELECT id, name, trigger_type, enabled, last_run
     FROM scheduled_tasks
     WHERE user_id = ? AND agent_id = ? AND enabled = 1 AND task_type != 'widget_refresh'
     ORDER BY COALESCE(last_run, created_at) DESC
     LIMIT 6`
  ).all(userId, scopedAgentId);
  const runs = db.prepare(
    `SELECT id, title, status, trigger_source, created_at, completed_at, error, metadata_json
     FROM agent_runs
     WHERE user_id = ? AND agent_id = ?
     ORDER BY created_at DESC
     LIMIT 6`
  ).all(userId, scopedAgentId);
  const conversations = memoryManager?.getRecentConversations?.(userId, 4, { agentId: scopedAgentId }) || [];
  const memories = memoryManager?.listMemories?.(userId, { limit: 6, agentId: scopedAgentId }) || [];

  const activeThreads = conversations.slice(0, 3).map((conversation) => ({
    title: safeTrim(conversation.title, 80),
    preview: safeTrim(conversation.preview || conversation.summary, 120),
    updatedAt: conversation.updatedAt || null,
  }));
  const nearTermPriorities = tasks.slice(0, 3).map((task) => ({
    label: safeTrim(task.name, 80),
    value: safeTrim(task.trigger_type === 'schedule' ? 'Scheduled' : 'Triggered', 40),
  }));
  const recentSignals = runs.slice(0, 3).map((run) => ({
    label: (() => {
      const metadata = parseJsonObject(run.metadata_json, {});
      return safeTrim(
        metadata.deliverable?.type
          ? `${run.title || 'Run'} (${metadata.deliverable.type})`
          : (run.title || 'Run'),
        80,
      );
    })(),
    value: safeTrim(run.status || 'unknown', 32),
  }));
  const rememberedContext = memories.slice(0, 2).map((memory) => safeTrim(memory.content, 140));

  const currentFocus = safeTrim(
    selfState.focus?.currentFocus
    || activeThreads[0]?.title
    || nearTermPriorities[0]?.label
    || 'Monitoring your active work',
    120,
  );

  return {
    currentFocus,
    activeThreads,
    nearTermPriorities,
    recentSignals,
    rememberedContext,
    assistantIdentity: {
      name: safeTrim(selfState.identity?.displayName, 80),
      style: safeTrim(selfState.identity?.style, 120),
    },
    generatedAt: new Date().toISOString(),
  };
}

function buildAssistantFocusWidgetPayload(snapshot) {
  const rows = [
    ...snapshot.nearTermPriorities,
    ...snapshot.recentSignals,
  ].slice(0, 3);
  const chips = [
    ...snapshot.activeThreads.map((item) => item.title),
    ...snapshot.rememberedContext,
  ].filter(Boolean).slice(0, 3);

  return {
    title: 'Today / Focus',
    kicker: 'Assistant state',
    subtitle: snapshot.currentFocus,
    body: snapshot.activeThreads[0]?.preview
      || snapshot.rememberedContext[0]
      || 'Watching recent conversations, tasks, and runs.',
    metric: String(snapshot.activeThreads.length),
    metricLabel: snapshot.activeThreads.length === 1 ? 'active thread' : 'active threads',
    secondaryMetric: String(snapshot.nearTermPriorities.length),
    secondaryLabel: 'priorities',
    tertiaryMetric: formatRelativeTimestamp(snapshot.generatedAt),
    tertiaryLabel: 'updated',
    rows,
    chips,
    iconToken: 'focus',
    accentToken: 'focus',
    backgroundToken: 'night',
    updatedAt: snapshot.generatedAt,
    deepLink: 'widget:assistant-focus',
  };
}

module.exports = {
  buildAssistantFocusSnapshot,
  buildAssistantFocusWidgetPayload,
};
