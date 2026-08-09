'use strict';

class OpenAiNeoAgentBridge {
  constructor({ session, runtimeManager, send, getTurnId, isActive }) {
    this.session = session;
    this.runtimeManager = runtimeManager;
    this.send = send;
    this.getTurnId = getTurnId;
    this.isActive = isActive;
    this.inFlight = null;
  }

  captureFinal(content, options = {}) {
    if (!this.inFlight || options.kind !== 'final') return false;
    this.inFlight.finalContent = content;
    this.inFlight.messageId = options.messageId || '';
    this.inFlight.runId = options.runId || null;
    this.inFlight.turnId = options.turnId || this.inFlight.turnId;
    return true;
  }

  async handle(functionCall, transcript) {
    if (this.inFlight) return this.#handleControl(functionCall, transcript);
    const turnId = this.getTurnId();
    this.inFlight = {
      finalContent: '',
      messageId: '',
      runId: null,
      turnId,
    };
    await this.session.setState('triaging', { turnId });
    try {
      const result = await this.runtimeManager.chatTurnGateway.submitTurn(
        this.session,
        transcript,
        { turnId },
      );
      const content = String(
        this.inFlight.finalContent || result?.replyText || result?.content || '',
      ).trim();
      if (!this.isActive()) {
        this.inFlight = null;
        return;
      }
      const messageId = this.inFlight.messageId;
      const runId = this.inFlight.runId || result?.runId || null;
      const finalTurnId = this.inFlight.turnId || turnId;
      this.#publishToolOutput(functionCall.call_id, {
        runId,
        action: result?.action || 'run',
        content,
      });
      this.inFlight = null;
      if (!content) {
        await this.session.setState('working', { runId: result?.runId || null });
        return;
      }
      await this.session.setState('speaking', { runId });
      this.send({
        type: 'response.create',
        response: {
          output_modalities: ['audio'],
          tool_choice: 'none',
          metadata: {
            delivery_kind: 'final',
            message_id: messageId,
            run_id: runId,
            turn_id: finalTurnId,
          },
          instructions: 'Speak the neoagent_turn content faithfully. Do not add or omit facts.',
        },
      });
    } catch (error) {
      this.inFlight = null;
      throw error;
    }
  }

  async #handleControl(functionCall, transcript) {
    const turnId = this.getTurnId();
    const control = await this.runtimeManager.chatTurnGateway.submitTurn(
      this.session,
      transcript,
      { turnId },
    );
    const content = String(control?.content || '').trim();
    this.#publishToolOutput(functionCall.call_id, {
      runId: control?.runId || this.session.currentRunId,
      action: control?.action || 'steer',
      content,
    });
    if (content) {
      this.send({
        type: 'response.create',
        response: {
          output_modalities: ['audio'],
          tool_choice: 'none',
          metadata: {
            delivery_kind: 'control',
            run_id: control?.runId || '',
            turn_id: turnId,
          },
          instructions: 'Speak the neoagent_turn control result faithfully. Do not add facts.',
        },
      });
    }
  }

  #publishToolOutput(callId, output) {
    this.send({
      type: 'conversation.item.create',
      item: {
        type: 'function_call_output',
        call_id: callId,
        output: JSON.stringify(output),
      },
    });
  }
}

module.exports = {
  OpenAiNeoAgentBridge,
};
