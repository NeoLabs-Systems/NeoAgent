'use strict';

const db = require('../../db/database');
const { normalizeWhatsAppWhitelist } = require('../../utils/whatsapp');
const { UI_LANGUAGE_CODES } = require('../../config/ui_languages');
const { normalizeTimeZone } = require('../../utils/timezone');
const { createServiceLogger } = require('../../utils/logger');
const { ensureDefaultAiSettings, normalizeSystemOneModel } = require('../ai/settings');
const {
  ensureDefaultRuntimeSettings,
  getRuntimeSettings,
  redactRuntimeSettingValue,
  serializeRuntimeSettingValue,
  validateRuntimeSettings,
} = require('../runtime/settings');
const { isMainAgent } = require('../agents/manager');

const logger = createServiceLogger('Settings');

// Settings stored per agent rather than per account.
const AGENT_SETTING_KEYS = new Set([
  'cost_mode',
  'chat_history_window',
  'tool_replay_budget_chars',
  'tool_replay_budget_file_chars',
  'tool_replay_budget_browser_chars',
  'tool_replay_budget_command_chars',
  'max_consecutive_read_only_iterations',
  'max_consecutive_tool_failures',
  'subagent_max_children_per_run',
  'assistant_behavior_notes',
  'auto_skill_learning',
  'system_one_model',
  'neorouter_roles',
  'ai_provider_configs',
  'default_chat_model',
  'default_subagent_model',
  'default_speech_model',
  'task_models',
  'enabled_models',
  'voice_stt_provider',
  'voice_stt_model',
  'voice_live_provider',
  'voice_live_model',
  'voice_live_voice',
  'voice_input_mode',
  'last_platform',
  'last_chat_id',
]);

// Data-sharing consent is only changed through /api/account/data-sharing.
const SERVER_MANAGED_SETTING_KEYS = new Set([
  'ai_provider_configs',
  'ai_provider_api_keys',
  'usage_data_sharing',
]);

const HIDDEN_SETTING_KEYS = new Set([
  'ai_provider_api_keys',
  'usage_data_sharing',
]);

const RETIRED_SETTING_KEYS = new Set([
  'voice_tts_provider',
  'voice_tts_model',
  'voice_tts_voice',
  'voice_media_mode',
  'browser_backend',
  'browser_extension_token_id',
  'selected_browser_extension_token_id',
  'cli_backend',
  'cli_desktop_device_id',
  'desktop_backend',
  'desktop_device_id',
  'max_iterations',
  'max_model_failure_recoveries',
  'compaction_threshold',
  'subagent_max_iterations',
]);

const RUNTIME_SETTING_KEYS = [
  'runtime_profile',
  'runtime_backend',
  'computer_backend',
  'android_backend',
  'mcp_backend',
];

const LOGGED_MODEL_KEYS = ['default_chat_model', 'default_subagent_model'];

function isAgentScopedSettingKey(key) {
  return AGENT_SETTING_KEYS.has(key)
    || key.startsWith('platform_whitelist_')
    || key.startsWith('platform_access_policy_');
}

function isProtectedSecretSettingKey(key) {
  return /^social_reach_cookies_/i.test(String(key || ''));
}

function normalizeUiLanguage(value) {
  const code = String(value ?? '').trim().toLowerCase();
  return UI_LANGUAGE_CODES.has(code) ? code : null;
}

function parseStoredValue(key, raw) {
  try {
    return JSON.parse(raw);
  } catch (error) {
    if (typeof raw === 'string' && (raw.trim().startsWith('{') || raw.trim().startsWith('['))) {
      logger.warn(`Failed to parse '${key}' as JSON, treating as raw string. Error:`, error.message);
    }
    return raw;
  }
}

function readSettingValue(userId, agentId, key) {
  if (RETIRED_SETTING_KEYS.has(key) || HIDDEN_SETTING_KEYS.has(key)) return null;
  ensureDefaultRuntimeSettings(userId);
  const row = isAgentScopedSettingKey(key)
    ? (
      db.prepare('SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?').get(userId, agentId, key)
      || (isMainAgent(userId, agentId)
        ? db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, key)
        : null)
    )
    : db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?').get(userId, key);
  if (!row) return null;
  return redactRuntimeSettingValue(key, parseStoredValue(key, row.value));
}

