'use strict';

const fs = require('fs');
const path = require('path');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');
const { getOpenAiClient } = require('./openaiClient');
const { synthesizeSpeechBuffer } = require('./openaiSpeech');
const { transcribeChunkWithDeepgram } = require('../recordings/deepgram');
const { decryptLocalValue } = require('../../utils/local_secrets');

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
  gemini: 'gemini-2.5-flash-preview-tts',
});

const DEFAULT_TTS_VOICES = Object.freeze({
  openai: 'alloy',
  deepgram: '',
  gemini: 'Kore',
});

const GEMINI_API_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';
const DEFAULT_GEMINI_TRANSCRIPTION_PROMPT =
  'Transcribe this audio verbatim. Return only the transcript text.';
const EMOJI_SPEECH_REGEX =
  /[\p{Extended_Pictographic}\p{Emoji_Presentation}\p{Regional_Indicator}\u200D\uFE0F\u20E3]/gu;
const WEARABLE_SAFE_AUDIO_FORMAT = Object.freeze({
  responseFormat: 'wav',
  mimeType: 'audio/wav',
  deepgramEncoding: 'linear16',
  deepgramContainer: 'wav',
});

function withTimeout(promise, timeoutMs, label) {
  const normalizedTimeout = Number(timeoutMs);
  if (!Number.isFinite(normalizedTimeout) || normalizedTimeout <= 0) {
    return promise;
  }
  let timer = null;
  const timeoutPromise = new Promise((_, reject) => {
    timer = setTimeout(() => {
      reject(new Error(`${label} timed out after ${normalizedTimeout}ms.`));
    }, normalizedTimeout);
    timer.unref?.();
  });
  return Promise.race([promise, timeoutPromise]).finally(() => {
    if (timer) {
      clearTimeout(timer);
    }
  });
}

function sanitizeSpeechText(value) {
  const text = String(value || '');
  if (!text) {
    return '';
  }
  return text
    .replace(EMOJI_SPEECH_REGEX, ' ')
    .replace(/[ \t]{2,}/g, ' ')
    .replace(/\s+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

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
      const value = decryptLocalValue(keys[variant]);
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
    responseFormat: String(options.responseFormat || '').trim().toLowerCase(),
    transport: String(options.transport || '').trim().toLowerCase(),
  };
}

function resolveWearableSafeAudioOptions(options = {}) {
  return String(options.transport || '').trim().toLowerCase() === 'wearable'
    || String(options.responseFormat || '').trim().toLowerCase() === 'wav';
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

async function fetchAudioStreamOrThrow(url, init, errorPrefix, defaultMimeType = 'audio/mpeg', onChunk) {
  const response = await fetch(url, init);
  if (!response.ok) {
    await throwResponseError(response, errorPrefix);
  }
  const mimeType = response.headers.get('content-type') || defaultMimeType;
  const reader = response.body.getReader();
  const chunks = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value?.length) chunks.push(Buffer.from(value));
  }
  const audioBytes = Buffer.concat(chunks);
  await onChunk({ audioBytes, mimeType });
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

