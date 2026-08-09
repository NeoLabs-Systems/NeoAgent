'use strict';

const fs = require('fs');
const { wrapPcmAsWav } = require('../shared_audio');
const { requireApiKey } = require('./credentials');
const { MAX_AUDIO_BYTES, providerResponse, readBounded } = require('./http_stream');

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

function apiKey(options) {
  return requireApiKey('Gemini voice', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY'], options.apiKey);
}

function requestBody(text, voice) {
  return {
    contents: [{ parts: [{ text }] }],
    generationConfig: {
      responseModalities: ['AUDIO'],
      speechConfig: {
        voiceConfig: { prebuiltVoiceConfig: { voiceName: voice || 'Kore' } },
      },
    },
  };
}

function audioFromPayload(payload) {
  const parts = payload?.candidates?.[0]?.content?.parts || [];
  const part = parts.find((item) => item?.inlineData?.data || item?.inline_data?.data);
  const data = part?.inlineData?.data || part?.inline_data?.data || '';
  if (!data) return null;
  const mime = part?.inlineData?.mimeType
    || part?.inline_data?.mime_type
    || 'audio/l16;rate=24000;channels=1';
  const bytes = Buffer.from(data, 'base64');
  return mime.toLowerCase().startsWith('audio/l')
    ? { audioBytes: wrapPcmAsWav(bytes), mimeType: 'audio/wav' }
    : { audioBytes: bytes, mimeType: mime };
}

async function jsonRequest(url, body, options, label) {
  const response = await providerResponse(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey(options) },
    body: JSON.stringify(body),
    signal: options.signal,
  }, label);
  return JSON.parse((await readBounded(response)).toString('utf8'));
}

async function transcribe(filePath, model, mimeType, options = {}) {
  const audio = await fs.promises.readFile(filePath, { signal: options.signal });
  const payload = await jsonRequest(
    `${BASE_URL}/${encodeURIComponent(model)}:generateContent`,
    {
      contents: [{ parts: [
        { text: 'Transcribe this audio verbatim. Return only the transcript text.' },
        { inlineData: { mimeType: mimeType || 'audio/mpeg', data: audio.toString('base64') } },
      ] }],
      generationConfig: { temperature: 0 },
    },
    options,
    'Gemini STT failed',
  );
  return (payload?.candidates?.[0]?.content?.parts || [])
    .map((part) => String(part?.text || ''))
    .join('\n')
    .trim();
}

async function synthesize(text, model, voice, options = {}) {
  const payload = await jsonRequest(
    `${BASE_URL}/${encodeURIComponent(model)}:generateContent`,
    requestBody(text, voice),
    options,
    'Gemini TTS failed',
  );
  const audio = audioFromPayload(payload);
  if (!audio) throw new Error('Gemini TTS returned no audio data.');
  return audio;
}

async function stream(text, model, voice, options, onChunk) {
  const response = await providerResponse(
    `${BASE_URL}/${encodeURIComponent(model)}:streamGenerateContent?alt=sse`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey(options) },
      body: JSON.stringify(requestBody(text, voice)),
      signal: options.signal,
    },
    'Gemini TTS stream failed',
  );
  let pending = '';
  let total = 0;
  for await (const raw of response.body) {
    pending += Buffer.from(raw).toString('utf8');
    const lines = pending.split('\n');
    pending = lines.pop() || '';
    for (const line of lines) {
      if (!line.startsWith('data:')) continue;
      const payload = JSON.parse(line.slice(5).trim());
      const audio = audioFromPayload(payload);
      if (!audio) continue;
      total += audio.audioBytes.length;
      if (total > MAX_AUDIO_BYTES) {
        const error = new Error('Gemini speech response exceeded its safety limit.');
        error.code = 'VOICE_PROVIDER_RESPONSE_TOO_LARGE';
        throw error;
      }
      await onChunk(audio);
    }
  }
}

module.exports = { stream, synthesize, transcribe };
