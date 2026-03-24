const db = require('../../db/database');

const AI_PROVIDER_DEFINITIONS = Object.freeze({
  openai: {
    id: 'openai',
    label: 'OpenAI',
    description: 'GPT-5 and GPT-4.1 models for fast general work and reasoning.',
    envKey: 'OPENAI_API_KEY',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: true,
    defaultBaseUrl: ''
  },
  anthropic: {
    id: 'anthropic',
    label: 'Anthropic',
    description: 'Claude models for long-context drafting and analytical work.',
    envKey: 'ANTHROPIC_API_KEY',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: ''
  },
  google: {
    id: 'google',
    label: 'Google',
    description: 'Gemini models with large context windows and multimodal support.',
    envKey: 'GOOGLE_AI_KEY',
    supportsApiKey: true,
    supportsBaseUrl: false,
    defaultEnabled: true,
    defaultBaseUrl: ''
  },
  grok: {
    id: 'grok',
    label: 'xAI',
    description: 'Grok models tuned for personality-heavy chat and reasoning.',
    envKey: 'XAI_API_KEY',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: true,
    defaultBaseUrl: 'https://api.x.ai/v1'
  },
  minimax: {
    id: 'minimax',
    label: 'MiniMax Code',
    description: 'MiniMax Coding Plan for MiniMax-M2.7 through the Anthropic-compatible endpoint.',
    envKey: 'MINIMAX_API_KEY',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://api.minimax.io/anthropic'
  },
  ollama: {
    id: 'ollama',
    label: 'Ollama',
    description: 'Local models running on your machine through an Ollama server.',
    envKey: '',
    supportsApiKey: false,
    supportsBaseUrl: true,
    defaultEnabled: true,
    defaultBaseUrl: 'http://localhost:11434'
  }
});

function createDefaultProviderConfigs() {
  return Object.fromEntries(
    Object.values(AI_PROVIDER_DEFINITIONS).map((definition) => [
      definition.id,
      {
        enabled: definition.defaultEnabled,
        apiKey: '',
        baseUrl: definition.supportsBaseUrl ? definition.defaultBaseUrl : ''
      }
    ])
  );
}

function createDefaultAiSettings() {
  return {
    cost_mode: 'balanced_auto',
    chat_history_window: 8,
    tool_replay_budget_chars: 1200,
    subagent_max_iterations: 6,
    auto_skill_learning: false,
    fallback_model_id: 'gpt-5-nano',
    smarter_model_selector: true,
    ai_provider_configs: createDefaultProviderConfigs()
  };
}

const DEFAULT_AI_SETTINGS = Object.freeze(createDefaultAiSettings());

function parseSettingValue(value) {
  if (value == null) return null;
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function normalizeProviderConfigs(rawConfigs) {
  const defaults = createDefaultProviderConfigs();
  const parsed = rawConfigs && typeof rawConfigs === 'object' && !Array.isArray(rawConfigs)
    ? rawConfigs
    : {};

  const normalized = {};
  for (const definition of Object.values(AI_PROVIDER_DEFINITIONS)) {
    const raw = parsed[definition.id];
    const entry = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
    const baseUrl = typeof entry.baseUrl === 'string' ? entry.baseUrl.trim() : '';

    normalized[definition.id] = {
      enabled: entry.enabled !== false && entry.enabled !== 'false' && entry.enabled !== 0,
      apiKey: definition.supportsApiKey && typeof entry.apiKey === 'string'
        ? entry.apiKey.trim()
        : '',
      baseUrl: definition.supportsBaseUrl
        ? (baseUrl || defaults[definition.id].baseUrl)
        : ''
    };
  }

  return normalized;
}

function getProviderConfigs(userId) {
  if (!userId) return normalizeProviderConfigs(DEFAULT_AI_SETTINGS.ai_provider_configs);

  const row = db.prepare(
    'SELECT value FROM user_settings WHERE user_id = ? AND key = ?'
  ).get(userId, 'ai_provider_configs');

  return normalizeProviderConfigs(parseSettingValue(row?.value));
}

function ensureDefaultAiSettings(userId) {
  if (!userId) return createDefaultAiSettings();

  const existing = db.prepare(
    'SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (?, ?, ?, ?, ?, ?, ?, ?)'
  ).all(
    userId,
    'cost_mode',
    'chat_history_window',
    'tool_replay_budget_chars',
    'subagent_max_iterations',
    'auto_skill_learning',
    'fallback_model_id',
    'smarter_model_selector',
    'ai_provider_configs'
  );

  const seen = new Set(existing.map((row) => row.key));
  const insert = db.prepare(
    'INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO NOTHING'
  );

  for (const [key, value] of Object.entries(createDefaultAiSettings())) {
    if (!seen.has(key)) {
      insert.run(userId, key, JSON.stringify(value));
    }
  }

  return getAiSettings(userId);
}

function getAiSettings(userId) {
  if (!userId) return createDefaultAiSettings();

  const rows = db.prepare(
    'SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (?, ?, ?, ?, ?, ?, ?, ?)'
  ).all(
    userId,
    'cost_mode',
    'chat_history_window',
    'tool_replay_budget_chars',
    'subagent_max_iterations',
    'auto_skill_learning',
    'fallback_model_id',
    'smarter_model_selector',
    'ai_provider_configs'
  );

  const settings = createDefaultAiSettings();
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
  settings.ai_provider_configs = normalizeProviderConfigs(settings.ai_provider_configs);

  return settings;
}

module.exports = {
  AI_PROVIDER_DEFINITIONS,
  DEFAULT_AI_SETTINGS,
  createDefaultAiSettings,
  ensureDefaultAiSettings,
  getAiSettings,
  getProviderConfigs,
  normalizeProviderConfigs
};
