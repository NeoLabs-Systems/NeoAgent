'use strict';

const fs = require('fs');
const path = require('path');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');
const { getOpenAiClient } = require('./openaiClient');
const { synthesizeSpeechBuffer } = require('./openaiSpeech');
const { transcribeChunkWithDeepgram } = require('../recordings/deepgram');

const DEFAULT_STT_PROVIDER = 'openai';
const DEFAULT_TTS_PROVIDER = 'openai';

const STT_PROVIDERS = Object.freeze(['openai', 'deepgram', 'gemini']);
const TTS_PROVIDERS = Object.freeze(['openai', 'deepgram', 'gemini']);

const DEFAULT_STT_MODELS = Object.freeze({
  openai: 'whisper-1',
  deepgram: process.env.DEEPGRAM_MODEL || 'nova-3',
  gemini: 'gemini-2.0-flash',
});

const DEFAULT_TTS_MODELS = Object.freeze({
  openai: 'tts-1',
  deepgram: 'aura-2-thalia-en',
  gemini: 'gemini-2.5-flash-preview-tts',
});

const DEFAULT_TTS_VOICES = Object.freeze({
  openai: 'alloy',
  deepgram: '',
  gemini: 'Kore',
});

function readSharedApiKeys() {
  try {
    const keysPath = path.join(AGENT_DATA_DIR, 'API_KEYS.json');
    const raw = fs.readFileSync(keysPath, 'utf8');
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function resolveApiKey(candidates = []) {
  for (const key of candidates) {
    const envValue = process.env[key];
    if (typeof envValue === 'string' && envValue.trim()) {
      return envValue.trim();
    }
  }

  const keys = readSharedApiKeys();
  for (const key of candidates) {
    const lower = key.toLowerCase();
    const snake = lower.replace(/[^a-z0-9]+/g, '_');
    const variants = [key, lower, snake];
    for (const variant of variants) {
      const value = keys[variant];
      if (typeof value === 'string' && value.trim()) {
        return value.trim();
      }
    }
  }

  return '';
}

function normalizeSttProvider(provider) {
  const value = String(provider || '').trim().toLowerCase();
  return STT_PROVIDERS.includes(value) ? value : DEFAULT_STT_PROVIDER;
}

function normalizeTtsProvider(provider) {
  const value = String(provider || '').trim().toLowerCase();
  return TTS_PROVIDERS.includes(value) ? value : DEFAULT_TTS_PROVIDER;
}

function resolveSttModel(provider, requestedModel) {
  const normalizedProvider = normalizeSttProvider(provider);
  const model = String(requestedModel || '').trim();
  return model || DEFAULT_STT_MODELS[normalizedProvider];
}

function resolveTtsModel(provider, requestedModel) {
  const normalizedProvider = normalizeTtsProvider(provider);
  const model = String(requestedModel || '').trim();
  return model || DEFAULT_TTS_MODELS[normalizedProvider];
}

function resolveTtsVoice(provider, requestedVoice) {
  const normalizedProvider = normalizeTtsProvider(provider);
  const voice = String(requestedVoice || '').trim();
  return voice || DEFAULT_TTS_VOICES[normalizedProvider];
}

function guessExtFromMimeType(mimeType) {
  const mime = String(mimeType || '').toLowerCase();
  if (mime.includes('wav')) return 'wav';
  if (mime.includes('ogg')) return 'ogg';
  if (mime.includes('mpeg') || mime.includes('mp3')) return 'mp3';
  return 'mp3';
}

async function transcribeWithOpenAi(filePath, model) {
  const client = getOpenAiClient();
  if (!client) {
    throw new Error('OpenAI STT is selected but OPENAI_API_KEY is not configured.');
  }
  const transcription = await client.audio.transcriptions.create({
    file: fs.createReadStream(filePath),
    model,
  });
  return String(transcription?.text || '').trim();
}

async function transcribeWithDeepgram(filePath, mimeType) {
  const audioBytes = await fs.promises.readFile(filePath);
  const payload = await transcribeChunkWithDeepgram({
    audioBytes,
    mimeType: mimeType || 'audio/mpeg',
    detectLanguage: 'multi',
  });

  const transcript = payload?.results?.channels?.[0]?.alternatives?.[0]?.transcript;
  return String(transcript || '').trim();
}

async function transcribeWithGemini(filePath, model, mimeType) {
  const apiKey = resolveApiKey(['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);
  if (!apiKey) {
    throw new Error('Gemini STT is selected but GOOGLE_AI_KEY is not configured.');
  }

  const audioBytes = await fs.promises.readFile(filePath);
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              {
                text: 'Transcribe this audio verbatim. Return only the transcript text.',
              },
              {
                inline_data: {
                  mime_type: mimeType || 'audio/mpeg',
                  data: Buffer.from(audioBytes).toString('base64'),
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0,
        },
      }),
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Gemini STT request failed (${response.status}): ${body || 'empty response'}`);
  }

  const payload = await response.json();
  const parts = payload?.candidates?.[0]?.content?.parts;
  const transcript = Array.isArray(parts)
    ? parts.map((part) => String(part?.text || '')).join('\n').trim()
    : '';
  return transcript;
}

async function transcribeVoiceInput(filePath, options = {}) {
  const provider = normalizeSttProvider(options.provider);
  const model = resolveSttModel(provider, options.model);

  if (provider === 'openai') {
    return transcribeWithOpenAi(filePath, model);
  }
  if (provider === 'deepgram') {
    return transcribeWithDeepgram(filePath, options.mimeType);
  }
  return transcribeWithGemini(filePath, model, options.mimeType);
}

async function synthesizeWithOpenAi(text, model, voice) {
  const client = getOpenAiClient();
  if (!client) {
    throw new Error('OpenAI TTS is selected but OPENAI_API_KEY is not configured.');
  }
  const audioBytes = await synthesizeSpeechBuffer(client, text, { model, voice });
  return {
    audioBytes,
    mimeType: 'audio/mpeg',
  };
}

async function synthesizeWithDeepgram(text, model) {
  const apiKey = resolveApiKey(['DEEPGRAM_API_KEY']);
  if (!apiKey) {
    throw new Error('Deepgram TTS is selected but DEEPGRAM_API_KEY is not configured.');
  }

  const response = await fetch(
    `https://api.deepgram.com/v1/speak?model=${encodeURIComponent(model)}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text }),
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Deepgram TTS request failed (${response.status}): ${body || 'empty response'}`);
  }

  const audioBytes = Buffer.from(await response.arrayBuffer());
  return {
    audioBytes,
    mimeType: response.headers.get('content-type') || 'audio/mpeg',
  };
}

async function synthesizeWithGemini(text, model, voice) {
  const apiKey = resolveApiKey(['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);
  if (!apiKey) {
    throw new Error('Gemini TTS is selected but GOOGLE_AI_KEY is not configured.');
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text }],
          },
        ],
        generationConfig: {
          responseModalities: ['AUDIO'],
          temperature: 0.6,
        },
        speechConfig: {
          voiceConfig: {
            prebuiltVoiceConfig: {
              voiceName: String(voice || '').trim() || 'Kore',
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Gemini TTS request failed (${response.status}): ${body || 'empty response'}`);
  }

  const payload = await response.json();
  const parts = payload?.candidates?.[0]?.content?.parts;
  const audioPart = Array.isArray(parts)
    ? parts.find((part) => part?.inlineData?.data || part?.inline_data?.data)
    : null;

  const data = audioPart?.inlineData?.data || audioPart?.inline_data?.data || '';
  if (!data) {
    throw new Error('Gemini TTS returned no audio data.');
  }

  const mimeType =
    audioPart?.inlineData?.mimeType
    || audioPart?.inlineData?.mime_type
    || audioPart?.inline_data?.mimeType
    || audioPart?.inline_data?.mime_type
    || 'audio/wav';

  return {
    audioBytes: Buffer.from(data, 'base64'),
    mimeType,
  };
}

async function synthesizeVoiceReply(text, options = {}) {
  const content = String(text || '').trim();
  if (!content) {
    throw new Error('Voice reply text is empty; cannot synthesize speech.');
  }

  const provider = normalizeTtsProvider(options.provider);
  const model = resolveTtsModel(provider, options.model);
  const voice = resolveTtsVoice(provider, options.voice);

  if (provider === 'openai') {
    return synthesizeWithOpenAi(content, model, voice);
  }
  if (provider === 'deepgram') {
    return synthesizeWithDeepgram(content, model);
  }
  return synthesizeWithGemini(content, model, voice);
}

module.exports = {
  DEFAULT_STT_PROVIDER,
  DEFAULT_TTS_PROVIDER,
  STT_PROVIDERS,
  TTS_PROVIDERS,
  DEFAULT_STT_MODELS,
  DEFAULT_TTS_MODELS,
  DEFAULT_TTS_VOICES,
  normalizeSttProvider,
  normalizeTtsProvider,
  resolveSttModel,
  resolveTtsModel,
  resolveTtsVoice,
  guessExtFromMimeType,
  transcribeVoiceInput,
  synthesizeVoiceReply,
};
