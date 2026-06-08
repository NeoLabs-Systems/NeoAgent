const db = require('../../db/database');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const {
  normalizeRuntimeMode,
  normalizeLiveProvider,
  resolveLiveModel,
  resolveLiveVoice,
} = require('../voice/liveSettings');

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
  'grok-oauth': {
    id: 'grok-oauth',
    label: 'Grok (xAI OAuth)',
    description: 'Grok models via xAI account. Login with `neoagent login grok-oauth`.',
    envKey: 'GROK_OAUTH_ACCESS_TOKEN',
    supportsApiKey: true,
    supportsBaseUrl: false,
    defaultEnabled: false,
    defaultBaseUrl: ''
  },
  nvidia: {
    id: 'nvidia',
    label: 'NVIDIA NIM',
    description: 'NVIDIA-hosted models including free-tier Nemotron, Kimi, Llama 4, and DeepSeek. Get a key at build.nvidia.com.',
    envKey: 'NVIDIA_API_KEY',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://integrate.api.nvidia.com/v1'
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
  'github-copilot': {
    id: 'github-copilot',
    label: 'GitHub Copilot',
    description: 'Use your GitHub Copilot subscription as an AI provider.',
    envKey: 'GITHUB_COPILOT_ACCESS_TOKEN',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://api.githubcopilot.com'
  },
  'openai-codex': {
    id: 'openai-codex',
    label: 'OpenAI Codex',
    description: 'Use Codex models through ChatGPT Codex authentication.',
    envKey: 'OPENAI_CODEX_ACCESS_TOKEN',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://chatgpt.com/backend-api/codex'
  },
  'claude-code': {
    id: 'claude-code',
    label: 'Claude Code',
    description: 'Claude models via Claude Code subscription. Login with `neoagent login claude-code`.',
    envKey: 'CLAUDE_CODE_OAUTH_TOKEN',
    supportsApiKey: true,
    supportsBaseUrl: false,
    defaultEnabled: false,
    defaultBaseUrl: ''
  },
  openrouter: {
    id: 'openrouter',
    label: 'OpenRouter',
    description: 'Access 300+ models through one API, including free-tier models. Get a key at openrouter.ai.',
    envKey: 'OPENROUTER_API_KEY',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://openrouter.ai/api/v1'
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
        baseUrl: definition.supportsBaseUrl ? definition.defaultBaseUrl : ''
      }
    ])
  );
}

function createDefaultAiSettings() {
  return {
    cost_mode: 'balanced_auto',
    chat_history_window: 20,
    tool_replay_budget_chars: 6000,
    subagent_max_iterations: 6,
    assistant_behavior_notes: '',
    auto_skill_learning: false,
    auto_recording_insights: true,
    default_recording_transcription_provider: 'deepgram',
    default_recording_transcription_model: 'nova-3',
    default_recording_summary_provider: 'auto',
    default_recording_summary_model: 'auto',
    fallback_model_id: 'gpt-5-nano',
    smarter_model_selector: true,
    enabled_models: [],
    default_chat_model: 'auto',
    default_subagent_model: 'auto',
    default_speech_model: 'auto',
    ai_provider_configs: createDefaultProviderConfigs(),
    voice_runtime_mode: 'live',
    voice_live_provider: 'openai',
    voice_live_model: 'gpt-realtime-1.5',
    voice_live_voice: 'alloy',
  };
}

const DEFAULT_AI_SETTINGS = Object.freeze(createDefaultAiSettings());
const AI_SETTING_KEYS = Object.freeze(Object.keys(DEFAULT_AI_SETTINGS));
const AI_SETTING_PLACEHOLDERS = AI_SETTING_KEYS.map(() => '?').join(', ');

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
      baseUrl: definition.supportsBaseUrl
        ? (baseUrl || defaults[definition.id].baseUrl)
        : ''
    };
  }

  return normalized;
}

function getProviderConfigs(userId, agentId = null) {
  if (!userId) return normalizeProviderConfigs(DEFAULT_AI_SETTINGS.ai_provider_configs);

  const scopedAgentId = resolveAgentId(userId, agentId);
  if (scopedAgentId) {
    const agentRow = db.prepare(
      'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?'
    ).get(userId, scopedAgentId, 'ai_provider_configs');
    if (agentRow) return normalizeProviderConfigs(parseSettingValue(agentRow.value));
  }

  const row = isMainAgent(userId, scopedAgentId)
    ? db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
      .get(userId, 'ai_provider_configs')
    : null;

  return normalizeProviderConfigs(parseSettingValue(row?.value));
}

function parseEncryptedJson(value, fallback = {}) {
  if (!value) return fallback;
  try {
    const raw = decryptValue(String(value));
    const parsed = JSON.parse(raw || '{}');
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : fallback;
  } catch {
    return fallback;
  }
}

function getProviderSecrets(userId, agentId = null) {
  if (!userId) return {};
  const scopedAgentId = resolveAgentId(userId, agentId);
  if (!scopedAgentId) return {};
  const row = db.prepare(
    'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?'
  ).get(userId, scopedAgentId, 'ai_provider_api_keys');
  return parseEncryptedJson(row?.value, {});
}

