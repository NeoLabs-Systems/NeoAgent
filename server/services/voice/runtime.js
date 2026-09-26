'use strict';

const { buildPlatformFormattingGuide } = require('../messaging/formatting_guides');
const { getAiSettings } = require('../ai/settings');
const { SENDER_IDENTITY_NOTE, buildSenderIdentityBlock } = require('../messaging/sender_identity');
const { INTENT_DICTATION } = require('./voice_note');

const VOICE_REASONING_EFFORT = 'low';
const VOICE_LATENCY_PROFILE = 'voice';

// Dictated voice notes run as spoken turns. An audio clip shared as context is
// a normal message with media attached. Live calls never come through here:
// they run on the live voice model (services/voice/live/).
function isVoiceLikeMessage(msg = {}) {
  const mediaType = String(msg.mediaType || '').trim().toLowerCase();
  return mediaType === 'audio' && msg.voiceNote?.intent === INTENT_DICTATION;
}

function buildVoiceMessagingPrompt(msg = {}) {
  const senderIdentity = buildSenderIdentityBlock(msg);
  const formattingGuide = buildPlatformFormattingGuide(msg.platform);
  const transcript = String(msg.content || '').trim();
  const channel = String(msg.platform || 'voice').trim();
  const sttError = msg.voiceNote?.sttError;

  if (sttError) {
    return [
      `You received a voice note on ${channel}, but transcribing it failed (${sttError}).`,
      senderIdentity,
      '',
      SENDER_IDENTITY_NOTE,
      `The original audio is kept at: ${msg.localMediaPath}`,
      '',
      formattingGuide,
      '',
      'Do not guess what was said. You may retry once with transcribe_audio on that path.',
      `If that does not work, reply with send_message platform="${msg.platform}" to="${msg.chatId}" asking one short question so the sender can repeat or type the request.`,
    ].join('\n');
  }

  return [
    `You received a spoken request on ${channel}.`,
    senderIdentity,
    '',
    'Transcribed speech content:',
    '<spoken_request>',
    transcript,
    '</spoken_request>',
    '',
    SENDER_IDENTITY_NOTE,
    msg.localMediaPath
      ? `The original voice note is kept at: ${msg.localMediaPath}. If the sender says it was not meant as a request, treat that clip as shared audio instead.`
      : '',
    '',
    formattingGuide,
    '',
    'Latency matters. Use full tool autonomy but move without delay.',
    `Reply with send_message platform="${msg.platform}" to="${msg.chatId}" when complete.`,
    'Match the spoken register: direct, natural sentences. Avoid bullet-heavy or markdown-heavy replies unless the platform clearly renders them.',
    'Use send_interim_update only when a real progress update or a blocking question would genuinely help.',
  ].join('\n');
}

function buildVoiceMessagingRunOptions({
  runId,
  userId,
  agentId = null,
  conversationId,
  msg,
}) {
  const aiSettings = getAiSettings(userId, agentId);
  const speechModel = String(aiSettings.default_speech_model || 'auto').trim();
  return {
    runId,
    agentId,
    model: speechModel !== 'auto' ? speechModel : null,
    triggerSource: 'messaging',
    conversationId,
    source: msg.platform,
    chatId: msg.chatId,
    context: {
      rawUserMessage: msg.content,
      voiceMode: true,
    },
    latencyProfile: VOICE_LATENCY_PROFILE,
    latencyPriority: 'interactive',
    reasoningEffort: VOICE_REASONING_EFFORT,
  };
}

module.exports = {
  VOICE_LATENCY_PROFILE,
  VOICE_REASONING_EFFORT,
  buildVoiceMessagingPrompt,
  buildVoiceMessagingRunOptions,
  isVoiceLikeMessage,
};
