'use strict';

const fs = require('fs');
const { OpenAI } = require('openai');
const { requireApiKey } = require('./credentials');

async function transcribe(filePath, model, _mimeType, options = {}) {
  const client = new OpenAI({
    apiKey: requireApiKey('OpenAI transcription', ['OPENAI_API_KEY'], options.apiKey),
    baseURL: String(options.baseUrl || '').trim() || undefined,
  });
  const file = fs.createReadStream(filePath);
  try {
    const result = await client.audio.transcriptions.create({ file, model }, { signal: options.signal });
    return String(result?.text || '').trim();
  } finally {
    file.destroy();
  }
}

module.exports = { transcribe };
