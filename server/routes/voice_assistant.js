const express = require('express');

const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { synthesizeAssistantSpeech } = require('../services/voice/assistantSpeech');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');
const { buildAgentRunContext } = require('./_helpers/agentRunContext');
const { TurnCoordinator } = require('../services/voice/turnCoordinator');

const router = express.Router();
const turnCoordinator = new TurnCoordinator();

router.use(requireAuth);

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

router.post('/respond', async (req, res) => {
  try {
    const userId = req.session.userId;
    const recordingManager = req.app?.locals?.recordingManager;
    const agentEngine = req.app?.locals?.agentEngine;
    const memoryManager = req.app?.locals?.memoryManager;
    if (!recordingManager || !agentEngine || !memoryManager) {
      return res.status(500).json({ error: 'Voice assistant service is not initialized.' });
    }

    const sessionId = String(req.body?.sessionId || '').trim();
    if (!sessionId) {
      return res.status(400).json({ error: 'sessionId is required.' });
    }

    const ttsVoice = String(req.body?.ttsVoice || 'alloy').trim() || 'alloy';
    const ttsModel = String(req.body?.ttsModel || 'tts-1').trim() || 'tts-1';
    const promptHint = String(req.body?.promptHint || '').trim();

    const responsePayload = await turnCoordinator.run(sessionId, async () => {
      let session = recordingManager.getSession(userId, sessionId);
      if (session.status === 'recording') {
        session = recordingManager.finalizeSession(userId, sessionId, { stopReason: 'voice_assistant' });
      }
      if (session.status === 'processing') {
        await recordingManager.processSession(userId, sessionId);
        session = recordingManager.getSession(userId, sessionId);
      }
      if (session.status !== 'completed') {
        throw new Error(`Recording session is not ready for assistant response (status: ${session.status}).`);
      }

      const transcript = String(session.transcriptText || '').trim();
      if (!transcript) {
        throw new Error('Recording transcript is empty. Please retry transcription or record again.');
      }

      const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
      const normalizedTask = normalizeTranscriptPrompt(transcript, promptHint);
      db.prepare('INSERT INTO conversation_history (user_id, agent_id, role, content, metadata) VALUES (?, ?, ?, ?, ?)')
        .run(userId, agentId, 'user', normalizedTask, JSON.stringify({
          platform: 'voice_assistant',
          recordingSessionId: sessionId,
          transcript,
        }));

      const { priorMessages, priorSummary } = buildAgentRunContext({
        userId,
        agentId,
        task: normalizedTask,
      });
      const conversationId = memoryManager.getDefaultWebConversationId(userId, { agentId });

      const runResult = await agentEngine.run(userId, normalizedTask, {
        agentId,
        conversationId,
        priorMessages,
        priorSummary,
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
            platform: 'voice_assistant',
            recordingSessionId: sessionId,
            tokens: runResult?.totalTokens || 0,
          }),
        );

      const synthesized = await synthesizeAssistantSpeech(replyText, {
        model: ttsModel,
        voice: ttsVoice,
      });

      return {
        session,
        transcript,
        runId: runResult?.runId || null,
        replyText,
        ttsModel,
        ttsVoice,
        audioMimeType: synthesized.mimeType,
        audioBase64: synthesized.audioBytes.toString('base64'),
      };
    });

    return res.json(responsePayload);
  } catch (err) {
    const message = sanitizeError(err);
    const statusCode = /not ready|empty/i.test(message) ? 400 : 500;
    return res.status(statusCode).json({ error: message });
  }
});

module.exports = router;
