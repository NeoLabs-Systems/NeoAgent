'use strict';

const fs = require('fs');
const { getOpenAiClient } = require('../openaiClient');
const { synthesizeSpeechBuffer } = require('../openaiSpeech');
const { wrapPcmAsWav } = require('../shared_audio');
const { MAX_AUDIO_BYTES } = require('./http_stream');

function clientFor(options) {
  const client = getOpenAiClient({ apiKey: options.apiKey, baseUrl: options.baseUrl });
  if (!client) throw new Error('OpenAI voice is selected but OPENAI_API_KEY is not configured.');
  return client;
}

async function transcribe(filePath, model, _mimeType, options = {}) {
  const file = fs.createReadStream(filePath);
  try {
    const result = await clientFor(options).audio.transcriptions.create({
      file,
      model: model === 'gpt-live-transcribe' ? 'gpt-transcribe' : model,
    }, { signal: options.signal });
    return String(result?.text || '').trim();
  } finally {
    file.destroy();
  }
}

async function synthesize(text, model, voice, options = {}) {
  const audioBytes = await synthesizeSpeechBuffer(clientFor(options), text, {
    model,
    voice,
    responseFormat: 'mp3',
    signal: options.signal,
    timeoutMs: options.timeoutMs,
    maxResponseBytes: MAX_AUDIO_BYTES,
  });
  return { audioBytes, mimeType: 'audio/mpeg' };
}

async function stream(text, model, voice, options, onChunk) {
  const response = await clientFor(options).audio.speech.create({
    model,
    voice,
    input: text,
    response_format: 'pcm',
  }, { signal: options.signal });
  let total = 0;
  let pending = Buffer.alloc(0);
  for await (const raw of response.body) {
    const chunk = Buffer.from(raw);
    total += chunk.length;
    if (total > MAX_AUDIO_BYTES) {
      const error = new Error('OpenAI speech response exceeded its safety limit.');
      error.code = 'VOICE_PROVIDER_RESPONSE_TOO_LARGE';
      throw error;
    }
    pending = Buffer.concat([pending, chunk]);
    if (pending.length >= 8192) {
      const even = pending.length - (pending.length % 2);
      await onChunk({
        audioBytes: wrapPcmAsWav(pending.subarray(0, even)),
        mimeType: 'audio/wav',
      });
      pending = pending.subarray(even);
    }
  }
  if (pending.length > 1) {
    await onChunk({
      audioBytes: wrapPcmAsWav(pending.subarray(0, pending.length - (pending.length % 2))),
      mimeType: 'audio/wav',
    });
  }
}

module.exports = { stream, synthesize, transcribe };