// Validates and normalizes a settings patch. Keys nobody may write through
// this path are dropped; a value that cannot be accepted rejects the patch.
function normalizeSettingsPatch(userId, patch) {
  const normalized = { ...patch };
  for (const key of Object.keys(normalized)) {
    if (
      RETIRED_SETTING_KEYS.has(key)
      || SERVER_MANAGED_SETTING_KEYS.has(key)
      || isProtectedSecretSettingKey(key)
    ) {
      delete normalized[key];
    }
  }

  if ('timezone' in normalized) {
    const timeZone = normalizeTimeZone(normalized.timezone);
    if (!timeZone) return { ok: false, error: 'Unknown time zone.' };
    normalized.timezone = timeZone;
  }

  if ('ui_language' in normalized) {
    const language = normalizeUiLanguage(normalized.ui_language);
    if (!language) return { ok: false, error: 'Unknown language.' };
    normalized.ui_language = language;
  }

  if (
    'system_one_model' in normalized
    && normalizeSystemOneModel(normalized.system_one_model) !== normalized.system_one_model
  ) {
    return { ok: false, error: 'Unknown SystemOne model selection.' };
  }

  if ('platform_whitelist_whatsapp' in normalized) {
    let whitelist = normalized.platform_whitelist_whatsapp;
    if (typeof whitelist === 'string') {
      try {
        whitelist = JSON.parse(whitelist);
      } catch {
        whitelist = [];
      }
    }
    normalized.platform_whitelist_whatsapp = JSON.stringify(normalizeWhatsAppWhitelist(whitelist));
  }

  if (RUNTIME_SETTING_KEYS.some((key) => key in normalized)) {
    const validation = validateRuntimeSettings({
      ...getRuntimeSettings(userId),
      ...normalized,
    });
    if (!validation.valid) {
      return { ok: false, error: validation.issues[0], issues: validation.issues };
    }
    Object.assign(normalized, validation.settings);
  }

  return { ok: true, settings: normalized };
}

function logModelChanges(userId, agentId, settings, source) {
  const previousRows = db.prepare(
    `SELECT key, value FROM agent_settings
     WHERE user_id = ? AND agent_id = ? AND key IN ('default_chat_model', 'default_subagent_model')`,
  ).all(userId, agentId);
  for (const key of LOGGED_MODEL_KEYS) {
    if (!(key in settings)) continue;
    const stored = previousRows.find((row) => row.key === key)?.value ?? null;
    let previous = stored;
    try { previous = JSON.parse(stored); } catch {}
    if (previous !== settings[key]) {
      logger.info(`user=${userId} agent=${agentId} ${key}: ${previous} -> ${settings[key]} (${source})`);
    }
  }
}

// The prompt clock and recurring task schedules both follow the user's time zone.
function applySettingsSideEffects(userId, agentId, settings, taskRuntime) {
  const promptChanged = 'assistant_behavior_notes' in settings || 'timezone' in settings;
  if (promptChanged) {
    const { invalidateSystemPromptCache } = require('../ai/systemPrompt');
    invalidateSystemPromptCache(userId, agentId);
  }
  if ('timezone' in settings && taskRuntime) {
    taskRuntime.rescheduleUserTasks(userId).catch((error) => {
      logger.error('Rescheduling tasks after time zone change failed:', error.message);
    });
  }
}

/**
 * Validates and saves a settings patch for one user and agent. Every writer —
 * the settings API and the assistant's own settings tool — goes through here,
 * so a value is accepted or refused the same way wherever it comes from.
 */
function applySettingsUpdate({ userId, agentId, patch, taskRuntime = null, source = 'unknown' }) {
  ensureDefaultAiSettings(userId, agentId);
  ensureDefaultRuntimeSettings(userId);
  const result = normalizeSettingsPatch(userId, patch);
  if (!result.ok) return result;
  const { settings } = result;

  logModelChanges(userId, agentId, settings, source);

  const upsert = db.prepare('INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value');
  const upsertAgent = db.prepare('INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value');
  db.transaction((entries) => {
    for (const [key, value] of entries) {
      const serialized = serializeRuntimeSettingValue(key, value);
      if (isAgentScopedSettingKey(key)) {
        upsertAgent.run(userId, agentId, key, serialized);
      } else if (key !== 'agentId' && key !== 'agent_id') {
        upsert.run(userId, key, serialized);
      }
    }
  })(Object.entries(settings));

  applySettingsSideEffects(userId, agentId, settings, taskRuntime);
  return { ok: true, settings };
}

module.exports = {
  HIDDEN_SETTING_KEYS,
  RETIRED_SETTING_KEYS,
  SERVER_MANAGED_SETTING_KEYS,
  applySettingsSideEffects,
  applySettingsUpdate,
  isAgentScopedSettingKey,
  isProtectedSecretSettingKey,
  parseStoredValue,
  readSettingValue,
};
