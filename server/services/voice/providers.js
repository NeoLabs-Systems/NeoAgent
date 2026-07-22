'use strict';

const fs = require('fs');
const path = require('path');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');
const { getOpenAiClient } = require('./openaiClient');
const { synthesizeSpeechBuffer } = require('./openaiSpeech');
const { decryptLocalValue } = require('../../utils/local_secrets');
const { fetchResponseBuffer, fetchResponseText } = require('../network/http');
const {
  createAbortError,
  runWithAbortTimeout,
  throwIfAborted,
} = require('../../utils/abort');

const DEEPGRAM_STT_MODEL = process.env.DEEPGRAM_MODEL || 'nova-3';
const DEEPGRAM_STT_LANGUAGE = process.env.DEEPGRAM_LANGUAGE || 'multi';
const DEEPGRAM_BASE_URL = process.env.DEEPGRAM_BASE_URL || 'https://api.deepgram.com';

async function transcribeChunkWithDeepgram({
  audioBytes,
  mimeType,
  detectLanguage = DEEPGRAM_STT_LANGUAGE,
  model = DEEPGRAM_STT_MODEL,
  signal = null,
} = {}) {
  if (!(audioBytes instanceof Uint8Array) || audioBytes.byteLength === 0) {
    throw new Error('Audio payload is empty.');
  }

  const query = new URLSearchParams({
    model: `${model || DEEPGRAM_STT_MODEL}`.trim() || DEEPGRAM_STT_MODEL,
    language: detectLanguage || DEEPGRAM_STT_LANGUAGE,
    punctuate: 'true',
    smart_format: 'true',
    paragraphs: 'true',
    utterances: 'true',
    diarize: 'false',
  });
  return fetchJsonOrThrow(
    `${DEEPGRAM_BASE_URL.replace(/\/$/, '')}/v1/listen?${query.toString()}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${requireApiKey('Deepgram STT', ['DEEPGRAM_API_KEY'])}`,
        'Content-Type': mimeType || 'application/octet-stream',
      },
      body: audioBytes,
      signal,
    },
    'Deepgram request failed',
    { maxResponseBytes: 10 * 1024 * 1024, timeoutMs: 60000 },
  );
}

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
  streamResponseFormat: 'pcm',
  streamMimeType: 'audio/wav',
  pcmSampleRate: 24000,
  pcmChannels: 1,
  pcmBitsPerSample: 16,
  deepgramEncoding: 'linear16',
  deepgramContainer: 'wav',
  deepgramStreamContainer: 'none',
});
const MIN_STREAM_PCM_CHUNK_BYTES = 24000;
const MAX_STREAM_PCM_CHUNK_BYTES = 48000;
const DEFAULT_STT_TIMEOUT_MS = 60000;
const DEFAULT_TTS_TIMEOUT_MS = 30000;
const MAX_JSON_RESPONSE_BYTES = 40 * 1024 * 1024;
const MAX_AUDIO_RESPONSE_BYTES = 32 * 1024 * 1024;

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

function responseError(prefix, status, body) {
  const error = new Error(
    `${prefix} (${status}): ${String(body || 'empty response').slice(0, 2000)}`,
  );
  error.status = status;
  return error;
}

async function fetchJsonOrThrow(url, init, errorPrefix, options = {}) {
  const { response, text } = await fetchResponseText(url, {
    ...init,
    timeoutMs: options.timeoutMs || DEFAULT_STT_TIMEOUT_MS,
    maxResponseBytes: options.maxResponseBytes || MAX_JSON_RESPONSE_BYTES,
    serviceName: errorPrefix,
    timeoutCode: 'VOICE_PROVIDER_TIMEOUT',
    tooLargeCode: 'VOICE_PROVIDER_RESPONSE_TOO_LARGE',
  });
  if (!response.ok) throw responseError(errorPrefix, response.status, text);
  try {
    return JSON.parse(text);
  } catch (cause) {
    throw new Error(`${errorPrefix}: provider returned malformed JSON.`, { cause });
  }
}