function setProviderSecrets(userId, agentId, secrets = {}) {
  const scopedAgentId = resolveAgentId(userId, agentId);
  if (!scopedAgentId) return;
  const cleaned = Object.fromEntries(
    Object.entries(secrets || {})
      .map(([key, value]) => [String(key), String(value || '').trim()])
      .filter(([, value]) => value)
  );
  db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`
  ).run(userId, scopedAgentId, 'ai_provider_api_keys', encryptValue(JSON.stringify(cleaned)));
}

function getScopedSettingRow(userId, agentId, key) {
  const scopedAgentId = resolveAgentId(userId, agentId);
  if (!scopedAgentId) return null;
  return db.prepare(
    'SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?'
  ).get(userId, scopedAgentId, key);
}

function ensureDefaultAiSettings(userId, agentId = null) {
  if (!userId) return createDefaultAiSettings();
  const scopedAgentId = resolveAgentId(userId, agentId);
  if (!scopedAgentId) return createDefaultAiSettings();

  const existing = db.prepare(
    `SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key IN (${AI_SETTING_PLACEHOLDERS})`
  ).all(
    userId,
    scopedAgentId,
    ...AI_SETTING_KEYS
  );

  const seen = new Set(existing.map((row) => row.key));
  const insert = db.prepare(
    'INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, agent_id, key) DO NOTHING'
  );

  for (const [key, value] of Object.entries(createDefaultAiSettings())) {
    if (!seen.has(key)) {
      const legacy = isMainAgent(userId, scopedAgentId)
        ? db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
          .get(userId, key)
        : null;
      insert.run(userId, scopedAgentId, key, legacy?.value ?? JSON.stringify(value));
    }
  }

  return getAiSettings(userId, scopedAgentId);
}

function getAiSettings(userId, agentId = null) {
  if (!userId) return createDefaultAiSettings();
  const scopedAgentId = resolveAgentId(userId, agentId);
  if (!scopedAgentId) return createDefaultAiSettings();

  const rows = db.prepare(
    `SELECT key, value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key IN (${AI_SETTING_PLACEHOLDERS})`
  ).all(
    userId,
    scopedAgentId,
    ...AI_SETTING_KEYS
  );

  const settings = createDefaultAiSettings();
  const missing = new Set(Object.keys(settings));
  for (const row of rows) {
    settings[row.key] = parseSettingValue(row.value);
    missing.delete(row.key);
  }
  for (const key of missing) {
    const legacy = isMainAgent(userId, scopedAgentId)
      ? db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
        .get(userId, key)
      : null;
    if (legacy) settings[key] = parseSettingValue(legacy.value);
  }

  settings.chat_history_window = Math.max(6, Math.min(Number(settings.chat_history_window) || DEFAULT_AI_SETTINGS.chat_history_window, 40));
  settings.tool_replay_budget_chars = Math.max(1200, Math.min(Number(settings.tool_replay_budget_chars) || DEFAULT_AI_SETTINGS.tool_replay_budget_chars, 12000));
  settings.subagent_max_iterations = Math.max(2, Math.min(Number(settings.subagent_max_iterations) || DEFAULT_AI_SETTINGS.subagent_max_iterations, 12));
  settings.cost_mode = typeof settings.cost_mode === 'string' ? settings.cost_mode : DEFAULT_AI_SETTINGS.cost_mode;
  settings.assistant_behavior_notes = typeof settings.assistant_behavior_notes === 'string'
    ? settings.assistant_behavior_notes
    : DEFAULT_AI_SETTINGS.assistant_behavior_notes;
  settings.auto_skill_learning = settings.auto_skill_learning !== false && settings.auto_skill_learning !== 'false';
  settings.auto_recording_insights = settings.auto_recording_insights !== false && settings.auto_recording_insights !== 'false';
  settings.smarter_model_selector = settings.smarter_model_selector !== false && settings.smarter_model_selector !== 'false';
  settings.fallback_model_id = typeof settings.fallback_model_id === 'string' ? settings.fallback_model_id : DEFAULT_AI_SETTINGS.fallback_model_id;
  settings.enabled_models = Array.isArray(settings.enabled_models) ? settings.enabled_models : DEFAULT_AI_SETTINGS.enabled_models;
  settings.default_chat_model = typeof settings.default_chat_model === 'string' && settings.default_chat_model.trim()
    ? settings.default_chat_model
    : DEFAULT_AI_SETTINGS.default_chat_model;
  settings.default_subagent_model = typeof settings.default_subagent_model === 'string' && settings.default_subagent_model.trim()
    ? settings.default_subagent_model
    : DEFAULT_AI_SETTINGS.default_subagent_model;
  settings.default_speech_model = typeof settings.default_speech_model === 'string' && settings.default_speech_model.trim()
    ? settings.default_speech_model.trim()
    : DEFAULT_AI_SETTINGS.default_speech_model;
  settings.voice_runtime_mode = normalizeRuntimeMode(settings.voice_runtime_mode);
  settings.voice_live_provider = normalizeLiveProvider(settings.voice_live_provider);
  settings.voice_live_model = resolveLiveModel(settings.voice_live_provider, settings.voice_live_model);
  settings.voice_live_voice = resolveLiveVoice(settings.voice_live_provider, settings.voice_live_voice);
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
  getProviderSecrets,
  normalizeProviderConfigs
};
