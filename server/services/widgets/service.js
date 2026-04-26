const crypto = require('crypto');
const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');
const { findNextRun, getMinimumIntervalMinutes } = require('../tasks/schedule_utils');

const MIN_WIDGET_REFRESH_MINUTES = 60;

const TEMPLATE_VARIANTS = {
  stat: ['hero', 'split', 'compact'],
  summary: ['stack', 'banner', 'focus'],
  list: ['agenda', 'compact', 'split'],
};

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

function normalizeText(value, maxLength = 4000) {
  return String(value || '').trim().slice(0, maxLength);
}

function normalizeOptionalText(value, maxLength = 4000) {
  const normalized = normalizeText(value, maxLength);
  return normalized || null;
}

function normalizeSurfaceColor(value) {
  const normalized = normalizeOptionalText(value, 16);
  if (!normalized) return null;
  const prefixed = normalized.startsWith('#') ? normalized : `#${normalized}`;
  return /^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(prefixed)
    ? prefixed.toUpperCase()
    : null;
}

function buildWidgetRefreshTaskName(name) {
  return `Refresh widget: ${normalizeText(name, 120)}`;
}

function templateVariants(template) {
  return TEMPLATE_VARIANTS[template] || [];
}

function normalizeDefinition(input = {}) {
  const raw = parseJsonObject(input, {});
  const prompt = normalizeText(raw.prompt || raw.refreshPrompt || raw.goal || '', 12000);
  if (!prompt) {
    throw new Error('Widget definition requires a prompt.');
  }

  return {
    prompt,
    description: normalizeOptionalText(raw.description, 500),
    systemHint: normalizeOptionalText(raw.systemHint, 1000),
    emptyState: normalizeOptionalText(raw.emptyState, 200),
  };
}

function validateRefreshCron(refreshCron) {
  const cronExpression = normalizeText(refreshCron, 120);
  if (!cronExpression) {
    throw new Error('refreshCron is required.');
  }
  const minInterval = getMinimumIntervalMinutes(cronExpression, 4);
  if (minInterval != null && minInterval < MIN_WIDGET_REFRESH_MINUTES) {
    throw new Error('Widget refresh cadence must be at least 1 hour.');
  }
  return cronExpression;
}

function normalizeWidgetInput(input = {}, userId) {
  const name = normalizeText(input.name, 120);
  if (!name) {
    throw new Error('Widget name is required.');
  }

  const template = normalizeText(input.template, 40).toLowerCase();
  if (!Object.prototype.hasOwnProperty.call(TEMPLATE_VARIANTS, template)) {
    throw new Error(`Unsupported widget template "${template}".`);
  }

  const layoutVariant = normalizeText(input.layoutVariant || input.layout_variant, 40).toLowerCase();
  if (!templateVariants(template).includes(layoutVariant)) {
    throw new Error(`Unsupported layout variant "${layoutVariant}" for template "${template}".`);
  }

  const refreshCron = validateRefreshCron(input.refreshCron || input.refresh_cron);
  const agentId = resolveAgentId(userId, input.agentId || input.agent_id || null);

  return {
    name,
    template,
    layoutVariant,
    refreshCron,
    enabled: input.enabled !== false,
    definition: normalizeDefinition(input.definition || input.definition_json || {
      prompt: input.prompt || input.refreshPrompt || input.refresh_prompt || '',
      description: input.description || '',
    }),
    agentId,
  };
}

function normalizeTrend(input) {
  if (input == null) return null;
  if (typeof input === 'string') {
    const label = normalizeText(input, 80);
    return label ? { label, direction: 'flat' } : null;
  }
  const raw = parseJsonObject(input, {});
  const label = normalizeText(raw.label, 80);
  if (!label) return null;
  const direction = ['up', 'down', 'flat'].includes(String(raw.direction || '').trim().toLowerCase())
    ? String(raw.direction).trim().toLowerCase()
    : 'flat';
  return { label, direction };
}

