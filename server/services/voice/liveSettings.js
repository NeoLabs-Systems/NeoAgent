'use strict';

const db = require('../../db/database');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const {
  normalizeTtsProvider,
  resolveSttModel,
  resolveTtsModel,
  resolveTtsVoice,
} = require('./providers');

const DEFAULT_VOICE_RUNTIME_MODE = 'live';
const DEFAULT_VOICE_LIVE_PROVIDER = 'openai';
const DEFAULT_VOICE_LIVE_MODEL_BY_PROVIDER = Object.freeze({
  openai: 'gpt-realtime-1.5',
  gemini: 'gemini-live-2.5-flash-preview',
});
const DEFAULT_VOICE_LIVE_VOICE_BY_PROVIDER = Object.freeze({
  openai: 'alloy',
  gemini: 'Kore',
});

function parseSettingValue(value, fallback = '') {
  if (value == null) return fallback;
  if (typeof value !== 'string') return value;
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function readScopedSetting(userId, agentId, key) {
  const row = db.prepare(
    'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?'
  ).get(userId, agentId, key);
  if (row) return parseSettingValue(row.value, '');
  if (!isMainAgent(userId, agentId)) return '';
  const userRow = db.prepare(
    'SELECT value FROM user_settings WHERE user_id = ? AND key = ?'
  ).get(userId, key);
  return parseSettingValue(userRow?.value, '');
}

function normalizeRuntimeMode(value) {
  return String(value || '').trim().toLowerCase() === 'legacy' ? 'legacy' : 'live';
}

function normalizeLiveProvider(value) {
  return String(value || '').trim().toLowerCase() === 'gemini' ? 'gemini' : 'openai';
}

function resolveLiveModel(provider, requestedModel) {
  const value = String(requestedModel || '').trim();
  return value || DEFAULT_VOICE_LIVE_MODEL_BY_PROVIDER[provider] || DEFAULT_VOICE_LIVE_MODEL_BY_PROVIDER.openai;
}

function resolveLiveVoice(provider, requestedVoice) {
  const value = String(requestedVoice || '').trim();
  return value || DEFAULT_VOICE_LIVE_VOICE_BY_PROVIDER[provider] || DEFAULT_VOICE_LIVE_VOICE_BY_PROVIDER.openai;
}

function getVoiceRuntimeSettings(userId, agentId = null) {
  const scopedAgentId = resolveAgentId(userId, agentId);
  const runtimeMode = normalizeRuntimeMode(readScopedSetting(userId, scopedAgentId, 'voice_runtime_mode'));
  const liveProvider = normalizeLiveProvider(readScopedSetting(userId, scopedAgentId, 'voice_live_provider'));
  const liveModel = resolveLiveModel(liveProvider, readScopedSetting(userId, scopedAgentId, 'voice_live_model'));
  const liveVoice = resolveLiveVoice(liveProvider, readScopedSetting(userId, scopedAgentId, 'voice_live_voice'));
  const liveSttModel = resolveSttModel(liveProvider, '');
  const liveTtsModel = resolveTtsModel(liveProvider, '');

  const legacyTtsProvider = normalizeTtsProvider(readScopedSetting(userId, scopedAgentId, 'voice_tts_provider'));
  const legacyTtsModel = resolveTtsModel(
    legacyTtsProvider,
    readScopedSetting(userId, scopedAgentId, 'voice_tts_model'),
  );
  const legacyTtsVoice = resolveTtsVoice(
    legacyTtsProvider,
    readScopedSetting(userId, scopedAgentId, 'voice_tts_voice'),
  );

  return {
    runtimeMode,
    liveProvider,
    liveModel,
    liveVoice,
    liveSttModel,
    liveTtsModel,
    legacyTtsProvider,
    legacyTtsModel,
    legacyTtsVoice,
  };
}

module.exports = {
  DEFAULT_VOICE_LIVE_MODEL_BY_PROVIDER,
  DEFAULT_VOICE_LIVE_PROVIDER,
  DEFAULT_VOICE_LIVE_VOICE_BY_PROVIDER,
  DEFAULT_VOICE_RUNTIME_MODE,
  getVoiceRuntimeSettings,
  normalizeLiveProvider,
  normalizeRuntimeMode,
  resolveLiveModel,
  resolveLiveVoice,
};
