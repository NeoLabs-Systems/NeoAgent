'use strict';

const db = require('../../db/database');
const { getProviderRuntimeConfig } = require('../ai/models');
const { buildAgentRunContext } = require('../ai/runContext');
const { buildDirectVoiceContext } = require('./message');
const { analyzeVoiceAssistantScreenshot } = require('./screenshotContext');
const {
  synthesizeVoiceReply,
  normalizeVoiceSynthesisOptions,
  sanitizeSpeechText,
} = require('./providers');
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
    userId,
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
  const assistantMetadata = {
    ...persistedMetadata,
    platform,
    tokens: runResult?.totalTokens || 0,
    screenshotIncluded: Boolean(screenshotContext),
    screenshotVisionProvider: screenshotContext?.provider || null,
    screenshotVisionModel: screenshotContext?.model || null,
  };
  if (!replyText) {
    db.prepare('INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)')
      .run(
        userId,
        agentId,
        runResult?.runId || null,
        'assistant',
        '',
        JSON.stringify(assistantMetadata),
      );
    return {
      runId: runResult?.runId || null,
      transcript: transcriptText,
      replyText: '',
      ttsProvider: voiceOptions.provider,
      ttsModel: voiceOptions.model,
      ttsVoice: voiceOptions.voice,
      audioMimeType: 'audio/mpeg',
      audioBase64: '',
      ttsError: null,
    };
  }

  db.prepare('INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)')
    .run(
      userId,
      agentId,
      runResult?.runId || null,
      'assistant',
      replyText,
      JSON.stringify(assistantMetadata),
    );

  let synthesized;
  let ttsError = null;
  let providerUsed = voiceOptions.provider;
  let modelUsed = voiceOptions.model;
  let voiceUsed = voiceOptions.voice;
  if (synthesize !== false) {
    const spokenReplyText = sanitizeSpeechText(replyText);
    if (!spokenReplyText) {
      synthesized = {
        mimeType: 'audio/mpeg',
        audioBytes: Buffer.alloc(0),
      };
      ttsError = null;
    } else {
    const attemptProviders = [
      voiceOptions.provider,
      ...['openai', 'deepgram', 'gemini'].filter((provider) => provider !== voiceOptions.provider),
    ];
    let lastTtsError = null;
    for (const provider of attemptProviders) {
      const normalized = normalizeVoiceSynthesisOptions({
        provider,
        model: provider === voiceOptions.provider ? voiceOptions.model : null,
        voice: provider === voiceOptions.provider ? voiceOptions.voice : null,
      });
      const runtime = resolveProviderRuntime(userId, agentId, provider);
      try {
        synthesized = await synthesizeVoiceReply(spokenReplyText, {
          ...normalized,
          apiKey: runtime.apiKey,
          baseUrl: runtime.baseUrl,
          timeoutMs: 12000,
        });
        providerUsed = normalized.provider;
        modelUsed = normalized.model;
        voiceUsed = normalized.voice;
        ttsError = null;
        break;
      } catch (error) {
        lastTtsError = error;
      }
    }
    if (!synthesized) {
      ttsError = String(lastTtsError?.message || lastTtsError || 'Speech synthesis failed.');
      synthesized = {
        mimeType: 'audio/mpeg',
        audioBytes: Buffer.alloc(0),
      };
    }
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
    ttsProvider: providerUsed,
    ttsModel: modelUsed,
    ttsVoice: voiceUsed,
    audioMimeType: synthesized.mimeType,
    audioBase64: synthesized.audioBytes.toString('base64'),
    ttsError,
  };
}

function resolveProviderRuntime(userId, agentId, provider) {
  const providerId = String(provider || '').trim().toLowerCase() === 'gemini'
    ? 'google'
    : String(provider || '').trim().toLowerCase();
  if (!providerId || providerId === 'deepgram') {
    return { apiKey: '', baseUrl: '' };
  }
  try {
    const runtime = getProviderRuntimeConfig(userId, providerId, agentId);
    return {
      apiKey: typeof runtime.apiKey === 'string' ? runtime.apiKey.trim() : '',
      baseUrl: typeof runtime.baseUrl === 'string' ? runtime.baseUrl.trim() : '',
    };
  } catch {
    return { apiKey: '', baseUrl: '' };
  }
}

module.exports = {
  runVoiceTranscriptTurn,
};
