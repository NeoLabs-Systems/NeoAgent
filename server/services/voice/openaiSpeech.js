'use strict';

const { readResponseBuffer } = require('../network/http');
const { runWithAbortTimeout } = require('../../utils/abort');

const DEFAULT_SPEECH_TIMEOUT_MS = 30000;
const DEFAULT_MAX_SPEECH_BYTES = 32 * 1024 * 1024;

async function synthesizeSpeechBuffer(
  client,
  text,
  {
    model = 'gpt-4o-mini-tts',
    voice = 'alloy',
    responseFormat = 'mp3',
    signal = null,
    timeoutMs = DEFAULT_SPEECH_TIMEOUT_MS,
    maxResponseBytes = DEFAULT_MAX_SPEECH_BYTES,
  } = {},
) {
  if (!client) {
    throw new Error('OpenAI client is not configured for speech synthesis.');
  }

  const content = String(text || '').trim();
  if (!content) {
    throw new Error('Speech input is empty; cannot synthesize audio.');
  }

  return runWithAbortTimeout(async (operationSignal) => {
    const response = await client.audio.speech.create({
      model: String(model || 'gpt-4o-mini-tts').trim() || 'gpt-4o-mini-tts',
      voice: String(voice || 'alloy').trim() || 'alloy',
      input: content,
      response_format: String(responseFormat || 'mp3').trim() || 'mp3',
    }, { signal: operationSignal });

    return readResponseBuffer(response, {
      maxResponseBytes,
      serviceName: 'OpenAI speech synthesis',
      signal: operationSignal,
      tooLargeCode: 'VOICE_PROVIDER_RESPONSE_TOO_LARGE',
    });
  }, {
    signal,
    timeoutMs,
    timeoutCode: 'VOICE_PROVIDER_TIMEOUT',
    label: 'OpenAI speech synthesis',
  });
}

module.exports = {
  synthesizeSpeechBuffer,
};