function normalizeOptionalNumber(input, { min = null, max = null } = {}) {
  if (input == null || input === '') return null;
  const value = Number(input);
  if (!Number.isFinite(value)) return null;
  if (min != null && value < min) return min;
  if (max != null && value > max) return max;
  return value;
}

function normalizeProgress(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  const raw = parseJsonObject(input, {});
  const value = normalizeOptionalNumber(raw.value, { min: 0 });
  const max = normalizeOptionalNumber(raw.max, { min: 0 });
  if (value == null || max == null || max <= 0) return null;
  return {
    value: Math.min(value, max),
    max,
    label: normalizeOptionalText(raw.label, 60),
  };
}

function normalizeRows(input) {
  if (!Array.isArray(input)) return [];
  return input
    .slice(0, 3)
    .map((row) => {
      if (typeof row === 'string') {
        const value = normalizeText(row, 140);
        if (!value) return null;
        return { label: value, value: '' };
      }
      const raw = parseJsonObject(row, {});
      const label = normalizeText(raw.label, 60);
      const value = normalizeText(raw.value, 120);
      if (!label && !value) return null;
      return {
        label: label || value,
        value: value || label,
      };
    })
    .filter(Boolean);
}

function normalizeChips(input) {
  if (!Array.isArray(input)) return [];
  return input
    .slice(0, 3)
    .map((chip) => normalizeText(chip, 40))
    .filter(Boolean);
}

function serializeSnapshotRow(row) {
  if (!row) return null;
  const payload = parseJsonObject(row.payload_json, {});
  return {
    id: row.id,
    widgetId: row.widget_id,
    payload,
    generatedAt: row.generated_at,
    sourceRunId: row.source_run_id || null,
    status: row.status || 'ready',
  };
}

function validateSnapshotPayload(widget, snapshot = {}) {
  const payload = parseJsonObject(snapshot, {});
  const title = normalizeText(payload.title, 120);
  if (!title) {
    throw new Error('Widget snapshots require a title.');
  }

  return {
    template: widget.template,
    layoutVariant: widget.layoutVariant,
    title,
    kicker: normalizeOptionalText(payload.kicker, 80),
    subtitle: normalizeOptionalText(payload.subtitle, 160),
    body: normalizeOptionalText(payload.body, 600),
    metric: normalizeOptionalText(payload.metric, 64),
    metricLabel: normalizeOptionalText(payload.metricLabel, 80),
    secondaryMetric: normalizeOptionalText(payload.secondaryMetric, 64),
    secondaryLabel: normalizeOptionalText(payload.secondaryLabel, 80),
    tertiaryMetric: normalizeOptionalText(payload.tertiaryMetric, 64),
    tertiaryLabel: normalizeOptionalText(payload.tertiaryLabel, 80),
    trend: normalizeTrend(payload.trend),
    progress: normalizeProgress(payload.progress),
    rows: normalizeRows(payload.rows),
    chips: normalizeChips(payload.chips),
    iconToken: normalizeOptionalText(payload.iconToken, 40),
    accentToken: normalizeOptionalText(payload.accentToken, 40),
    backgroundToken: normalizeOptionalText(payload.backgroundToken, 40),
    surfaceColor: normalizeSurfaceColor(payload.surfaceColor),
    updatedAt: normalizeOptionalText(payload.updatedAt, 80) || new Date().toISOString(),
    deepLink: normalizeOptionalText(payload.deepLink, 200) || `widget:${widget.id}`,
  };
}

class WidgetService {
  constructor({ app }) {
    this.app = app;
  }

  get taskRuntime() {
    return this.app?.locals?.taskRuntime || null;
  }

  get agentEngine() {
    return this.app?.locals?.agentEngine || null;
  }

