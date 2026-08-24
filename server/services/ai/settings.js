const db = require('../../db/database');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const {
  normalizeInputMode,
  normalizeMediaMode,
} = require('../voice/voice_config');
const {
  normalizeSttProvider,
  normalizeTtsProvider,
  resolveSttModel,
  resolveTtsModel,
  resolveTtsVoice,
} = require('../voice/providers');
const { AI_PROVIDER_DEFINITIONS } = require('./provider_definitions');

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
    tool_replay_budget_file_chars: null,
    tool_replay_budget_browser_chars: null,
    tool_replay_budget_command_chars: null,
    max_iterations: null,
    max_consecutive_read_only_iterations: null,
    max_consecutive_tool_failures: null,
    max_model_failure_recoveries: null,
    compaction_threshold: null,
    subagent_max_iterations: 6,
    subagent_max_children_per_run: 10,
    assistant_behavior_notes: '',
    auto_skill_learning: true,
    fallback_model_id: 'openai::gpt-5-nano',
    smarter_model_selector: true,
    enabled_models: [],
    default_chat_model: 'auto',
    default_subagent_model: 'auto',
    default_speech_model: 'auto',
    ai_provider_configs: createDefaultProviderConfigs(),
    voice_stt_provider: 'openai',
    voice_stt_model: 'gpt-live-transcribe',
    voice_tts_provider: 'openai',
    voice_tts_model: 'gpt-4o-mini-tts',
    voice_tts_voice: 'marin',
    voice_media_mode: 'auto',
    voice_input_mode: 'ptt',
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

function normalizeOptionalNumber(value, min, max, { integer = false } = {}) {
  if (value == null || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  const normalized = integer ? Math.floor(parsed) : parsed;
  return Math.min(Math.max(normalized, min), max);
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
  settings.tool_replay_budget_file_chars = normalizeOptionalNumber(settings.tool_replay_budget_file_chars, 500, 500_000, { integer: true });
  settings.tool_replay_budget_browser_chars = normalizeOptionalNumber(settings.tool_replay_budget_browser_chars, 500, 500_000, { integer: true });
  settings.tool_replay_budget_command_chars = normalizeOptionalNumber(settings.tool_replay_budget_command_chars, 500, 500_000, { integer: true });
  settings.max_iterations = normalizeOptionalNumber(settings.max_iterations, 1, 400, { integer: true });
  settings.max_consecutive_read_only_iterations = normalizeOptionalNumber(settings.max_consecutive_read_only_iterations, 3, 25, { integer: true });
  settings.max_consecutive_tool_failures = normalizeOptionalNumber(settings.max_consecutive_tool_failures, 1, 50, { integer: true });
  settings.max_model_failure_recoveries = normalizeOptionalNumber(settings.max_model_failure_recoveries, 0, 10, { integer: true });
  settings.compaction_threshold = normalizeOptionalNumber(settings.compaction_threshold, 0.1, 1);
  settings.subagent_max_iterations = Math.max(2, Math.min(Number(settings.subagent_max_iterations) || DEFAULT_AI_SETTINGS.subagent_max_iterations, 12));
  settings.subagent_max_children_per_run = Math.max(
    1,
    Math.min(
      Number(settings.subagent_max_children_per_run) || DEFAULT_AI_SETTINGS.subagent_max_children_per_run,
      20,
    ),
  );
  settings.cost_mode = typeof settings.cost_mode === 'string' ? settings.cost_mode : DEFAULT_AI_SETTINGS.cost_mode;
  settings.assistant_behavior_notes = typeof settings.assistant_behavior_notes === 'string'
    ? settings.assistant_behavior_notes
    : DEFAULT_AI_SETTINGS.assistant_behavior_notes;
  settings.auto_skill_learning = settings.auto_skill_learning !== false && settings.auto_skill_learning !== 'false';
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
  settings.voice_stt_provider = normalizeSttProvider(settings.voice_stt_provider);
  settings.voice_stt_model = resolveSttModel(settings.voice_stt_provider, settings.voice_stt_model);
  settings.voice_tts_provider = normalizeTtsProvider(settings.voice_tts_provider);
  settings.voice_tts_model = resolveTtsModel(settings.voice_tts_provider, settings.voice_tts_model);
  settings.voice_tts_voice = resolveTtsVoice(settings.voice_tts_provider, settings.voice_tts_voice);
  settings.voice_media_mode = normalizeMediaMode(settings.voice_media_mode);
  settings.voice_input_mode = normalizeInputMode(settings.voice_input_mode);
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
