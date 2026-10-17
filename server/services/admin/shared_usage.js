'use strict';

// The admin analytics section built from accounts that opted in to usage data
// sharing (services/account/data_sharing.js). Everything here is pooled
// across those accounts and limited to metadata: counts, names of tools,
// models and integrations, timings. No message text, run titles, tool inputs
// or results, file names, account identities or locations are read.

const db = require('../../db/database');
const { listSharingRecords } = require('../account/data_sharing');

// Every query binds @ids, the JSON array of sharing account ids.
const SHARING_USERS = '(SELECT value FROM json_each(@ids))';

// Each feature counts the sharing accounts that have set it up at least once.
const FEATURES = [
  { key: 'agents', sql: 'SELECT user_id FROM agents GROUP BY user_id HAVING COUNT(*) > 1' },
  { key: 'scheduledTasks', sql: 'SELECT user_id FROM scheduled_tasks WHERE enabled = 1' },
  { key: 'skills', sql: 'SELECT user_id FROM skills WHERE user_id > 0' },
  { key: 'mcpServers', sql: 'SELECT user_id FROM mcp_servers' },
  { key: 'integrations', sql: "SELECT user_id FROM integration_connections WHERE status = 'connected'" },
  { key: 'messaging', sql: 'SELECT user_id FROM platform_connections WHERE last_connected IS NOT NULL' },
  { key: 'memory', sql: 'SELECT user_id FROM memories' },
];

function tally(values) {
  const counts = new Map();
  for (const value of values) {
    if (!value) continue;
    counts.set(value, (counts.get(value) || 0) + 1);
  }
  return [...counts.entries()]
    .map(([label, count]) => ({ label, count }))
    .sort((a, b) => b.count - a.count);
}

function settingValues(params, key) {
  const rows = db.prepare(`
    SELECT value FROM user_settings WHERE key = @key AND user_id IN ${SHARING_USERS}
  `).all({ ...params, key });
  return rows.map((row) => {
    try {
      return String(JSON.parse(row.value) || '');
    } catch {
      return String(row.value || '');
    }
  });
}

// "Europe/Berlin" becomes "Europe": enough for when people are around,
// too coarse to place anyone.
function timeZoneRegion(zone) {
  const region = zone.split('/')[0];
  return region && region !== zone ? region : null;
}

function audience(params, records) {
  return {
    platforms: tally(records.map((record) => record.client?.platform)),
    appVersions: tally(records.map((record) => record.client?.appVersion)).slice(0, 8),
    languages: tally(settingValues(params, 'ui_language')),
    regions: tally(settingValues(params, 'timezone').map(timeZoneRegion)),
  };
}

function featureAdoption(params) {
  return FEATURES.map(({ key, sql }) => ({
    key,
    users: db.prepare(`
      SELECT COUNT(DISTINCT user_id) AS n FROM (${sql}) WHERE user_id IN ${SHARING_USERS}
    `).get(params).n,
  }));
}

function connectedIntegrations(params) {
  return db.prepare(`
    SELECT provider_key AS label, COUNT(DISTINCT user_id) AS count
    FROM integration_connections
    WHERE status = 'connected' AND user_id IN ${SHARING_USERS}
    GROUP BY provider_key
    ORDER BY count DESC, label
    LIMIT 10
  `).all(params);
}

function connectedMessaging(params) {
  return db.prepare(`
    SELECT platform AS label, COUNT(DISTINCT user_id) AS count
    FROM platform_connections
    WHERE last_connected IS NOT NULL AND user_id IN ${SHARING_USERS}
    GROUP BY platform
    ORDER BY count DESC, label
  `).all(params);
}

function toolUsage(params) {
  return db.prepare(`
    SELECT s.tool_name AS tool,
           COUNT(*) AS calls,
           SUM(CASE WHEN s.status = 'failed' THEN 1 ELSE 0 END) AS failures
    FROM agent_steps s
    JOIN agent_runs r ON r.id = s.run_id
    WHERE s.tool_name IS NOT NULL AND r.created_at > @since AND r.user_id IN ${SHARING_USERS}
    GROUP BY s.tool_name
    ORDER BY calls DESC
    LIMIT 12
  `).all(params);
}

function runTriggers(params) {
  return db.prepare(`
    SELECT COALESCE(trigger_type, 'user') AS label, COUNT(*) AS count
    FROM agent_runs
    WHERE created_at > @since AND user_id IN ${SHARING_USERS}
    GROUP BY label
    ORDER BY count DESC
  `).all(params);
}

// Runs per weekday (0 = Sunday) and hour, in UTC.
function activityHeatmap(params) {
  return db.prepare(`
    SELECT CAST(strftime('%w', created_at) AS INTEGER) AS weekday,
           CAST(strftime('%H', created_at) AS INTEGER) AS hour,
           COUNT(*) AS runs
    FROM agent_runs
    WHERE created_at > @since AND user_id IN ${SHARING_USERS}
    GROUP BY weekday, hour
  `).all(params);
}

function runOutcomes(params) {
  const row = db.prepare(`
    SELECT COUNT(*) AS runs,
           SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed,
           AVG(CASE WHEN status = 'completed' AND completed_at IS NOT NULL
                    THEN (julianday(completed_at) - julianday(created_at)) * 86400 END) AS avgSeconds,
           AVG(total_tokens) AS avgTokens
    FROM agent_runs
    WHERE created_at > @since AND user_id IN ${SHARING_USERS}
  `).get(params);
  const steps = db.prepare(`
    SELECT AVG(n) AS avgSteps FROM (
      SELECT COUNT(s.id) AS n
      FROM agent_runs r
      LEFT JOIN agent_steps s ON s.run_id = r.id
      WHERE r.created_at > @since AND r.user_id IN ${SHARING_USERS}
      GROUP BY r.id
    )
  `).get(params);
  return {
    runs: row.runs,
    successRate: row.runs > 0 ? Math.round((row.completed / row.runs) * 100) : 0,
    avgDurationSeconds: Math.round(row.avgSeconds || 0),
    avgTokens: Math.round(row.avgTokens || 0),
    avgSteps: Math.round((steps.avgSteps || 0) * 10) / 10,
  };
}

function modelPerformance(params) {
  return db.prepare(`
    SELECT provider, model,
           COUNT(*) AS calls,
           CAST(AVG(latency_ms) AS INTEGER) AS avgLatencyMs,
           COALESCE(SUM(input_tokens), 0) AS inputTokens,
           COALESCE(SUM(cached_read_tokens), 0) AS cachedTokens,
           COALESCE(SUM(output_tokens), 0) AS outputTokens,
           SUM(estimated_cost_usd) AS costUsd
    FROM agent_model_usage
    WHERE phase = 'model_turn' AND created_at > @since AND user_id IN ${SHARING_USERS}
    GROUP BY provider, model
    ORDER BY calls DESC
    LIMIT 8
  `).all(params);
}

function getSharedUsage(since) {
  const records = listSharingRecords();
  const params = { since, ids: JSON.stringify(records.map((record) => record.userId)) };
  const participants = {
    sharing: records.length,
    total: db.prepare('SELECT COUNT(*) AS n FROM users').get().n,
  };
  if (records.length === 0) return { participants };
  return {
    participants,
    audience: audience(params, records),
    features: featureAdoption(params),
    integrations: connectedIntegrations(params),
    messaging: connectedMessaging(params),
    tools: toolUsage(params),
    triggers: runTriggers(params),
    activity: activityHeatmap(params),
    outcomes: runOutcomes(params),
    models: modelPerformance(params),
  };
}

module.exports = { getSharedUsage };
