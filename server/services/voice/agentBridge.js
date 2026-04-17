'use strict';

const { randomUUID } = require('crypto');

const { runVoiceTranscriptTurn } = require('./turnRunner');

class VoiceAgentBridge {
  constructor({ agentEngine, memoryManager, runtimeManager }) {
    this.agentEngine = agentEngine;
    this.memoryManager = memoryManager;
    this.runtimeManager = runtimeManager;
  }

  async runTranscriptTurn(session, transcript, options = {}) {
    const transcriptText = String(transcript || '').trim();
    if (!transcriptText) {
      throw new Error('Voice transcript is empty.');
    }

    await session.publishTranscriptFinal(transcriptText);
    await session.setState('thinking');
    const runId = randomUUID();
    session.currentRunId = runId;

    try {
      const result = await runVoiceTranscriptTurn({
        userId: session.userId,
        agentId: session.agentId,
        transcript: transcriptText,
        promptHint: options.promptHint || '',
        platform: session.platform,
        metadata: {
          ...(options.metadata && typeof options.metadata === 'object' ? options.metadata : {}),
          voiceSessionId: session.id,
        },
        agentEngine: this.agentEngine,
        memoryManager: this.memoryManager,
        synthesize: false,
        allowInterimUpdates: true,
        voiceSessionId: session.id,
        runId,
      });
      session.currentRunId = result.runId || runId;
      if (String(result.replyText || '').trim()) {
        await this.runtimeManager.deliverAssistantMessage(session, result.replyText, {
          kind: 'final',
        });
      }
      await session.setState('idle');
      session.currentRunId = null;
      return result;
    } catch (error) {
      session.currentRunId = null;
      await session.setState('idle');
      throw error;
    }
  }
}

module.exports = {
  VoiceAgentBridge,
};