async function fetchAudioOrThrow(
  url,
  init,
  errorPrefix,
  defaultMimeType = 'audio/mpeg',
  options = {},
) {
  const { response, body } = await fetchResponseBuffer(url, {
    ...init,
    timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS,
    maxResponseBytes: options.maxResponseBytes || MAX_AUDIO_RESPONSE_BYTES,
    serviceName: errorPrefix,
    timeoutCode: 'VOICE_PROVIDER_TIMEOUT',
    tooLargeCode: 'VOICE_PROVIDER_RESPONSE_TOO_LARGE',
  });
  if (!response.ok) {
    throw responseError(errorPrefix, response.status, body.toString('utf8'));
  }
  return {
    audioBytes: body,
    mimeType: response.headers.get('content-type') || defaultMimeType,
  };
}

async function fetchAudioStreamOrThrow(
  url,
  init,
  errorPrefix,
  defaultMimeType,
  onChunk,
  options = {},
) {
  const audio = await fetchAudioOrThrow(
    url,
    init,
    errorPrefix,
    defaultMimeType,
    options,
  );
  await onChunk(audio);
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

async function emitPcmBufferAsWavChunks(audioBytes, format, onChunk, signal = null) {
  const source = Buffer.isBuffer(audioBytes) ? audioBytes : Buffer.from(audioBytes || []);
  for (let offset = 0; offset < source.length; offset += MAX_STREAM_PCM_CHUNK_BYTES) {
    throwIfAborted(signal, 'Voice synthesis aborted.');
    const end = Math.min(source.length, offset + MAX_STREAM_PCM_CHUNK_BYTES);
    const evenEnd = end - ((end - offset) % 2);
    if (evenEnd <= offset) continue;
    await onChunk({
      audioBytes: wrapPcmAsWav(source.subarray(offset, evenEnd), format),
      mimeType: WEARABLE_SAFE_AUDIO_FORMAT.streamMimeType,
    });
  }
}

async function streamPcmAsWavChunks(readable, format, onChunk, options = {}) {
  const source = readable && typeof readable.getReader === 'function'
    ? readable
    : null;
  let pending = Buffer.alloc(0);
  let totalBytes = 0;

  async function flushPending(force = false) {
    while (pending.length >= MIN_STREAM_PCM_CHUNK_BYTES || (force && pending.length > 0)) {
      const targetLength = force
        ? pending.length
        : Math.min(pending.length, MAX_STREAM_PCM_CHUNK_BYTES);
      const evenLength = targetLength - (targetLength % 2);
      if (evenLength <= 0) return;
      const pcmChunk = pending.subarray(0, evenLength);
      pending = pending.subarray(evenLength);
      throwIfAborted(options.signal, 'Voice synthesis aborted.');
      await onChunk({
        audioBytes: wrapPcmAsWav(pcmChunk, format),
        mimeType: WEARABLE_SAFE_AUDIO_FORMAT.streamMimeType,
      });
    }
  }

  if (source) {
    const reader = source.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value?.length) {
        totalBytes += value.length;
        if (totalBytes > MAX_AUDIO_RESPONSE_BYTES) {
          await reader.cancel().catch(() => {});
          const error = new Error('Voice audio response exceeded its safety limit.');
          error.code = 'VOICE_PROVIDER_RESPONSE_TOO_LARGE';
          throw error;
        }
        pending = Buffer.concat([pending, Buffer.from(value)]);
        await flushPending(false);
      }
    }
  } else {
    for await (const chunk of readable) {
      if (chunk?.length) {
        const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
        totalBytes += buffer.length;
        if (totalBytes > MAX_AUDIO_RESPONSE_BYTES) {
          const error = new Error('Voice audio response exceeded its safety limit.');
          error.code = 'VOICE_PROVIDER_RESPONSE_TOO_LARGE';
          throw error;
        }
        pending = Buffer.concat([pending, buffer]);
        await flushPending(false);
      }
    }
  }
  await flushPending(true);
}

