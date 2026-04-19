'use strict';

const db = require('../../db/database');
const { getProviderRuntimeConfig } = require('../ai/models');
const { buildAgentRunContext } = require('../ai/runContext');
const { buildDirectVoiceContext } = require('./message');
const { analyzeVoiceAssistantScreenshot } = require('./screenshotContext');
const { synthesizeVoiceReply, normalizeVoiceSynthesisOptions } = require('./providers');
const {
  VOICE_HISTORY_WINDOW,
  buildDirectVoiceRunOptions,
} = require('./runtime');

async function runVoiceTranscriptTurn({
  userId,
  agentId,
  transcript,
  promptHint = '',
  platform = 'voice_assistant',
  metadata = null,
  agentEngine,
  memoryManager,
  ttsProvider = 'openai',
  ttsModel = 'gpt-4o-mini-tts',
  ttsVoice = 'alloy',
  synthesize = true,
  allowInterimUpdates = false,
  voiceSessionId = null,
  runId = null,
}) {
  if (!agentEngine || !memoryManager) {
    throw new Error('Voice turn service is not initialized.');
  }

  const transcriptText = String(transcript || '').trim();
  if (!transcriptText) {
    throw new Error('Voice transcript is empty.');
  }

  const voiceOptions = normalizeVoiceSynthesisOptions({
    provider: ttsProvider,
    model: ttsModel,
    voice: ttsVoice,
  });
  const ttsProviderId = voiceOptions.provider === 'gemini'
    ? 'google'
    : voiceOptions.provider;
  let ttsRuntime = { apiKey: '', baseUrl: '' };
  if (ttsProviderId !== 'deepgram') {
    try {
      const runtime = getProviderRuntimeConfig(userId, ttsProviderId, agentId);
      ttsRuntime = {
        apiKey: typeof runtime.apiKey === 'string' ? runtime.apiKey.trim() : '',
        baseUrl: typeof runtime.baseUrl === 'string' ? runtime.baseUrl.trim() : '',
      };
    } catch {
      ttsRuntime = { apiKey: '', baseUrl: '' };
    }
  }

  const storedUserContent = transcriptText;
  const normalizedMetadata = metadata && typeof metadata === 'object' ? metadata : {};
  const screenshotBase64 = String(normalizedMetadata.screenshotBase64 || '').trim();
  const screenshotMimeType = String(
    normalizedMetadata.screenshotMimeType || 'image/jpeg',
  ).trim();
  const persistedMetadata = { ...normalizedMetadata };
  delete persistedMetadata.screenshotBase64;
  let screenshotContext = null;
  if (screenshotBase64) {
    screenshotContext = await analyzeVoiceAssistantScreenshot({
      userId,
      agentId,
      screenshotBase64,
      screenshotMimeType,
    });
  }
  const directVoiceContext = buildDirectVoiceContext({
    promptHint,
    platform,
    allowInterimUpdates,
    screenSummary: screenshotContext?.description || '',
  });

  db.prepare('INSERT INTO conversation_history (user_id, agent_id, role, content, metadata) VALUES (?, ?, ?, ?, ?)')
    .run(userId, agentId, 'user', storedUserContent, JSON.stringify({
      platform,
      transcript: transcriptText,
      promptHint,
      screenshotIncluded: Boolean(screenshotContext),
      screenshotVisionProvider: screenshotContext?.provider || null,
      screenshotVisionModel: screenshotContext?.model || null,
      ...persistedMetadata,
    }));

  const { priorMessages, priorSummary } = buildAgentRunContext({
    userId,
    agentId,
    task: storedUserContent,
    historyWindow: VOICE_HISTORY_WINDOW,
  });
  const conversationId = memoryManager.getDefaultWebConversationId(userId, { agentId });
  const runOptions = buildDirectVoiceRunOptions({
    agentId,
    conversationId,
    platform,
  });

  const runResult = await agentEngine.run(userId, storedUserContent, {
    runId,
    ...runOptions,
    priorMessages,
    priorSummary,
    voiceSessionId,
    context: {
      rawUserMessage: storedUserContent,
      additionalContext: directVoiceContext,
      voiceMode: true,
    },
  });

  const replyText = String(runResult?.content || '').trim();
  if (!replyText) {
    throw new Error('Agent returned an empty voice reply.');
  }

  db.prepare('INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)')
    .run(
      userId,
      agentId,
      runResult?.runId || null,
      'assistant',
      replyText,
      JSON.stringify({
        ...persistedMetadata,
        platform,
        tokens: runResult?.totalTokens || 0,
        screenshotIncluded: Boolean(screenshotContext),
        screenshotVisionProvider: screenshotContext?.provider || null,
        screenshotVisionModel: screenshotContext?.model || null,
      }),
    );

  let synthesized;
  let ttsError = null;
  if (synthesize !== false) {
    try {
      synthesized = await synthesizeVoiceReply(replyText, {
        ...voiceOptions,
        apiKey: ttsRuntime.apiKey,
        baseUrl: ttsRuntime.baseUrl,
      });
    } catch (error) {
      ttsError = String(error?.message || error || 'Speech synthesis failed.');
      synthesized = {
        mimeType: 'audio/mpeg',
        audioBytes: Buffer.alloc(0),
      };
    }
  } else {
    synthesized = {
      mimeType: 'audio/mpeg',
      audioBytes: Buffer.alloc(0),
    };
  }

  return {
    runId: runResult?.runId || null,
    transcript: transcriptText,
    replyText,
    ttsProvider: voiceOptions.provider,
    ttsModel: voiceOptions.model,
    ttsVoice: voiceOptions.voice,
    audioMimeType: synthesized.mimeType,
    audioBase64: synthesized.audioBytes.toString('base64'),
    ttsError,
  };
}

module.exports = {
  runVoiceTranscriptTurn,
};
