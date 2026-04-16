'use strict';

const fs = require('fs');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { getOpenAiClient } = require('./openaiClient');

const DEFAULT_STT_PROVIDER = 'openai';
const DEFAULT_STT_MODELS = {
  openai: 'whisper-1',
  deepgram: process.env.DEEPGRAM_MODEL || 'nova-3',
  gemini: 'gemini-2.0-flash-lite',
};

function normalizeSttProvider(provider) {
  const value = String(provider || '').trim().toLowerCase();
  if (value === 'openai' || value === 'deepgram' || value === 'gemini') {
    return value;
  }
  return DEFAULT_STT_PROVIDER;
}

function resolveSttModel(provider, model) {
  const normalizedProvider = normalizeSttProvider(provider);
  const candidate = String(model || '').trim();
  if (candidate) return candidate;
  return DEFAULT_STT_MODELS[normalizedProvider] || DEFAULT_STT_MODELS.openai;
}

async function transcribeWithOpenAi(filePath, model, openAiClient) {
  const client = openAiClient || getOpenAiClient();
  if (!client) {
    throw new Error('OPENAI_API_KEY is not configured.');
  }
  const response = await client.audio.transcriptions.create({
    file: fs.createReadStream(filePath),
    model,
  });
  return String(response?.text || '').trim();
}

async function transcribeWithDeepgram(filePath, model) {
  const apiKey = String(process.env.DEEPGRAM_API_KEY || '').trim();
  if (!apiKey) {
    throw new Error('DEEPGRAM_API_KEY is not configured.');
  }
  const baseUrl = String(process.env.DEEPGRAM_BASE_URL || 'https://api.deepgram.com').replace(/\/$/, '');
  const language = String(process.env.DEEPGRAM_LANGUAGE || 'multi').trim() || 'multi';
  const audioBytes = await fs.promises.readFile(filePath);
  const query = new URLSearchParams({
    model,
    language,
    punctuate: 'true',
    smart_format: 'true',
    paragraphs: 'true',
    utterances: 'true',
    diarize: 'false',
  });
  const response = await fetch(`${baseUrl}/v1/listen?${query.toString()}`, {
    method: 'POST',
    headers: {
      Authorization: `Token ${apiKey}`,
      'Content-Type': 'audio/mpeg',
    },
    body: audioBytes,
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Deepgram STT failed (${response.status}): ${body || 'empty response'}`);
  }
  const payload = await response.json();
  const transcript = payload?.results?.channels?.[0]?.alternatives?.[0]?.transcript;
  return String(transcript || '').trim();
}

async function transcribeWithGemini(filePath, model) {
  const apiKey = String(process.env.GOOGLE_AI_KEY || process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) {
    throw new Error('GOOGLE_AI_KEY is not configured.');
  }
  const bytes = await fs.promises.readFile(filePath);
  const client = new GoogleGenerativeAI(apiKey);
  const geminiModel = client.getGenerativeModel({ model });
  const result = await geminiModel.generateContent([
    {
      inlineData: {
        mimeType: 'audio/mpeg',
        data: bytes.toString('base64'),
      },
    },
    {
      text: 'Transcribe this audio accurately. Return only the transcript text with punctuation.',
    },
  ]);
  const response = result?.response;
  if (!response) return '';
  if (typeof response.text === 'function') {
    return String(response.text() || '').trim();
  }
  return String(response?.candidates?.[0]?.content?.parts?.[0]?.text || '').trim();
}

async function transcribeAudioFile(filePath, { provider, model, openAiClient } = {}) {
  const resolvedProvider = normalizeSttProvider(provider);
  const resolvedModel = resolveSttModel(resolvedProvider, model);
  if (resolvedProvider === 'deepgram') {
    return transcribeWithDeepgram(filePath, resolvedModel);
  }
  if (resolvedProvider === 'gemini') {
    return transcribeWithGemini(filePath, resolvedModel);
  }
  return transcribeWithOpenAi(filePath, resolvedModel, openAiClient);
}

module.exports = {
  DEFAULT_STT_PROVIDER,
  DEFAULT_STT_MODELS,
  normalizeSttProvider,
  resolveSttModel,
  transcribeAudioFile,
};
