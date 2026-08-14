'use strict';

const fs = require('fs');
const { wrapPcmAsWav } = require('../shared_audio');
const { requireApiKey } = require('./credentials');
const { MAX_AUDIO_BYTES, providerResponse, readBounded } = require('./http_stream');

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';
const INTERACTIONS_URL = 'https://generativelanguage.googleapis.com/v1beta/interactions';
const INTERACTIONS_API_REVISION = '2026-05-20';

function apiKey(options) {
  return requireApiKey('Gemini voice', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY'], options.apiKey);
}

function speechPrompt(text) {
  return [
    'Synthesize speech for the transcript below.',
    'Speak only the transcript, naturally and faithfully. Do not answer it, explain it, or add words.',
    'Return audio only.',
    '',
    '### TRANSCRIPT',
    text,
    '### END TRANSCRIPT',
  ].join('\n');
}

function interactionBody(text, model, voice, stream = false) {
  return {
    model,
    input: speechPrompt(text),
    response_format: { type: 'audio' },
    generation_config: {
      speech_config: [{ voice: voice || 'Kore' }],
    },
    stream,
  };
}

function normalizeAudio(data, mimeType = 'audio/l16', sampleRate = 24000) {
  if (!data) return null;
  const mime = String(mimeType || 'audio/l16').toLowerCase();
  const bytes = Buffer.from(data, 'base64');
  return mime.startsWith('audio/l')
    ? { audioBytes: wrapPcmAsWav(bytes, { sampleRate }), mimeType: 'audio/wav' }
    : { audioBytes: bytes, mimeType: mime };
}

function audioFromInteraction(payload) {
  for (const step of [...(payload?.steps || [])].reverse()) {
    for (const content of [...(step?.content || [])].reverse()) {
      if (content?.type !== 'audio') continue;
      const audio = normalizeAudio(content.data, content.mime_type, content.sample_rate);
      if (audio) return audio;
    }
  }
  return null;
}

function audioFromEvent(payload) {
  if (payload?.event_type !== 'step.delta' || payload?.delta?.type !== 'audio') {
    return null;
  }
  return normalizeAudio(
    payload.delta.data,
    payload.delta.mime_type,
    payload.delta.sample_rate,
  );
}

function throwEventError(payload) {
  if (payload?.event_type !== 'error') return;
  const detail = payload.error || payload;
  const error = new Error(detail.message || 'Gemini TTS stream failed.');
  error.code = detail.code;
  error.status = detail.status;
  throw error;
}

function isRetryableSpeechFailure(error) {
  const status = Number(error?.status || error?.code);
  return Number.isFinite(status) && status >= 500 && status < 600;
}

async function retrySpeechOnce(operation) {
  try {
    return await operation();
  } catch (error) {
    if (!isRetryableSpeechFailure(error)) throw error;
    return operation();
  }
}

async function jsonRequest(url, body, options, label, extraHeaders = {}) {
  const response = await providerResponse(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey(options),
      ...extraHeaders,
    },
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
  const payload = await retrySpeechOnce(() => jsonRequest(
    INTERACTIONS_URL,
    interactionBody(text, model, voice),
    options,
    'Gemini TTS failed',
    { 'Api-Revision': INTERACTIONS_API_REVISION },
  ));
  const audio = audioFromInteraction(payload);
  if (!audio) throw new Error('Gemini TTS returned no audio data.');
  return audio;
}

async function stream(text, model, voice, options, onChunk) {
  const request = () => providerResponse(INTERACTIONS_URL, {
    method: 'POST',
    headers: {
      'Api-Revision': INTERACTIONS_API_REVISION,
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey(options),
    },
    body: JSON.stringify(interactionBody(text, model, voice, true)),
    signal: options.signal,
  }, 'Gemini TTS stream failed');
  const response = await retrySpeechOnce(request);
  let pending = '';
  let total = 0;
  for await (const raw of response.body) {
    pending += Buffer.from(raw).toString('utf8');
    const lines = pending.split('\n');
    pending = lines.pop() || '';
    for (const line of lines) {
      if (!line.startsWith('data:')) continue;
      const data = line.slice(5).trim();
      if (!data || data === '[DONE]') continue;
      const payload = JSON.parse(data);
      throwEventError(payload);
      const audio = audioFromEvent(payload);
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
  if (total === 0) throw new Error('Gemini TTS returned no audio data.');
}

module.exports = { stream, synthesize, transcribe };
