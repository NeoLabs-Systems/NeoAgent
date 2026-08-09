'use strict';

const db = require('../../db/database');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const {
  normalizeSttProvider,
  normalizeTtsProvider,
  resolveSttModel,
  resolveTtsModel,
  resolveTtsVoice,
} = require('./providers');
const { normalizeInputMode, normalizeMediaMode } = require('./voice_config');

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
    'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?',
  ).get(userId, agentId, key);
  if (row) return parseSettingValue(row.value, '');
  if (!isMainAgent(userId, agentId)) return '';
  const userRow = db.prepare(
    'SELECT value FROM user_settings WHERE user_id = ? AND key = ?',
  ).get(userId, key);
  return parseSettingValue(userRow?.value, '');
}

function getVoiceRuntimeSettings(userId, agentId = null) {
  const scopedAgentId = resolveAgentId(userId, agentId);
  const sttProvider = normalizeSttProvider(
    readScopedSetting(userId, scopedAgentId, 'voice_stt_provider'),
  );
  const ttsProvider = normalizeTtsProvider(
    readScopedSetting(userId, scopedAgentId, 'voice_tts_provider'),
  );
  return {
    mediaMode: normalizeMediaMode(
      readScopedSetting(userId, scopedAgentId, 'voice_media_mode'),
    ),
    inputMode: normalizeInputMode(
      readScopedSetting(userId, scopedAgentId, 'voice_input_mode'),
    ),
    sttProvider,
    sttModel: resolveSttModel(
      sttProvider,
      readScopedSetting(userId, scopedAgentId, 'voice_stt_model'),
    ),
    ttsProvider,
    ttsModel: resolveTtsModel(
      ttsProvider,
      readScopedSetting(userId, scopedAgentId, 'voice_tts_model'),
    ),
    ttsVoice: resolveTtsVoice(
      ttsProvider,
      readScopedSetting(userId, scopedAgentId, 'voice_tts_voice'),
    ),
  };
}

module.exports = {
  getVoiceRuntimeSettings,
};
