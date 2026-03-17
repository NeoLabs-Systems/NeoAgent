const crypto = require('crypto');
const db = require('../../db/database');
const { v4: uuidv4 } = require('uuid');

function parseIsoOrNull(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function asJson(value) {
  return JSON.stringify(value == null ? null : value);
}

function asText(value) {
  if (value == null) return null;
  const text = String(value).trim();
  return text.length ? text : null;
}

function buildFallbackRecordId(metricType, record) {
  const hash = crypto.createHash('sha1');
  hash.update(metricType || '');
  hash.update('\n');
  hash.update(asJson(record));
  return hash.digest('hex');
}

function normalizeRecord(record = {}) {
  const metricType = asText(record.metricType || record.type);
  if (!metricType) return null;

  const payload = record.payload && typeof record.payload === 'object'
    ? record.payload
    : {};

  return {
    metricType,
    recordId: asText(record.recordId || payload.recordId) || buildFallbackRecordId(metricType, record),
    startTime: parseIsoOrNull(record.startTime || payload.startTime),
    endTime: parseIsoOrNull(record.endTime || payload.endTime),
    recordedAt: parseIsoOrNull(record.recordedAt || payload.recordedAt || record.endTime || record.startTime),
    numericValue: Number.isFinite(Number(record.numericValue)) ? Number(record.numericValue) : null,
    textValue: asText(record.textValue),
    unit: asText(record.unit),
    sourceAppId: asText(record.sourceAppId || payload.sourceAppId),
    sourceDevice: asText(record.sourceDevice || payload.sourceDevice),
    lastModifiedTime: parseIsoOrNull(record.lastModifiedTime || payload.lastModifiedTime),
    payloadJson: asJson(payload),
  };
}

const insertRun = db.prepare(`
  INSERT INTO health_sync_runs (
    id, user_id, source, provider, sync_window_start, sync_window_end,
    record_count, summary_json, payload_json
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
`);

const upsertSample = db.prepare(`
  INSERT INTO health_metric_samples (
    user_id, sync_run_id, metric_type, record_id, start_time, end_time, recorded_at,
    numeric_value, text_value, unit, source_app_id, source_device, last_modified_time, payload_json
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ON CONFLICT(user_id, metric_type, record_id) DO UPDATE SET
    sync_run_id = excluded.sync_run_id,
    start_time = excluded.start_time,
    end_time = excluded.end_time,
    recorded_at = excluded.recorded_at,
    numeric_value = excluded.numeric_value,
    text_value = excluded.text_value,
    unit = excluded.unit,
    source_app_id = excluded.source_app_id,
    source_device = excluded.source_device,
    last_modified_time = excluded.last_modified_time,
    payload_json = excluded.payload_json,
    updated_at = datetime('now')
`);

const ingestHealthSyncTx = db.transaction((userId, body) => {
  const runId = uuidv4();
  const source = asText(body.source) || 'android-health-connect';
  const provider = asText(body.provider);
  const windowStart = parseIsoOrNull(body.windowStart);
  const windowEnd = parseIsoOrNull(body.windowEnd);
  const records = Array.isArray(body.records)
    ? body.records.map(normalizeRecord).filter(Boolean)
    : [];

  insertRun.run(
    runId,
    userId,
    source,
    provider,
    windowStart,
    windowEnd,
    records.length,
    asJson(body.summary || {}),
    asJson(body),
  );

  for (const record of records) {
    upsertSample.run(
      userId,
      runId,
      record.metricType,
      record.recordId,
      record.startTime,
      record.endTime,
      record.recordedAt,
      record.numericValue,
      record.textValue,
      record.unit,
      record.sourceAppId,
      record.sourceDevice,
      record.lastModifiedTime,
      record.payloadJson,
    );
  }

  return {
    runId,
    source,
    provider,
    windowStart,
    windowEnd,
    recordCount: records.length,
    acceptedMetrics: [...new Set(records.map((record) => record.metricType))],
  };
});

function ingestHealthSync(userId, body = {}) {
  if (!userId) throw new Error('Missing user');
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new Error('Health sync payload must be a JSON object');
  }
  return ingestHealthSyncTx(userId, body);
}

