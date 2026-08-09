'use strict';

const SHELL_INSTRUCTIONS = `You are NeoAgent's realtime voice interface, not its task brain.
For every user question, request, correction, status query, or cancellation, call neoagent_turn exactly once with a faithful transcript.
Never answer a substantive request from your own knowledge and never claim an action completed yourself.
You may speak one short, request-specific preamble while the tool starts. Do not use a canned phrase.
After the tool returns, speak its content faithfully and naturally. Do not add facts or change the result.
Handle only audio turn-taking, interruption, and brief conversational delivery yourself.`;

const NEOAGENT_TURN_TOOL = Object.freeze({
  type: 'function',
  name: 'neoagent_turn',
  description: 'Send the caller transcript to the canonical NeoAgent chat runtime. Required for every substantive turn and every active-run control request.',
  parameters: {
    type: 'object',
    properties: {
      transcript: {
        type: 'string',
        description: 'A faithful transcript of what the caller wants NeoAgent to handle.',
      },
    },
    required: ['transcript'],
    additionalProperties: false,
  },
});

function buildRealtimeSessionUpdate(config) {
  return {
    type: 'session.update',
    session: {
      type: 'realtime',
      model: config.duplexModel,
      output_modalities: ['audio'],
      instructions: SHELL_INSTRUCTIONS,
      reasoning: { effort: 'low' },
      audio: {
        input: {
          format: { type: 'audio/pcm', rate: config.inputSampleRate },
          transcription: { model: 'gpt-live-transcribe' },
          turn_detection: config.inputMode === 'hands_free'
            ? { type: 'semantic_vad', create_response: true, interrupt_response: true }
            : null,
        },
        output: {
          format: { type: 'audio/pcm' },
          voice: config.duplexVoice,
        },
      },
      tools: [NEOAGENT_TURN_TOOL],
      tool_choice: 'required',
    },
  };
}

function parseJson(value, fallback = null) {
  try {
    return JSON.parse(String(value || ''));
  } catch {
    return fallback;
  }
}

module.exports = {
  NEOAGENT_TURN_TOOL,
  SHELL_INSTRUCTIONS,
  buildRealtimeSessionUpdate,
  parseJson,
};
