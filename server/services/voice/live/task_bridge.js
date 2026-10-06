'use strict';

const { randomUUID } = require('crypto');
const { createServiceLogger } = require('../../../utils/logger');
const { sanitizeError } = require('../../../utils/security');
const { MESSAGE_KINDS } = require('../../ai/runtime/constants');

const logger = createServiceLogger('LiveVoiceTasks');
const SPOKEN_LIVENESS = new Set(['blocked', 'waiting']);

// Everything the live model hands off runs as an ordinary agent run: same
// orchestrator, tools, memory, approvals, verification, and outbox delivery as
// a chat or WhatsApp message. This bridge only maps runs to the live model's
// hand-off handles and feeds results back into the conversation.
//
// Only runs this call started are its work. The run that placed an
// agent-initiated call is not: it finishes on its own, so treating it as the
// call's task showed the call as busy and fed what the owner said into a run
// that was already wrapping up, where nothing answered it.
class LiveTaskBridge {
  constructor({ agentEngine, session }) {
    this.agentEngine = agentEngine;
    this.session = session;
    this.runs = new Map();
  }

  get activeRunId() {
    return this.#activeRunId();
  }

  get hasRunningWork() {
    return Boolean(this.#activeRunId());
  }

  delegate({ handle, request }) {
    const text = String(request || '').trim();
    const adapter = this.session.adapter;
    if (!text) {
      adapter.completeTask(handle, 'The hand-off arrived without a request. Ask the owner what they want done.');
      return;
    }
    const activeRunId = this.#activeRunId();
    if (activeRunId) {
      const queued = this.agentEngine.enqueueSteering(activeRunId, text, {
        platform: 'voice_live',
        sessionId: this.session.id,
      });
      if (queued) {
        adapter.acknowledgeTask(handle, 'Forwarded to the task that is already running; its result will follow.');
        return;
      }
    }
    this.#start(handle, text);
  }

  // Outbox deliveries for runs this session started arrive here instead of a
  // chat channel.
  present(entry) {
    const content = String(entry?.payload?.content || '').trim();
    if (!content) return;
    const record = this.runs.get(entry.runId);
    const handle = record?.handle || null;
    const adapter = this.session.adapter;
    if (entry.messageKind === MESSAGE_KINDS.FINAL) {
      if (record) record.delivered = true;
      if (handle) adapter.completeTask(handle, content);
      else adapter.say(content);
      return;
    }
    // The live model already acknowledged the hand-off in its own words.
    if (entry.messageKind === MESSAGE_KINDS.ACK) return;
    const metadata = entry.payload?.metadata || {};
    const speak = metadata.expectsReply === true
      || SPOKEN_LIVENESS.has(String(metadata.liveness?.status || ''));
    if (handle) adapter.taskProgress(handle, content, { speak });
    else if (speak) adapter.say(content);
    else adapter.note(content);
  }

  cancel() {
    const runId = this.#activeRunId();
    if (!runId) return { cancelled: false };
    this.agentEngine.abort(runId, { userId: this.session.userId, reason: 'voice_user_cancelled' });
    return { cancelled: true, runId };
  }

  abortAll(reason) {
    for (const runId of this.runs.keys()) {
      this.agentEngine.abort(runId, { userId: this.session.userId, reason });
    }
  }

  #activeRunId() {
    for (const runId of this.runs.keys()) {
      const meta = this.agentEngine.getRunMeta(runId);
      if (meta && !meta.aborted && meta.status === 'running') return runId;
    }
    return null;
  }

  #start(handle, request) {
    const session = this.session;
    const runId = randomUUID();
    this.runs.set(runId, { handle, delivered: false });
    session.publishTask({ runId, status: 'running', request });
    this.agentEngine.run(session.userId, request, {
      runId,
      agentId: session.agentId,
      conversationId: session.conversationId,
      triggerSource: 'voice_live',
      source: 'voice_live',
      chatId: session.id,
      voiceSessionId: session.id,
      latencyPriority: 'interactive',
      context: { rawUserMessage: request },
    }).then((result) => {
      this.#settle(runId, result?.status || 'completed', result?.content, null);
    }).catch((error) => {
      logger.warn('Voice task failed', { runId, error: error?.message || String(error) });
      this.#settle(runId, 'failed', '', error);
    });
  }

  #settle(runId, status, content, error) {
    const record = this.runs.get(runId);
    this.runs.delete(runId);
    this.session.publishTask({ runId, status });
    if (!record || record.delivered) {
      this.session.releaseIfIdle();
      return;
    }
    const reply = status === 'completed' ? String(content || '').trim() : '';
    const outcome = reply || [
        `The task ended with status "${status}" and produced no result for the owner.`,
        error ? `Reported error: ${sanitizeError(error)}` : '',
        content ? `Partial output: ${String(content).trim()}` : '',
      ].filter(Boolean).join('\n');
    this.session.deliverTaskOutcome({ handle: record.handle, runId, outcome, reply });
  }
}

module.exports = {
  LiveTaskBridge,
};
