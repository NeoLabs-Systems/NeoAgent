'use strict';

const { GoogleGenerativeAI } = require('@google/generative-ai');
const { getOpenAiClient } = require('./openaiClient');
const { synthesizeSpeechBuffer } = require('./openaiSpeech');

const DEFAULT_TTS_PROVIDER = 'openai';
const DEFAULT_TTS_MODELS = {
  openai: 'tts-1',
  deepgram: 'aura-2-thalia-en',
  gemini: 'gemini-2.5-flash-preview-tts',
};

function normalizeTtsProvider(provider) {
  const value = String(provider || '').trim().toLowerCase();
  if (value === 'openai' || value === 'deepgram' || value === 'gemini') {
    return value;
  }
  return DEFAULT_TTS_PROVIDER;
}

function resolveTtsModel(provider, model) {
  const normalizedProvider = normalizeTtsProvider(provider);
  const candidate = String(model || '').trim();
  if (candidate) return candidate;
  return DEFAULT_TTS_MODELS[normalizedProvider] || DEFAULT_TTS_MODELS.openai;
}

async function synthesizeWithOpenAi(text, { model, voice, openAiClient } = {}) {
  const client = openAiClient || getOpenAiClient();
  if (!client) {
    throw new Error('OPENAI_API_KEY is not configured.');
  }
  return synthesizeSpeechBuffer(client, text, { model, voice });
}

async function synthesizeWithDeepgram(text, { model } = {}) {
  const apiKey = String(process.env.DEEPGRAM_API_KEY || '').trim();
  if (!apiKey) {
    throw new Error('DEEPGRAM_API_KEY is not configured.');
  }
  const baseUrl = String(process.env.DEEPGRAM_BASE_URL || 'https://api.deepgram.com').replace(/\/$/, '');
  const response = await fetch(`${baseUrl}/v1/speak?model=${encodeURIComponent(model)}`, {
    method: 'POST',
    headers: {
      Authorization: `Token ${apiKey}`,
      'Content-Type': 'application/json',
      Accept: 'audio/mpeg',
    },
    body: JSON.stringify({ text }),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Deepgram TTS failed (${response.status}): ${body || 'empty response'}`);
  }
  return Buffer.from(await response.arrayBuffer());
}

function decodeGeminiAudioBase64(payload) {
  const parts = payload?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return null;
  for (const part of parts) {
    const base64 = part?.inlineData?.data;
    if (typeof base64 === 'string' && base64.trim()) {
      return Buffer.from(base64, 'base64');
    }
  }
  return null;
}

async function synthesizeWithGemini(text, { model, voice } = {}) {
  const apiKey = String(process.env.GOOGLE_AI_KEY || process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) {
    throw new Error('GOOGLE_AI_KEY is not configured.');
  }
  const client = new GoogleGenerativeAI(apiKey);
  const geminiModel = client.getGenerativeModel({ model });
  const result = await geminiModel.generateContent({
    contents: [{ role: 'user', parts: [{ text }] }],
    generationConfig: {
      responseModalities: ['AUDIO'],
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: {
            voiceName: String(voice || 'Kore'),
          },
        },
      },
    },
  });
  const response = result?.response;
  const audioBuffer = decodeGeminiAudioBase64(response);
  if (!audioBuffer || audioBuffer.length === 0) {
    throw new Error('Gemini TTS did not return audio.');
  }
  return audioBuffer;
}

async function synthesizeSpeechWithProvider(text, { provider, model, voice, openAiClient } = {}) {
  const resolvedProvider = normalizeTtsProvider(provider);
  const resolvedModel = resolveTtsModel(resolvedProvider, model);
  if (resolvedProvider === 'deepgram') {
    return synthesizeWithDeepgram(text, { model: resolvedModel });
  }
  if (resolvedProvider === 'gemini') {
    return synthesizeWithGemini(text, { model: resolvedModel, voice });
  }
  return synthesizeWithOpenAi(text, {
    model: resolvedModel,
    voice,
    openAiClient,
  });
}

module.exports = {
  DEFAULT_TTS_PROVIDER,
  DEFAULT_TTS_MODELS,
  normalizeTtsProvider,
  resolveTtsModel,
  synthesizeSpeechWithProvider,
};