async function transcribeWithOpenAi(filePath, model, options = {}) {
  const client = getOpenAiClient({
    apiKey: typeof options.apiKey === 'string' ? options.apiKey.trim() : '',
    baseUrl: typeof options.baseUrl === 'string' ? options.baseUrl.trim() : '',
  });
  if (!client) {
    throw new Error('OpenAI STT is selected but OPENAI_API_KEY is not configured.');
  }
  const file = fs.createReadStream(filePath);
  const abortFile = () => file.destroy(createAbortError(options.signal));
  options.signal?.addEventListener('abort', abortFile, { once: true });
  try {
    const transcription = await client.audio.transcriptions.create({
      file,
      model,
    }, { signal: options.signal });
    return String(transcription?.text || '').trim();
  } finally {
    options.signal?.removeEventListener('abort', abortFile);
    file.destroy();
  }
}

async function transcribeWithDeepgram(filePath, mimeType, options = {}) {
  const audioBytes = await fs.promises.readFile(filePath, { signal: options.signal });
  const payload = await transcribeChunkWithDeepgram({
    audioBytes,
    mimeType: mimeType || 'audio/mpeg',
    detectLanguage: 'multi',
    signal: options.signal,
  });

  const transcript = payload?.results?.channels?.[0]?.alternatives?.[0]?.transcript;
  return String(transcript || '').trim();
}

