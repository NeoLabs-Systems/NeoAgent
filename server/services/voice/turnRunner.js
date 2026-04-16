'use strict';

const db = require('../../db/database');
const { ensureDefaultAiSettings, getAiSettings } = require('../ai/settings');
const { getWebChatContext } = require('../ai/history');
const { synthesizeVoiceReply, normalizeTtsProvider } = require('./providers');

const VOICE_HISTORY_WINDOW = 4;

function buildAgentRunContext({ userId, agentId, task, historyWindow = VOICE_HISTORY_WINDOW }) {
  ensureDefaultAiSettings(userId, agentId);
  const aiSettings = getAiSettings(userId, agentId);
  const effectiveWindow = Math.max(1, Math.min(aiSettings.chat_history_window, historyWindow));
  const webContext = getWebChatContext(userId, effectiveWindow, { agentId });

  const lastMatchIndex = webContext.recentMessages.findLastIndex(
    (message) => message.role === 'user' && message.content === task,
  );
  const priorMessages = webContext.recentMessages
    .filter((_, index) => index !== lastMatchIndex)
    .slice(-effectiveWindow);

  return {
    priorMessages,
    priorSummary: webContext.summary,
  };
}

function normalizeTranscriptPrompt(text, promptHint) {
  const transcript = String(text || '').trim();
  const hint = String(promptHint || '').trim();
  if (!hint) return transcript;
  return [
    'Voice request transcript:',
    transcript,
    '',
    `Extra instruction for this turn: ${hint}`,
  ].join('\n');
}

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
}) {
  if (!agentEngine || !memoryManager) {
    throw new Error('Voice turn service is not initialized.');
  }

  const transcriptText = String(transcript || '').trim();
  if (!transcriptText) {
    throw new Error('Voice transcript is empty.');
  }

  const normalizedTask = normalizeTranscriptPrompt(transcriptText, promptHint);
  const normalizedMetadata = metadata && typeof metadata === 'object' ? metadata : {};

  db.prepare('INSERT INTO conversation_history (user_id, agent_id, role, content, metadata) VALUES (?, ?, ?, ?, ?)')
    .run(userId, agentId, 'user', normalizedTask, JSON.stringify({
      platform,
      transcript: transcriptText,
      ...normalizedMetadata,
    }));

  const { priorMessages, priorSummary } = buildAgentRunContext({
    userId,
    agentId,
    task: normalizedTask,
    historyWindow: VOICE_HISTORY_WINDOW,
  });
  const conversationId = memoryManager.getDefaultWebConversationId(userId, { agentId });

  const runResult = await agentEngine.run(userId, normalizedTask, {
    agentId,
    conversationId,
    priorMessages,
    priorSummary,
    skipConversationHistory: true,
    skipTaskAnalysis: true,
    triggerSource: 'voice_assistant',
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
        platform,
        tokens: runResult?.totalTokens || 0,
        ...normalizedMetadata,
      }),
    );

  let synthesized;
  let ttsError = null;
  try {
    synthesized = await synthesizeVoiceReply(replyText, {
      provider: normalizeTtsProvider(ttsProvider),
      model: ttsModel,
      voice: ttsVoice,
    });
  } catch (error) {
    ttsError = String(error?.message || error || 'Speech synthesis failed.');
    synthesized = {
      mimeType: 'audio/mpeg',
      audioBytes: Buffer.alloc(0),
    };
  }

  return {
    runId: runResult?.runId || null,
    transcript: transcriptText,
    replyText,
    ttsProvider: normalizeTtsProvider(ttsProvider),
    ttsModel,
    ttsVoice,
    audioMimeType: synthesized.mimeType,
    audioBase64: synthesized.audioBytes.toString('base64'),
    ttsError,
  };
}

module.exports = {
  normalizeTranscriptPrompt,
  runVoiceTranscriptTurn,
};
