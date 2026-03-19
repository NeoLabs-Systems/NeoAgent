'use strict';

const DEFAULT_MODEL = process.env.DEEPGRAM_MODEL || 'nova-3';
const DEFAULT_LANGUAGE = process.env.DEEPGRAM_LANGUAGE || 'multi';
const DEFAULT_BASE_URL = process.env.DEEPGRAM_BASE_URL || 'https://api.deepgram.com';

function isDeepgramConfigured() {
  return typeof process.env.DEEPGRAM_API_KEY === 'string' && process.env.DEEPGRAM_API_KEY.trim().length > 0;
}

async function transcribeChunkWithDeepgram({ audioBytes, mimeType, detectLanguage = DEFAULT_LANGUAGE } = {}) {
  if (!isDeepgramConfigured()) {
    throw new Error('DEEPGRAM_API_KEY is not configured.');
  }
  if (!(audioBytes instanceof Uint8Array) || audioBytes.byteLength === 0) {
    throw new Error('Audio payload is empty.');
  }

  const query = new URLSearchParams({
    model: DEFAULT_MODEL,
    language: detectLanguage || DEFAULT_LANGUAGE,
    punctuate: 'true',
    smart_format: 'true',
    paragraphs: 'true',
    utterances: 'true',
    diarize: 'false',
  });
  const response = await fetch(
    `${DEFAULT_BASE_URL.replace(/\/$/, '')}/v1/listen?${query.toString()}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${process.env.DEEPGRAM_API_KEY.trim()}`,
        'Content-Type': mimeType || 'application/octet-stream',
      },
      body: audioBytes,
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Deepgram request failed (${response.status}): ${body || 'empty response'}`);
  }

  return response.json();
}

module.exports = {
  DEFAULT_LANGUAGE,
  DEFAULT_MODEL,
  isDeepgramConfigured,
  transcribeChunkWithDeepgram,
};
