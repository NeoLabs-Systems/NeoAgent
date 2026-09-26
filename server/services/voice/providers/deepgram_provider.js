'use strict';

const fs = require('fs');
const { requireApiKey } = require('./credentials');
const { providerResponse, readBounded } = require('./http_stream');

const BASE_URL = 'https://api.deepgram.com';

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
      headers: {
        Authorization: `Token ${requireApiKey('Deepgram transcription', ['DEEPGRAM_API_KEY'], options.apiKey)}`,
        'Content-Type': mimeType || 'application/octet-stream',
      },
      body: audio,
      signal: options.signal,
    },
    'Deepgram STT failed',
  );
  const payload = JSON.parse((await readBounded(response)).toString('utf8'));
  return String(payload?.results?.channels?.[0]?.alternatives?.[0]?.transcript || '').trim();
}

module.exports = { transcribe };
