'use strict';

const fs = require('fs');
const { wrapPcmAsWav } = require('../shared_audio');
const { requireApiKey } = require('./credentials');
const {
  MAX_AUDIO_BYTES,
  providerResponse,
  readBounded,
  streamBytes,
} = require('./http_stream');

const BASE_URL = 'https://api.deepgram.com';

function headers(options, contentType) {
  return {
    Authorization: `Token ${requireApiKey('Deepgram voice', ['DEEPGRAM_API_KEY'], options.apiKey)}`,
    'Content-Type': contentType,
  };
}

async function transcribe(filePath, model, mimeType, options = {}) {
  const audio = await fs.promises.readFile(filePath, { signal: options.signal });
  const query = new URLSearchParams({
    model,
    language: 'multi',
    punctuate: 'true',
    smart_format: 'true',
  });
  const response = await providerResponse(
    `${BASE_URL}/v1/listen?${query}`,
    {
      method: 'POST',
      headers: headers(options, mimeType || 'application/octet-stream'),
      body: audio,
      signal: options.signal,
    },
    'Deepgram STT failed',
  );
  const payload = JSON.parse((await readBounded(response)).toString('utf8'));
  return String(payload?.results?.channels?.[0]?.alternatives?.[0]?.transcript || '').trim();
}

async function synthesize(text, model, _voice, options = {}) {
  const response = await providerResponse(
    `${BASE_URL}/v1/speak?${new URLSearchParams({ model })}`,
    {
      method: 'POST',
      headers: headers(options, 'application/json'),
      body: JSON.stringify({ text }),
      signal: options.signal,
    },
    'Deepgram TTS failed',
  );
  return {
    audioBytes: await readBounded(response, MAX_AUDIO_BYTES),
    mimeType: response.headers.get('content-type') || 'audio/mpeg',
  };
}

async function stream(text, model, _voice, options, onChunk) {
  const query = new URLSearchParams({
    model,
    encoding: 'linear16',
    container: 'none',
    sample_rate: '24000',
  });
  const response = await providerResponse(
    `${BASE_URL}/v1/speak?${query}`,
    {
      method: 'POST',
      headers: headers(options, 'application/json'),
      body: JSON.stringify({ text }),
      signal: options.signal,
    },
    'Deepgram TTS stream failed',
  );
  let pending = Buffer.alloc(0);
  await streamBytes(response, async (chunk) => {
    pending = Buffer.concat([pending, chunk]);
    if (pending.length < 8192) return;
    const even = pending.length - (pending.length % 2);
    await onChunk({
      audioBytes: wrapPcmAsWav(pending.subarray(0, even)),
      mimeType: 'audio/wav',
    });
    pending = pending.subarray(even);
  }, { signal: options.signal });
  if (pending.length > 1) {
    await onChunk({
      audioBytes: wrapPcmAsWav(pending.subarray(0, pending.length - (pending.length % 2))),
      mimeType: 'audio/wav',
    });
  }
}

module.exports = { stream, synthesize, transcribe };
