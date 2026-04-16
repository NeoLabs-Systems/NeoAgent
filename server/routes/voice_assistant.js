const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');
const { TurnCoordinator } = require('../services/voice/turnCoordinator');
const { runVoiceTranscriptTurn } = require('../services/voice/turnRunner');

const router = express.Router();
const turnCoordinator = new TurnCoordinator();

router.use(requireAuth);

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
    const ttsModel = String(req.body?.ttsModel || 'gpt-4o-mini-tts').trim() || 'gpt-4o-mini-tts';
    const ttsProvider = String(req.body?.ttsProvider || 'openai').trim() || 'openai';
    const promptHint = String(req.body?.promptHint || '').trim();
    const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));

    const responsePayload = await turnCoordinator.run(sessionId, async () => {
      let session = recordingManager.getSession(userId, sessionId);
      if (session.status === 'recording') {
        session = recordingManager.finalizeSession(userId, sessionId, {
          stopReason: 'voice_assistant',
          autoProcess: false,
          includeInsights: false,
        });
      }
      if (session.status === 'processing') {
        await recordingManager.processSession(userId, sessionId, {
          includeInsights: false,
        });
        session = recordingManager.getSession(userId, sessionId);
      }
      if (session.status !== 'completed') {
        throw new Error(`Recording session is not ready for assistant response (status: ${session.status}).`);
      }

      const transcript = String(session.transcriptText || '').trim();
      if (!transcript) {
        throw new Error('Recording transcript is empty. Please retry transcription or record again.');
      }

      const turnResult = await runVoiceTranscriptTurn({
        userId,
        agentId,
        transcript,
        promptHint,
        platform: 'voice_assistant',
        metadata: {
          recordingSessionId: sessionId,
        },
        agentEngine,
        memoryManager,
        ttsProvider,
        ttsModel,
        ttsVoice,
      });

      return {
        session,
        ...turnResult,
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