function getHealthSyncStatus(userId) {
  const lastRun = db.prepare(`
    SELECT id, source, provider, sync_window_start, sync_window_end, record_count, summary_json, created_at
    FROM health_sync_runs
    WHERE user_id = ?
    ORDER BY created_at DESC
    LIMIT 1
  `).get(userId);

  const metrics = db.prepare(`
    SELECT metric_type, COUNT(*) AS sample_count, MAX(COALESCE(end_time, recorded_at, start_time)) AS last_seen_at
    FROM health_metric_samples
    WHERE user_id = ?
    GROUP BY metric_type
    ORDER BY metric_type ASC
  `).all(userId);

  return {
    lastRun: lastRun ? {
      ...lastRun,
      summary: (() => {
        try { return JSON.parse(lastRun.summary_json || '{}'); } catch { return {}; }
      })(),
    } : null,
    metrics: metrics.map((metric) => ({
      metricType: metric.metric_type,
      sampleCount: Number(metric.sample_count || 0),
      lastSeenAt: metric.last_seen_at || null,
    })),
  };
}

// Aliases map collapsed/synonym forms → canonical stored metric_type values.
// Applied after camelCase/space normalization, so keys here are already lowercase+underscored.
const METRIC_TYPE_ALIASES = {
  // heart rate variants
  heartbeat: 'heart_rate',
  heartrate: 'heart_rate',
  heart_beat: 'heart_rate',
  bpm: 'heart_rate',
  pulse: 'heart_rate',
  // sleep variants
  sleep: 'sleep_session',
  sleeping: 'sleep_session',
  // exercise variants
  exercise: 'exercise_session',
  workout: 'exercise_session',
  activity: 'exercise_session',
  // weight variants
  body_weight: 'weight',
  bodyweight: 'weight',
  mass: 'weight',
  // steps variants
  step_count: 'steps',
  stepcount: 'steps',
  step: 'steps',
};

function normalizeMetricType(raw) {
  // Accept any casing/spacing: "HeartRate" → "heart_rate", "Steps" → "steps", etc.
  const normalized = String(raw || '')
    .trim()
    .replace(/([a-z])([A-Z])/g, '$1_$2')  // camelCase/PascalCase → snake_case
    .replace(/[\s-]+/g, '_')               // spaces/dashes → underscore
    .toLowerCase();
  // Resolve known synonyms to canonical stored values
  return METRIC_TYPE_ALIASES[normalized] || normalized;
}

function readHealthData(userId, metricType, limit = 50) {
  if (!metricType) {
    const metrics = db.prepare(`
      SELECT metric_type, COUNT(*) AS sample_count, MAX(COALESCE(end_time, recorded_at, start_time)) AS last_seen_at
      FROM health_metric_samples
      WHERE user_id = ?
      GROUP BY metric_type
      ORDER BY metric_type ASC
    `).all(userId);
    return { metrics };
  }

  const normalizedType = normalizeMetricType(metricType);

  // Aggregate summary — useful numbers without dumping raw rows
  const agg = db.prepare(`
    SELECT
      COUNT(*)                                                      AS record_count,
      SUM(numeric_value)                                            AS total,
      AVG(numeric_value)                                            AS avg,
      MIN(numeric_value)                                            AS min,
      MAX(numeric_value)                                            AS max,
      MIN(COALESCE(start_time, recorded_at))                        AS window_start,
      MAX(COALESCE(end_time, recorded_at, start_time))              AS window_end
    FROM health_metric_samples
    WHERE user_id = ? AND metric_type = ?
  `).get(userId, normalizedType);

  // Most-recent records — capped at limit (default 10 for readability)
  const actualLimit = Math.min(limit, 200);
  const samples = db.prepare(`
    SELECT
      start_time, end_time, recorded_at,
      numeric_value, text_value, unit,
      source_app_id, source_device,
      payload_json
    FROM health_metric_samples
    WHERE user_id = ? AND metric_type = ?
    ORDER BY COALESCE(end_time, recorded_at, start_time) DESC
    LIMIT ?
  `).all(userId, normalizedType, actualLimit);

  return {
    metricType: normalizedType,
    summary: {
      recordCount: agg.record_count || 0,
      total: agg.total ?? null,
      avg: agg.avg != null ? Math.round(agg.avg * 100) / 100 : null,
      min: agg.min ?? null,
      max: agg.max ?? null,
      windowStart: agg.window_start ?? null,
      windowEnd: agg.window_end ?? null,
      unit: samples[0]?.unit ?? null,
    },
    recentRecords: samples.map(s => ({
      startTime: s.start_time,
      endTime: s.end_time,
      recordedAt: s.recorded_at,
      value: s.numeric_value,
      text: s.text_value,
      unit: s.unit,
      payload: s.payload_json ? (() => { try { return JSON.parse(s.payload_json); } catch { return null; } })() : null,
    })),
  };
}

module.exports = {
  getHealthSyncStatus,
  ingestHealthSync,
  readHealthData,
};