  getWidget(userId, widgetId) {
    const row = db.prepare(
      `SELECT *
       FROM ai_widgets
       WHERE id = ? AND user_id = ?`
    ).get(widgetId, userId);
    if (!row) return null;
    return this._serializeWidget(
      row,
      this._loadLatestSnapshotMap([widgetId]).get(widgetId) || null,
      this._loadWidgetTasksMap([widgetId], userId).get(widgetId) || []
    );
  }

  listWidgets(userId, { agentId = null } = {}) {
    const scopedAgentId = agentId ? resolveAgentId(userId, agentId) : null;
    const rows = scopedAgentId
      ? db.prepare(
        `SELECT *
         FROM ai_widgets
         WHERE user_id = ? AND agent_id = ?
         ORDER BY updated_at DESC, created_at DESC`
      ).all(userId, scopedAgentId)
      : db.prepare(
        `SELECT *
         FROM ai_widgets
         WHERE user_id = ?
         ORDER BY updated_at DESC, created_at DESC`
      ).all(userId);
    const snapshotMap = this._loadLatestSnapshotMap(rows.map((row) => row.id));
    const tasksMap = this._loadWidgetTasksMap(rows.map((row) => row.id), userId);
    return rows.map((row) => this._serializeWidget(row, snapshotMap.get(row.id) || null, tasksMap.get(row.id) || []));
  }

  listLatestSnapshots(userId, { agentId = null } = {}) {
    return this.listWidgets(userId, { agentId })
      .map((widget) => widget.latestSnapshot)
      .filter(Boolean);
  }

  async createWidget(userId, input = {}) {
    const normalized = normalizeWidgetInput(input, userId);
    const taskRuntime = this.taskRuntime;
    if (!taskRuntime) {
      throw new Error('Task runtime not available.');
    }
    const widgetId = crypto.randomUUID();

    const tx = db.transaction(() => {
      db.prepare(
        `INSERT INTO ai_widgets (
          id, user_id, agent_id, name, template, layout_variant, definition_json,
          refresh_cron, enabled, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))`
      ).run(
        widgetId,
        userId,
        normalized.agentId,
        normalized.name,
        normalized.template,
        normalized.layoutVariant,
        JSON.stringify(normalized.definition),
        normalized.refreshCron,
        normalized.enabled ? 1 : 0,
      );
    });

    tx();

    let task;
    try {
      task = await taskRuntime.createTask(userId, {
        name: buildWidgetRefreshTaskName(normalized.name),
        triggerType: 'schedule',
        triggerConfig: {
          mode: 'recurring',
          cronExpression: normalized.refreshCron,
        },
        enabled: normalized.enabled,
        agentId: normalized.agentId,
        taskType: 'widget_refresh',
        taskConfig: { widgetId },
      });
    } catch (error) {
      db.prepare('DELETE FROM ai_widgets WHERE id = ? AND user_id = ?').run(widgetId, userId);
      throw error;
    }

    try {
      db.prepare(
        `UPDATE ai_widgets
         SET scheduled_task_id = ?, updated_at = datetime('now')
         WHERE id = ? AND user_id = ?`
      ).run(task.id, widgetId, userId);
    } catch (error) {
      try {
        taskRuntime.deleteTask(task.id, userId, { allowManaged: true });
      } catch {
        // Ignore cleanup failures and rethrow the original DB error.
      }
      throw error;
    }

    return this.getWidget(userId, widgetId);
  }

