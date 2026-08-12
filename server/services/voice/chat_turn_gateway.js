'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');
const { buildAgentRunContext } = require('../ai/runContext');
const { buildVoiceRunContext } = require('./voice_context');

const CONTROL_SYSTEM_PROMPT = `Classify a spoken follow-up to an active agent run.
Return JSON with action as exactly steer, status, or cancel.
Use cancel only when the caller clearly wants the underlying task stopped.
Use status when they are asking what is happening without changing the task.
Use steer for corrections, additions, or changed instructions.
Do not use phrase matching. Interpret the request in its conversational context.
Write one short spoken reply for the chosen action. Ground status only in the supplied progress ledger. For steer or cancel, confirm only what was actually queued or stopped.`;

function insertHistory({ userId, agentId, runId = null, role, content, metadata }) {
  db.prepare(
    `INSERT INTO conversation_history
      (user_id, agent_id, agent_run_id, role, content, metadata)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(userId, agentId, runId, role, content, JSON.stringify(metadata || {}));
}

class ChatTurnGateway {
  constructor({ agentEngine, memoryManager }) {
    this.agentEngine = agentEngine;
    this.memoryManager = memoryManager;
  }

  async submitTurn(session, transcript, options = {}) {
    const content = String(transcript || '').trim();
    if (!content) throw new Error('Voice transcript is empty.');
    const turnId = String(options.turnId || session.activeTurnId || randomUUID()).trim();
    session.currentTurnId = turnId;
    const messageId = String(options.messageId || randomUUID()).trim();
    const binding = {
      sessionId: session.id,
      turnId,
      messageId,
      mediaMode: session.voiceSettings?.mediaMode || 'composed',
    };

    await session.publishTranscriptFinal(content, binding);
    const active = this.#activeRun(session);
    if (active) {
      return this.#controlActiveRun(session, active, content, binding);
    }
    return this.#startRun(session, content, binding, options);
  }

  #activeRun(session) {
    if (!session.currentRunId) return null;
    const meta = this.agentEngine.getRunMeta?.(session.currentRunId);
    if (!meta || meta.aborted || meta.status !== 'running') return null;
    return { runId: session.currentRunId, ...meta };
  }

  async #controlActiveRun(session, active, content, binding) {
    const progressLedger = this.agentEngine.buildProgressLedgerSnapshot?.(active) || {};
    await session.setState('working', { runId: active.runId, turnId: binding.turnId });
    await session.runtimeManager.deliveryPresenter.flush(session);
    const decision = await this.agentEngine.inferStructured({
      userId: session.userId,
      agentId: session.agentId,
      purpose: 'fast',
      system: CONTROL_SYSTEM_PROMPT,
      prompt: JSON.stringify({ request: content, progressLedger }),
      maxTokens: 220,
      fallback: { action: 'steer', spoken_reply: '' },
    });
    const value = decision?.parsed || decision?.value || decision || {};
    const action = ['steer', 'status', 'cancel'].includes(value.action)
      ? value.action
      : 'steer';
    insertHistory({
      userId: session.userId,
      agentId: session.agentId,
      runId: active.runId,
      role: 'user',
      content,
      metadata: { platform: 'voice_live', ...binding, controlAction: action },
    });

    if (action === 'cancel') {
      this.agentEngine.abort(active.runId, {
        userId: session.userId,
        reason: 'voice_user_cancelled',
      });
      const reply = String(value.spoken_reply || '').trim();
      await this.#presentComposedControl(session, reply, binding, active.runId);
      return { action, runId: active.runId, content: reply };
    }
    if (action === 'status') {
      const reply = String(value.spoken_reply || '').trim();
      await this.#presentComposedControl(session, reply, binding, active.runId);
      return { action, runId: active.runId, content: reply };
    }

    this.agentEngine.enqueueSteering(active.runId, content, {
      platform: 'voice_live',
      sessionId: session.id,
      turnId: binding.turnId,
      messageId: binding.messageId,
    });
    const reply = String(value.spoken_reply || '').trim();
    await this.#presentComposedControl(session, reply, binding, active.runId);
    return { action, runId: active.runId, content: reply };
  }

  async #presentComposedControl(session, reply, binding, runId) {
    if (!reply || session.voiceSettings?.mediaMode === 'duplex') return;
    await session.runtimeManager.presentControlReply(session, reply, {
      ...binding,
      runId,
    });
  }

  async #startRun(session, content, binding, options) {
    const runId = randomUUID();
    session.currentRunId = runId;
    session.lastRunId = runId;
    await session.setState('triaging', { ...binding, runId });
    await session.runtimeManager.deliveryPresenter.flush(session);
    insertHistory({
      userId: session.userId,
      agentId: session.agentId,
      role: 'user',
      content,
      metadata: { platform: 'voice_live', transcript: content, ...binding },
    });
    const { priorMessages, priorSummary } = buildAgentRunContext({
      userId: session.userId,
      agentId: session.agentId,
      task: content,
    });
    const conversationId = session.originConversationId
      || this.memoryManager.getDefaultWebConversationId(
        session.userId,
        { agentId: session.agentId },
      );

    try {
      const result = await this.agentEngine.run(session.userId, content, {
        runId,
        agentId: session.agentId,
        conversationId,
        triggerSource: 'voice_live',
        source: 'voice_live',
        chatId: session.id,
        voiceSessionId: session.id,
        sessionBinding: { sessionId: session.id, turnId: binding.turnId },
        latencyPriority: 'interactive',
        latencyProfile: 'voice',
        maxSilenceSeconds: 45,
        priorMessages,
        priorSummary,
        context: {
          rawUserMessage: content,
          voiceMode: true,
          latencyPriority: 'interactive',
          additionalContext: buildVoiceRunContext({
            promptHint: options.promptHint,
          }),
        },
      });
      const reply = String(result?.content || '').trim();
      if (result?.status === 'completed' && reply) {
        insertHistory({
          userId: session.userId,
          agentId: session.agentId,
          runId: result?.runId || runId,
          role: 'assistant',
          content: reply,
          metadata: {
            platform: 'voice_live',
            tokens: result?.totalTokens || 0,
            ...binding,
          },
        });
      }
      return { ...result, replyText: reply, action: 'run' };
    } finally {
      if (session.currentRunId === runId) session.currentRunId = null;
      session.runtimeManager.releaseDetachedSession(session);
    }
  }
}

module.exports = {
  ChatTurnGateway,
};