async function transcribeWithOpenAi(filePath, model, options = {}) {
  const client = getOpenAiClient({
    apiKey: typeof options.apiKey === 'string' ? options.apiKey.trim() : '',
    baseUrl: typeof options.baseUrl === 'string' ? options.baseUrl.trim() : '',
  });
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

async function transcribeWithGemini(filePath, model, mimeType, options = {}) {
  const apiKey =
    (typeof options.apiKey === 'string' ? options.apiKey.trim() : '') ||
    requireApiKey('Gemini STT', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);

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
  let request = null;

  if (provider === 'openai') {
    request = transcribeWithOpenAi(filePath, model, options);
  } else if (provider === 'deepgram') {
    request = transcribeWithDeepgram(filePath, options.mimeType);
  } else {
    request = transcribeWithGemini(filePath, model, options.mimeType, options);
  }
  return withTimeout(request, options.timeoutMs, `${provider} STT`);
}

async function synthesizeWithOpenAi(text, model, voice, options = {}) {
  const client = getOpenAiClient({
    apiKey: typeof options.apiKey === 'string' ? options.apiKey.trim() : '',
    baseUrl: typeof options.baseUrl === 'string' ? options.baseUrl.trim() : '',
  });
  if (!client) {
    throw new Error('OpenAI TTS is selected but OPENAI_API_KEY is not configured.');
  }
  const useWearableSafeAudio = resolveWearableSafeAudioOptions(options);
  const audioBytes = await synthesizeSpeechBuffer(client, text, {
    model,
    voice,
    responseFormat: useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.responseFormat : 'mp3',
  });
  return {
    audioBytes,
    mimeType: useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.mimeType : 'audio/mpeg',
  };
}

async function streamWithOpenAi(text, model, voice, options = {}, onChunk) {
  const client = getOpenAiClient({
    apiKey: typeof options.apiKey === 'string' ? options.apiKey.trim() : '',
    baseUrl: typeof options.baseUrl === 'string' ? options.baseUrl.trim() : '',
  });
  if (!client) {
    throw new Error('OpenAI TTS is selected but OPENAI_API_KEY is not configured.');
  }
  const useWearableSafeAudio = resolveWearableSafeAudioOptions(options);
  const response = await client.audio.speech.create({
    model: String(model || 'gpt-4o-mini-tts').trim() || 'gpt-4o-mini-tts',
    voice: String(voice || 'alloy').trim() || 'alloy',
    input: text,
    response_format: useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.responseFormat : 'mp3',
  });
  const chunks = [];
  for await (const chunk of response.body) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  const audioBytes = Buffer.concat(chunks);
  await onChunk({
    audioBytes,
    mimeType: useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.mimeType : 'audio/mpeg',
  });
}

async function synthesizeWithDeepgram(text, model, options = {}) {
  const apiKey = requireApiKey('Deepgram TTS', ['DEEPGRAM_API_KEY']);
  const useWearableSafeAudio = resolveWearableSafeAudioOptions(options);
  const searchParams = new URLSearchParams({
    model,
  });
  if (useWearableSafeAudio) {
    searchParams.set('encoding', WEARABLE_SAFE_AUDIO_FORMAT.deepgramEncoding);
    searchParams.set('container', WEARABLE_SAFE_AUDIO_FORMAT.deepgramContainer);
  }

  return fetchAudioOrThrow(
    `https://api.deepgram.com/v1/speak?${searchParams.toString()}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text }),
    },
    'Deepgram TTS request failed',
    useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.mimeType : 'audio/mpeg',
  );
}

async function streamWithDeepgram(text, model, options = {}, onChunk) {
  const apiKey = requireApiKey('Deepgram TTS', ['DEEPGRAM_API_KEY']);
  const useWearableSafeAudio = resolveWearableSafeAudioOptions(options);
  const searchParams = new URLSearchParams({
    model,
  });
  if (useWearableSafeAudio) {
    searchParams.set('encoding', WEARABLE_SAFE_AUDIO_FORMAT.deepgramEncoding);
    searchParams.set('container', WEARABLE_SAFE_AUDIO_FORMAT.deepgramContainer);
  }
  await fetchAudioStreamOrThrow(
    `https://api.deepgram.com/v1/speak?${searchParams.toString()}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text }),
    },
    'Deepgram TTS stream failed',
    useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.mimeType : 'audio/mpeg',
    onChunk,
  );
}