  async updateWidget(userId, widgetId, input = {}) {
    const existingRow = db.prepare('SELECT * FROM ai_widgets WHERE id = ? AND user_id = ?').get(widgetId, userId);
    if (!existingRow) {
      throw new Error('Widget not found.');
    }

    const current = this._serializeWidget(existingRow, null, []);
    const normalized = normalizeWidgetInput({
      name: input.name ?? current.name,
      template: input.template ?? current.template,
      layoutVariant: input.layoutVariant ?? input.layout_variant ?? current.layoutVariant,
      refreshCron: input.refreshCron ?? input.refresh_cron ?? current.refreshCron,
      enabled: input.enabled ?? current.enabled,
      agentId: input.agentId ?? input.agent_id ?? current.agentId,
      definition: input.definition ?? input.definition_json ?? current.definition,
      prompt: input.prompt,
      refreshPrompt: input.refreshPrompt ?? input.refresh_prompt,
      description: input.description,
    }, userId);

    const taskRuntime = this.taskRuntime;
    if (!taskRuntime) {
      throw new Error('Task runtime not available.');
    }

    db.prepare('BEGIN').run();
    try {
      db.prepare(
        `UPDATE ai_widgets
         SET agent_id = ?, name = ?, template = ?, layout_variant = ?, definition_json = ?,
             refresh_cron = ?, enabled = ?, updated_at = datetime('now')
         WHERE id = ? AND user_id = ?`
      ).run(
        normalized.agentId,
        normalized.name,
        normalized.template,
        normalized.layoutVariant,
        JSON.stringify(normalized.definition),
        normalized.refreshCron,
        normalized.enabled ? 1 : 0,
        widgetId,
        userId,
      );

      if (existingRow.scheduled_task_id) {
        await taskRuntime.updateTask(
          existingRow.scheduled_task_id,
          userId,
          {
            name: buildWidgetRefreshTaskName(normalized.name),
            triggerType: 'schedule',
            triggerConfig: {
              mode: 'recurring',
              cronExpression: normalized.refreshCron,
            },
            enabled: normalized.enabled,
            agentId: normalized.agentId,
            taskConfig: { widgetId },
          },
          { allowManaged: true },
        );
      } else {
        const task = await taskRuntime.createTask(userId, {
          name: buildWidgetRefreshTaskName(normalized.name),
          triggerType: 'schedule',
          triggerConfig: {
            mode: 'recurring',
            cronExpression: normalized.refreshCron,
          },
          enabled: normalized.enabled,
          agentId: normalized.agentId,
          taskType: 'widget_refresh',
          taskConfig: { widgetId },
        });
        db.prepare(
          `UPDATE ai_widgets
           SET scheduled_task_id = ?, updated_at = datetime('now')
           WHERE id = ? AND user_id = ?`
        ).run(task.id, widgetId, userId);
      }

      db.prepare('COMMIT').run();
    } catch (error) {
      try {
        db.prepare('ROLLBACK').run();
      } catch {
        // Ignore rollback failures and rethrow the original task runtime/DB error.
      }
      throw error;
    }

    return this.getWidget(userId, widgetId);
  }

  deleteWidget(userId, widgetId) {
    const existingRow = db.prepare('SELECT * FROM ai_widgets WHERE id = ? AND user_id = ?').get(widgetId, userId);
    if (!existingRow) {
      throw new Error('Widget not found.');
    }

    const taskRuntime = this.taskRuntime;
    const tx = db.transaction(() => {
      if (existingRow.scheduled_task_id && taskRuntime) {
        taskRuntime.deleteTask(existingRow.scheduled_task_id, userId, { allowManaged: true });
      }
      db.prepare('DELETE FROM ai_widget_snapshots WHERE widget_id = ?').run(widgetId);
      db.prepare('DELETE FROM ai_widgets WHERE id = ? AND user_id = ?').run(widgetId, userId);
    });
    tx();
    return { deleted: true };
  }

  saveSnapshot(userId, widgetId, snapshot, { sourceRunId = null, status = 'ready' } = {}) {
    const widget = this.getWidget(userId, widgetId);
    if (!widget) {
      throw new Error('Widget not found.');
    }

    const payload = validateSnapshotPayload(widget, snapshot);
    const snapshotId = db.prepare(
      `INSERT INTO ai_widget_snapshots (
        widget_id, payload_json, generated_at, source_run_id, status
      ) VALUES (?, ?, datetime('now'), ?, ?)`
    ).run(widgetId, JSON.stringify(payload), sourceRunId, status).lastInsertRowid;

    db.prepare(
      `UPDATE ai_widgets
       SET last_snapshot_at = datetime('now'), last_error = NULL, updated_at = datetime('now')
       WHERE id = ? AND user_id = ?`
    ).run(widgetId, userId);

    const row = db.prepare('SELECT * FROM ai_widget_snapshots WHERE id = ?').get(snapshotId);
    return serializeSnapshotRow(row);
  }