async function transcribeWithGemini(filePath, model, mimeType, options = {}) {
  const apiKey =
    (typeof options.apiKey === 'string' ? options.apiKey.trim() : '') ||
    requireApiKey('Gemini STT', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);

  const audioBytes = await fs.promises.readFile(filePath, { signal: options.signal });
  const payload = await fetchJsonOrThrow(
    `${GEMINI_API_BASE_URL}/${encodeURIComponent(model)}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
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
      signal: options.signal,
    },
    'Gemini STT request failed',
    { maxResponseBytes: MAX_JSON_RESPONSE_BYTES, timeoutMs: DEFAULT_STT_TIMEOUT_MS },
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
  return runWithAbortTimeout(async (signal) => {
    const requestOptions = { ...options, signal };
    if (provider === 'openai') {
      return transcribeWithOpenAi(filePath, model, requestOptions);
    }
    if (provider === 'deepgram') {
      return transcribeWithDeepgram(filePath, options.mimeType, requestOptions);
    }
    return transcribeWithGemini(filePath, model, options.mimeType, requestOptions);
  }, {
    signal: options.signal,
    timeoutMs: options.timeoutMs || DEFAULT_STT_TIMEOUT_MS,
    timeoutCode: 'VOICE_STT_TIMEOUT',
    label: `${provider} STT`,
  });
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
    signal: options.signal,
    timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS,
    maxResponseBytes: options.maxResponseBytes || MAX_AUDIO_RESPONSE_BYTES,
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
    response_format: useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.streamResponseFormat : 'mp3',
  }, { signal: options.signal });
  if (useWearableSafeAudio) {
    await streamPcmAsWavChunks(
      response.body,
      {
        bitsPerSample: WEARABLE_SAFE_AUDIO_FORMAT.pcmBitsPerSample,
        sampleRate: WEARABLE_SAFE_AUDIO_FORMAT.pcmSampleRate,
        channels: WEARABLE_SAFE_AUDIO_FORMAT.pcmChannels,
      },
      onChunk,
      { signal: options.signal },
    );
    return;
  }
  const chunks = [];
  let totalBytes = 0;
  for await (const chunk of response.body) {
    throwIfAborted(options.signal, 'OpenAI TTS stream aborted.');
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    totalBytes += buffer.length;
    if (totalBytes > MAX_AUDIO_RESPONSE_BYTES) {
      const error = new Error('OpenAI speech response exceeded its safety limit.');
      error.code = 'VOICE_PROVIDER_RESPONSE_TOO_LARGE';
      throw error;
    }
    chunks.push(buffer);
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
      signal: options.signal,
    },
    'Deepgram TTS request failed',
    useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.mimeType : 'audio/mpeg',
    { timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS },
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
    searchParams.set('container', WEARABLE_SAFE_AUDIO_FORMAT.deepgramStreamContainer);
    searchParams.set('sample_rate', String(WEARABLE_SAFE_AUDIO_FORMAT.pcmSampleRate));
    const audio = await fetchAudioOrThrow(
      `https://api.deepgram.com/v1/speak?${searchParams.toString()}`,
      {
        method: 'POST',
        headers: {
          Authorization: `Token ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text }),
        signal: options.signal,
      },
      'Deepgram TTS stream failed',
      'audio/pcm',
      { timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS },
    );
    await emitPcmBufferAsWavChunks(
      audio.audioBytes,
      {
        bitsPerSample: WEARABLE_SAFE_AUDIO_FORMAT.pcmBitsPerSample,
        sampleRate: WEARABLE_SAFE_AUDIO_FORMAT.pcmSampleRate,
        channels: WEARABLE_SAFE_AUDIO_FORMAT.pcmChannels,
      },
      onChunk,
      options.signal,
    );
    return;
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
      signal: options.signal,
    },
    'Deepgram TTS stream failed',
    useWearableSafeAudio ? WEARABLE_SAFE_AUDIO_FORMAT.mimeType : 'audio/mpeg',
    onChunk,
    { timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS },
  );
}

async function synthesizeWithGemini(text, model, voice, options = {}) {
  const apiKey =
    (typeof options.apiKey === 'string' ? options.apiKey.trim() : '') ||
    requireApiKey('Gemini TTS', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY']);

  const payload = await fetchJsonOrThrow(
    `${GEMINI_API_BASE_URL}/${encodeURIComponent(model)}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
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
      signal: options.signal,
    },
    'Gemini TTS request failed',
    { maxResponseBytes: MAX_JSON_RESPONSE_BYTES, timeoutMs: DEFAULT_TTS_TIMEOUT_MS },
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

  const { response, text: eventStream } = await fetchResponseText(
    `${GEMINI_API_BASE_URL}/${encodeURIComponent(model)}:streamGenerateContent?alt=sse`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
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
      signal: options.signal,
      timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS,
      maxResponseBytes: MAX_JSON_RESPONSE_BYTES,
      serviceName: 'Gemini TTS stream',
      timeoutCode: 'VOICE_PROVIDER_TIMEOUT',
      tooLargeCode: 'VOICE_PROVIDER_RESPONSE_TOO_LARGE',
    },
  );
  if (!response.ok) {
    throw responseError('Gemini TTS stream request failed', response.status, eventStream);
  }

  let totalAudioBytes = 0;
  for (const line of eventStream.split('\n')) {
    throwIfAborted(options.signal, 'Gemini TTS stream aborted.');
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
    if (!chunk) continue;
    totalAudioBytes += chunk.audioBytes.length;
    if (totalAudioBytes > MAX_AUDIO_RESPONSE_BYTES) {
      const error = new Error('Gemini speech response exceeded its safety limit.');
      error.code = 'VOICE_PROVIDER_RESPONSE_TOO_LARGE';
      throw error;
    }
    await onChunk(chunk);
  }
}

async function synthesizeVoiceReply(text, options = {}) {
  const content = String(text || '').trim();
  if (!content) {
    throw new Error('Voice reply text is empty; cannot synthesize speech.');
  }

  const { provider, model, voice } = normalizeVoiceSynthesisOptions(options);
  return runWithAbortTimeout(async (signal) => {
    const requestOptions = { ...options, signal };
    if (provider === 'openai') {
      return synthesizeWithOpenAi(content, model, voice, requestOptions);
    }
    if (provider === 'deepgram') {
      return synthesizeWithDeepgram(content, model, requestOptions);
    }
    return synthesizeWithGemini(content, model, voice, requestOptions);
  }, {
    signal: options.signal,
    timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS,
    timeoutCode: 'VOICE_TTS_TIMEOUT',
    label: `${provider} TTS`,
  });
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
    await runWithAbortTimeout(async (signal) => {
      const requestOptions = { ...options, signal };
      if (provider === 'openai') {
        await streamWithOpenAi(chunk, model, voice, requestOptions, onChunk);
      } else if (provider === 'deepgram') {
        await streamWithDeepgram(chunk, model, requestOptions, onChunk);
      } else {
        await streamWithGemini(chunk, model, voice, requestOptions, onChunk);
      }
    }, {
      signal: options.signal,
      timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS,
      timeoutCode: 'VOICE_TTS_TIMEOUT',
      label: `${provider} TTS stream`,
    });
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