async function synthesizeWithGemini(text, model, voice, options = {}) {
  const apiKey =
    (typeof options.apiKey === 'string' ? options.apiKey.trim() : '') ||
    requireApiKey('Gemini TTS', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);

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

function extractGeminiAudioChunk(jsonObj) {
  const parts = jsonObj?.candidates?.[0]?.content?.parts;
  const audioPart = Array.isArray(parts)
    ? parts.find((part) => part?.inlineData?.data || part?.inline_data?.data)
    : null;
  if (!audioPart) return null;

  const data = audioPart?.inlineData?.data || audioPart?.inline_data?.data || '';
  if (!data) return null;

  const mimeType =
    audioPart?.inlineData?.mimeType
    || audioPart?.inlineData?.mime_type
    || audioPart?.inline_data?.mimeType
    || audioPart?.inline_data?.mime_type
    || 'audio/l16;rate=24000;channels=1';

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

async function streamWithGemini(text, model, voice, options = {}, onChunk) {
  const apiKey =
    (typeof options.apiKey === 'string' ? options.apiKey.trim() : '') ||
    requireApiKey('Gemini TTS', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);

  const response = await fetch(
    `${GEMINI_API_BASE_URL}/${encodeURIComponent(model)}:streamGenerateContent?alt=sse&key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text }] }],
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
  );

  if (!response.ok) {
    await throwResponseError(response, 'Gemini TTS stream request failed');
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    // SSE lines: each event is "data: {...}\n\n"
    const lines = buffer.split('\n');
    buffer = lines.pop(); // keep incomplete line

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      const jsonStr = trimmed.slice(5).trim();
      if (!jsonStr || jsonStr === '[DONE]') continue;
      let parsed;
      try {
        parsed = JSON.parse(jsonStr);
      } catch {
        continue;
      }
      const chunk = extractGeminiAudioChunk(parsed);
      if (chunk) await onChunk(chunk);
    }
  }

  // Flush any remaining buffered data.
  if (buffer.trim().startsWith('data:')) {
    const jsonStr = buffer.trim().slice(5).trim();
    if (jsonStr && jsonStr !== '[DONE]') {
      try {
        const parsed = JSON.parse(jsonStr);
        const chunk = extractGeminiAudioChunk(parsed);
        if (chunk) await onChunk(chunk);
      } catch {
        // Ignore incomplete trailing chunk.
      }
    }
  }
}

async function synthesizeVoiceReply(text, options = {}) {
  const content = String(text || '').trim();
  if (!content) {
    throw new Error('Voice reply text is empty; cannot synthesize speech.');
  }

  const { provider, model, voice } = normalizeVoiceSynthesisOptions(options);
  let request = null;

  if (provider === 'openai') {
    request = synthesizeWithOpenAi(content, model, voice, options);
  } else if (provider === 'deepgram') {
    request = synthesizeWithDeepgram(content, model, options);
  } else {
    request = synthesizeWithGemini(content, model, voice, options);
  }
  return withTimeout(request, options.timeoutMs, `${provider} TTS`);
}

// Minimum characters before flushing a sentence chunk to TTS to avoid tiny requests.
const MIN_SENTENCE_CHUNK_CHARS = 80;
const MAX_TTS_CHUNK_CHARS = 220;

function splitOversizeChunk(text, maxChars = MAX_TTS_CHUNK_CHARS) {
  const normalized = String(text || '').trim();
  if (!normalized) return [];
  if (normalized.length <= maxChars) return [normalized];

  const words = normalized.split(/\s+/).filter(Boolean);
  if (words.length <= 1) {
    const slices = [];
    for (let index = 0; index < normalized.length; index += maxChars) {
      slices.push(normalized.slice(index, index + maxChars).trim());
    }
    return slices.filter(Boolean);
  }

  const chunks = [];
  let pending = '';
  for (const word of words) {
    const candidate = pending ? `${pending} ${word}` : word;
    if (pending && candidate.length > maxChars) {
      chunks.push(pending);
      pending = word;
      continue;
    }
    if (!pending && candidate.length > maxChars) {
      chunks.push(...splitOversizeChunk(word, maxChars));
      pending = '';
      continue;
    }
    pending = candidate;
  }
  if (pending) chunks.push(pending);
  return chunks;
}

function splitIntoSentenceChunks(text) {
  const normalized = String(text || '').trim();
  if (!normalized) return [];

  // Split on sentence-ending punctuation followed by whitespace or end-of-string.
  const raw = normalized.split(/(?<=[.!?])(?=\s|$)/);
  const chunks = [];
  let pending = '';

  for (const part of raw) {
    const piece = part.trim();
    if (!piece) continue;
    pending = pending ? `${pending} ${piece}` : piece;
    if (pending.length >= MIN_SENTENCE_CHUNK_CHARS || pending.length >= MAX_TTS_CHUNK_CHARS) {
      chunks.push(...splitOversizeChunk(pending));
      pending = '';
    }
  }

  if (pending) chunks.push(...splitOversizeChunk(pending));
  return chunks.length ? chunks : [normalized];
}

async function synthesizeVoiceReplyStream(text, options = {}, onChunk) {
  const content = String(text || '').trim();
  if (!content) {
    throw new Error('Voice reply text is empty; cannot synthesize speech.');
  }

  const { provider, model, voice } = normalizeVoiceSynthesisOptions(options);
  const chunks = splitIntoSentenceChunks(content);

  for (const chunk of chunks) {
    const run = (async () => {
      if (provider === 'openai') {
        await streamWithOpenAi(chunk, model, voice, options, onChunk);
      } else if (provider === 'deepgram') {
        await streamWithDeepgram(chunk, model, options, onChunk);
      } else {
        await streamWithGemini(chunk, model, voice, options, onChunk);
      }
    })();
    await withTimeout(run, options.timeoutMs, `${provider} TTS stream`);
  }
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
  sanitizeSpeechText,
  guessExtFromMimeType,
  splitIntoSentenceChunks,
  transcribeVoiceInput,
  synthesizeVoiceReply,
  synthesizeVoiceReplyStream,
};