  setWidgetError(userId, widgetId, message) {
    db.prepare(
      `UPDATE ai_widgets
       SET last_error = ?, updated_at = datetime('now')
       WHERE id = ? AND user_id = ?`
    ).run(normalizeText(message, 500), widgetId, userId);
  }

  async refreshWidget(userId, widgetId, options = {}) {
    const widget = this.getWidget(userId, widgetId);
    if (!widget) {
      throw new Error('Widget not found.');
    }
    if (!widget.enabled) {
      return { skipped: true, reason: 'disabled' };
    }
    const engine = this.agentEngine;
    if (!engine) {
      throw new Error('Agent engine not available.');
    }

    try {
      const prompt = this._buildRefreshPrompt(widget);
      const result = await engine.run(userId, prompt, {
        triggerType: 'schedule',
        triggerSource: 'tasks',
        agentId: widget.agentId,
        app: this.app,
        taskId: options.taskId || widget.scheduledTaskId || null,
        widgetId: widget.id,
        skipTaskAnalysis: true,
        skipGlobalRecall: true,
        skipConversationHistory: true,
        skipConversationMaintenance: true,
        skipRunContextPersistence: true,
        skipVerifier: true,
        stream: false,
      });
      if (result?.runId) {
        engine.persistRunMetadata(result.runId, {
          widgetId: widget.id,
          widgetTemplate: widget.template,
          widgetLayoutVariant: widget.layoutVariant,
        });
      }
      return result;
    } catch (error) {
      this.setWidgetError(userId, widgetId, error?.message || 'Widget refresh failed.');
      throw error;
    }
  }

  _buildRefreshPrompt(widget) {
    const definition = widget.definition || {};
    return [
      '[SYSTEM: Refreshing AI Widget]',
      `Widget ID: ${widget.id}`,
      `Widget name: ${widget.name}`,
      `Template: ${widget.template}`,
      `Layout variant: ${widget.layoutVariant}`,
      '',
      'You are updating a structured product widget. Keep the layout fixed. Refresh only the content snapshot.',
      'Use fresh tools for time-sensitive claims. Do not rely on stale memory for live data such as weather, markets, incidents, or schedules.',
      'After gathering the latest information, call save_widget_snapshot exactly once with a payload matching this schema:',
      '{"title":"","kicker":"","subtitle":"","body":"","metric":"","metricLabel":"","secondaryMetric":"","secondaryLabel":"","tertiaryMetric":"","tertiaryLabel":"","trend":{"label":"","direction":"flat"},"progress":{"value":0,"max":100,"label":""},"rows":[{"label":"","value":""}],"chips":[""],"iconToken":"","accentToken":"","backgroundToken":"","surfaceColor":"","updatedAt":"","deepLink":""}',
      'Rules:',
      '- Do not change the template or layout variant.',
      '- Once you have enough accurate data, call save_widget_snapshot exactly once and stop. Do not keep exploring after saving.',
      '- Keep rows to at most 3 and chips to at most 3.',
      '- Prefer concrete data over generic prose. Use metric + supporting fields whenever live data exists.',
      '- Make the widget immediately useful at a glance. Avoid filler copy, duplicated labels, or repeating the widget name unless it helps identify the subject.',
      '- For stat widgets, use title to identify the subject, metric for the main live value, and secondary or tertiary metrics for the next most useful facts.',
      '- For summary widgets, keep body concise and information-dense. Use kicker or subtitle for the context, not for repeated metadata.',
      '- For list widgets, rows should be concrete current items with short labels and values. Do not use rows for vague prose.',
      '- For weather-style widgets, include real temperature/condition/wind/precipitation when available and choose a fitting accent/background token such as sunny, rain, storm, night, or cloud.',
      '- For vehicle-style widgets, include battery or fuel state, range, odometer or distance, and choose a color token or surfaceColor when the vehicle color is known.',
      '- Use backgroundToken and accentToken to reflect the actual state of the data, not a default theme.',
      '- If the subject exposes a progress-like state such as battery charge, tank level, or completion, populate progress with truthful values.',
      '- Never output placeholders such as "null", "n/a", "---", or invented values.',
      '- If the data source fails, explain the problem briefly in body and still save a truthful degraded snapshot if possible.',
      '- If nothing useful can be produced safely, say so clearly instead of inventing content.',
      '',
      'Widget definition:',
      definition.prompt || '',
      definition.systemHint ? `\nExtra guidance:\n${definition.systemHint}` : '',
    ].join('\n');
  }

