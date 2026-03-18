const db = require('../../db/database');

const DEFAULT_AI_SETTINGS = Object.freeze({
  cost_mode: 'balanced_auto',
  chat_history_window: 8,
  tool_replay_budget_chars: 1200,
  subagent_max_iterations: 6,
  auto_skill_learning: true,
  fallback_model_id: 'gpt-5-nano',
  smarter_model_selector: true
});

function parseSettingValue(value) {
  if (value == null) return null;
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function ensureDefaultAiSettings(userId) {
  if (!userId) return { ...DEFAULT_AI_SETTINGS };

  const existing = db.prepare(
    'SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (?, ?, ?, ?, ?, ?, ?)'
  ).all(
    userId,
    'cost_mode',
    'chat_history_window',
    'tool_replay_budget_chars',
    'subagent_max_iterations',
    'auto_skill_learning',
    'fallback_model_id',
    'smarter_model_selector'
  );

  const seen = new Set(existing.map((row) => row.key));
  const insert = db.prepare(
    'INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO NOTHING'
  );

  for (const [key, value] of Object.entries(DEFAULT_AI_SETTINGS)) {
    if (!seen.has(key)) {
      insert.run(userId, key, JSON.stringify(value));
    }
  }

  return getAiSettings(userId);
}

function getAiSettings(userId) {
  if (!userId) return { ...DEFAULT_AI_SETTINGS };

  const rows = db.prepare(
    'SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (?, ?, ?, ?, ?, ?, ?)'
  ).all(
    userId,
    'cost_mode',
    'chat_history_window',
    'tool_replay_budget_chars',
    'subagent_max_iterations',
    'auto_skill_learning',
    'fallback_model_id',
    'smarter_model_selector'
  );

  const settings = { ...DEFAULT_AI_SETTINGS };
  for (const row of rows) {
    settings[row.key] = parseSettingValue(row.value);
  }

  settings.chat_history_window = Math.max(4, Math.min(Number(settings.chat_history_window) || DEFAULT_AI_SETTINGS.chat_history_window, 12));
  settings.tool_replay_budget_chars = Math.max(400, Math.min(Number(settings.tool_replay_budget_chars) || DEFAULT_AI_SETTINGS.tool_replay_budget_chars, 2000));
  settings.subagent_max_iterations = Math.max(2, Math.min(Number(settings.subagent_max_iterations) || DEFAULT_AI_SETTINGS.subagent_max_iterations, 12));
  settings.cost_mode = typeof settings.cost_mode === 'string' ? settings.cost_mode : DEFAULT_AI_SETTINGS.cost_mode;
  settings.auto_skill_learning = settings.auto_skill_learning !== false && settings.auto_skill_learning !== 'false';
  settings.smarter_model_selector = settings.smarter_model_selector !== false && settings.smarter_model_selector !== 'false';
  settings.fallback_model_id = typeof settings.fallback_model_id === 'string' ? settings.fallback_model_id : DEFAULT_AI_SETTINGS.fallback_model_id;

  return settings;
}

module.exports = {
  DEFAULT_AI_SETTINGS,
  ensureDefaultAiSettings,
  getAiSettings
};
