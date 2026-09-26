'use strict';

const db = require('../../db/database');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const { normalizeSttProvider, resolveSttModel } = require('./providers');
const {
  normalizeInputMode,
  normalizeLiveProvider,
  resolveLiveModel,
  resolveLiveVoice,
} = require('./live/catalog');

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

// Transcription (voice notes, dictation) and the live voice model are separate
// concerns that share one per-agent settings scope.
function getVoiceRuntimeSettings(userId, agentId = null) {
  const scopedAgentId = resolveAgentId(userId, agentId);
  const read = (key) => readScopedSetting(userId, scopedAgentId, key);
  const sttProvider = normalizeSttProvider(read('voice_stt_provider'));
  const liveProvider = normalizeLiveProvider(read('voice_live_provider'));
  return {
    sttProvider,
    sttModel: resolveSttModel(sttProvider, read('voice_stt_model')),
    liveProvider,
    liveModel: resolveLiveModel(liveProvider, read('voice_live_model')),
    liveVoice: resolveLiveVoice(liveProvider, read('voice_live_voice')),
    inputMode: normalizeInputMode(read('voice_input_mode')),
  };
}

module.exports = {
  getVoiceRuntimeSettings,
};
