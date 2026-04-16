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
  openai: 'gpt-4o-transcribe',
  deepgram: process.env.DEEPGRAM_MODEL || 'nova-3',
  gemini: 'gemini-3-flash-preview',
});

const DEFAULT_TTS_MODELS = Object.freeze({
  openai: 'gpt-4o-mini-tts',
  deepgram: 'aura-2-thalia-en',
  gemini: 'gemini-3.1-flash-tts-preview',
});

const DEFAULT_TTS_VOICES = Object.freeze({
  openai: 'alloy',
  deepgram: '',
  gemini: 'Kore',
});

const GEMINI_API_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';
const DEFAULT_GEMINI_TRANSCRIPTION_PROMPT =
  'Transcribe this audio verbatim. Return only the transcript text.';

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

function normalizeVoiceSynthesisOptions(options = {}) {
  const provider = normalizeTtsProvider(options.provider);
  return {
    provider,
    model: resolveTtsModel(provider, options.model),
    voice: resolveTtsVoice(provider, options.voice),
  };
}

function requireApiKey(settingLabel, candidates = []) {
  const apiKey = resolveApiKey(candidates);
  if (!apiKey) {
    throw new Error(`${settingLabel} is selected but ${candidates[0]} is not configured.`);
  }
  return apiKey;
}

async function throwResponseError(response, prefix) {
  const body = await response.text();
  throw new Error(`${prefix} (${response.status}): ${body || 'empty response'}`);
}

async function fetchJsonOrThrow(url, init, errorPrefix) {
  const response = await fetch(url, init);
  if (!response.ok) {
    await throwResponseError(response, errorPrefix);
  }
  return response.json();
}

async function fetchAudioOrThrow(url, init, errorPrefix, defaultMimeType = 'audio/mpeg') {
  const response = await fetch(url, init);
  if (!response.ok) {
    await throwResponseError(response, errorPrefix);
  }
  return {
    audioBytes: Buffer.from(await response.arrayBuffer()),
    mimeType: response.headers.get('content-type') || defaultMimeType,
  };
}

function guessExtFromMimeType(mimeType) {
  const mime = String(mimeType || '').toLowerCase();
  if (mime.includes('wav')) return 'wav';
  if (mime.includes('ogg')) return 'ogg';
  if (mime.includes('mpeg') || mime.includes('mp3')) return 'mp3';
  return 'mp3';
}

function parsePcmMimeType(mimeType) {
  const mime = String(mimeType || '').toLowerCase();
  if (!mime.startsWith('audio/l')) return null;

  const bitDepthMatch = /^audio\/l(\d+)/.exec(mime);
  const bitsPerSample = Number(bitDepthMatch?.[1] || 16);
  if (!Number.isFinite(bitsPerSample) || bitsPerSample <= 0 || bitsPerSample % 8 !== 0) {
    return null;
  }

  const sampleRateMatch = /(?:^|[;\s])rate=(\d+)/.exec(mime);
  const channelMatch = /(?:^|[;\s])channels=(\d+)/.exec(mime);

  const sampleRate = Number(sampleRateMatch?.[1] || 24000);
  const channels = Number(channelMatch?.[1] || 1);
  if (!Number.isFinite(sampleRate) || sampleRate <= 0 || !Number.isFinite(channels) || channels <= 0) {
    return null;
  }

  return {
    bitsPerSample,
    sampleRate,
    channels,
  };
}

function wrapPcmAsWav(audioBytes, format) {
  const data = Buffer.isBuffer(audioBytes) ? audioBytes : Buffer.from(audioBytes || []);
  const { bitsPerSample, sampleRate, channels } = format;
  const blockAlign = channels * (bitsPerSample / 8);
  const byteRate = sampleRate * blockAlign;
  const header = Buffer.alloc(44);

  header.write('RIFF', 0, 4, 'ascii');
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8, 4, 'ascii');
  header.write('fmt ', 12, 4, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36, 4, 'ascii');
  header.writeUInt32LE(data.length, 40);

  return Buffer.concat([header, data]);
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
  const apiKey = requireApiKey('Gemini STT', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);

  const audioBytes = await fs.promises.readFile(filePath);
  const payload = await fetchJsonOrThrow(
    `${GEMINI_API_BASE_URL}/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
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
                text: DEFAULT_GEMINI_TRANSCRIPTION_PROMPT,
              },
              {
                inlineData: {
                  mimeType: mimeType || 'audio/mpeg',
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
    'Gemini STT request failed',
  );
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
  const apiKey = requireApiKey('Deepgram TTS', ['DEEPGRAM_API_KEY']);

  return fetchAudioOrThrow(
    `https://api.deepgram.com/v1/speak?model=${encodeURIComponent(model)}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text }),
    },
    'Deepgram TTS request failed',
  );
}

async function synthesizeWithGemini(text, model, voice) {
  const apiKey = requireApiKey('Gemini TTS', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);

  const payload = await fetchJsonOrThrow(
    `${GEMINI_API_BASE_URL}/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
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
          speechConfig: {
            voiceConfig: {
              prebuiltVoiceConfig: {
                voiceName: String(voice || '').trim() || 'Kore',
              },
            },
          },
          temperature: 0.6,
        },
      }),
    },
    'Gemini TTS request failed',
  );
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

  const pcmFormat = parsePcmMimeType(mimeType);
  if (pcmFormat) {
    return {
      audioBytes: wrapPcmAsWav(Buffer.from(data, 'base64'), pcmFormat),
      mimeType: 'audio/wav',
    };
  }

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

  const { provider, model, voice } = normalizeVoiceSynthesisOptions(options);

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
  normalizeVoiceSynthesisOptions,
  guessExtFromMimeType,
  transcribeVoiceInput,
  synthesizeVoiceReply,
};