  _loadLatestSnapshotMap(widgetIds) {
    const ids = Array.from(new Set(widgetIds.filter(Boolean)));
    const map = new Map();
    if (!ids.length) return map;
    const placeholders = ids.map(() => '?').join(', ');
    const rows = db.prepare(
      `SELECT s.*
       FROM ai_widget_snapshots s
       INNER JOIN (
         SELECT widget_id, MAX(id) AS latest_id
         FROM ai_widget_snapshots
         WHERE widget_id IN (${placeholders})
         GROUP BY widget_id
       ) latest ON latest.latest_id = s.id`
    ).all(...ids);
    for (const row of rows) {
      map.set(row.widget_id, serializeSnapshotRow(row));
    }
    return map;
  }

  _loadWidgetTasksMap(widgetIds, userId) {
    const ids = Array.from(new Set(widgetIds.filter(Boolean)));
    const map = new Map();
    if (!ids.length) return map;
    
    const placeholders = ids.map(() => '?').join(', ');
    const params = [userId, ...ids];
    
    // We filter tasks where task_type is NOT 'widget_refresh' 
    // and where the task_config contains the widgetId.
    const rows = db.prepare(
      `SELECT id, name, trigger_type, enabled, task_config
       FROM scheduled_tasks
       WHERE user_id = ?
         AND task_type != 'widget_refresh'
         AND json_extract(task_config, '$.widgetId') IN (${placeholders})
       ORDER BY created_at ASC`
    ).all(...params);
    
    for (const row of rows) {
      const config = parseJsonObject(row.task_config, {});
      const widgetId = config.widgetId;
      if (!widgetId) continue;
      
      const task = {
        id: row.id,
        name: row.name,
        triggerType: row.trigger_type,
        enabled: row.enabled !== 0 && row.enabled !== false,
      };
      
      if (!map.has(widgetId)) {
        map.set(widgetId, []);
      }
      map.get(widgetId).push(task);
    }
    return map;
  }

  _serializeWidget(row, latestSnapshot, tasks = []) {
    const definition = parseJsonObject(row.definition_json, {});
    return {
      id: row.id,
      userId: row.user_id,
      agentId: row.agent_id || null,
      name: row.name,
      template: row.template,
      layoutVariant: row.layout_variant,
      definition,
      refreshCron: row.refresh_cron,
      enabled: row.enabled !== 0 && row.enabled !== false,
      scheduledTaskId: row.scheduled_task_id || null,
      lastSnapshotAt: row.last_snapshot_at || null,
      lastError: row.last_error || null,
      createdAt: row.created_at || null,
      updatedAt: row.updated_at || null,
      nextRefresh: row.refresh_cron ? findNextRun(row.refresh_cron)?.toISOString() || null : null,
      latestSnapshot,
      tasks,
    };
  }
}

module.exports = {
  MIN_WIDGET_REFRESH_MINUTES,
  TEMPLATE_VARIANTS,
  WidgetService,
  buildWidgetRefreshTaskName,
  validateRefreshCron,
};
