'use strict';

const fs = require('fs');
const { requireApiKey } = require('./credentials');
const { providerResponse, readBounded } = require('./http_stream');

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

async function transcribe(filePath, model, mimeType, options = {}) {
  const audio = await fs.promises.readFile(filePath, { signal: options.signal });
  const response = await providerResponse(
    `${BASE_URL}/${encodeURIComponent(model)}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': requireApiKey('Gemini transcription', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY'], options.apiKey),
      },
      body: JSON.stringify({
        contents: [{ parts: [
          { text: 'Transcribe this audio verbatim. Return only the transcript text.' },
          { inlineData: { mimeType: mimeType || 'audio/mpeg', data: audio.toString('base64') } },
        ] }],
        generationConfig: { temperature: 0 },
      }),
      signal: options.signal,
    },
    'Gemini STT failed',
  );
  const payload = JSON.parse((await readBounded(response)).toString('utf8'));
  return (payload?.candidates?.[0]?.content?.parts || [])
    .map((part) => String(part?.text || ''))
    .join('\n')
    .trim();
}

module.exports = { transcribe };
