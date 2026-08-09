'use strict';

const { runWithAbortTimeout } = require('../../utils/abort');
const deepgram = require('./providers/deepgram_provider');
const gemini = require('./providers/gemini_provider');
const openai = require('./providers/openai_provider');
const defaults = require('./providers/provider_defaults');

const DEFAULT_STT_TIMEOUT_MS = 60000;
const DEFAULT_TTS_TIMEOUT_MS = 30000;
const MIN_SENTENCE_CHUNK_CHARS = 80;
const MAX_TTS_CHUNK_CHARS = 220;

const IMPLEMENTATIONS = Object.freeze({ openai, deepgram, gemini });

function guessExtFromMimeType(mimeType) {
  const mime = String(mimeType || '').toLowerCase();
  if (mime.includes('wav')) return 'wav';
  if (mime.includes('ogg')) return 'ogg';
  if (mime.includes('mpeg') || mime.includes('mp3')) return 'mp3';
  return 'mp3';
}

async function transcribeVoiceInput(filePath, options = {}) {
  const provider = defaults.normalizeSttProvider(options.provider);
  const model = defaults.resolveSttModel(provider, options.model);
  return runWithAbortTimeout((signal) => IMPLEMENTATIONS[provider].transcribe(
    filePath,
    model,
    options.mimeType,
    { ...options, signal },
  ), {
    signal: options.signal,
    timeoutMs: options.timeoutMs || DEFAULT_STT_TIMEOUT_MS,
    timeoutCode: 'VOICE_STT_TIMEOUT',
    label: `${provider} STT`,
  });
}

async function synthesizeVoiceReply(text, options = {}) {
  const content = String(text || '').trim();
  if (!content) throw new Error('Voice reply text is empty; cannot synthesize speech.');
  const normalized = defaults.normalizeVoiceSynthesisOptions(options);
  return runWithAbortTimeout((signal) => IMPLEMENTATIONS[normalized.provider].synthesize(
    content,
    normalized.model,
    normalized.voice,
    { ...options, signal },
  ), {
    signal: options.signal,
    timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS,
    timeoutCode: 'VOICE_TTS_TIMEOUT',
    label: `${normalized.provider} TTS`,
  });
}

function splitOversizeChunk(text, maxChars = MAX_TTS_CHUNK_CHARS) {
  const normalized = String(text || '').trim();
  if (!normalized) return [];
  if (normalized.length <= maxChars) return [normalized];
  const chunks = [];
  let pending = '';
  for (const word of normalized.split(/\s+/).filter(Boolean)) {
    const candidate = pending ? `${pending} ${word}` : word;
    if (pending && candidate.length > maxChars) {
      chunks.push(pending);
      pending = word;
    } else if (!pending && candidate.length > maxChars) {
      for (let index = 0; index < word.length; index += maxChars) {
        chunks.push(word.slice(index, index + maxChars));
      }
    } else {
      pending = candidate;
    }
  }
  if (pending) chunks.push(pending);
  return chunks;
}

function splitIntoSentenceChunks(text) {
  const normalized = String(text || '').trim();
  if (!normalized) return [];
  const chunks = [];
  let pending = '';
  for (const part of normalized.split(/(?<=[.!?])(?=\s|$)/)) {
    const piece = part.trim();
    if (!piece) continue;
    pending = pending ? `${pending} ${piece}` : piece;
    if (pending.length >= MIN_SENTENCE_CHUNK_CHARS) {
      chunks.push(...splitOversizeChunk(pending));
      pending = '';
    }
  }
  if (pending) chunks.push(...splitOversizeChunk(pending));
  return chunks.length ? chunks : [normalized];
}

async function synthesizeVoiceReplyStream(text, options = {}, onChunk) {
  const content = String(text || '').trim();
  if (!content) throw new Error('Voice reply text is empty; cannot synthesize speech.');
  if (typeof onChunk !== 'function') throw new Error('Voice stream callback is required.');
  const normalized = defaults.normalizeVoiceSynthesisOptions(options);
  for (const chunk of splitIntoSentenceChunks(content)) {
    await runWithAbortTimeout((signal) => IMPLEMENTATIONS[normalized.provider].stream(
      chunk,
      normalized.model,
      normalized.voice,
      { ...options, signal },
      onChunk,
    ), {
      signal: options.signal,
      timeoutMs: options.timeoutMs || DEFAULT_TTS_TIMEOUT_MS,
      timeoutCode: 'VOICE_TTS_TIMEOUT',
      label: `${normalized.provider} TTS stream`,
    });
  }
}

module.exports = {
  ...defaults,
  guessExtFromMimeType,
  splitIntoSentenceChunks,
  synthesizeVoiceReply,
  synthesizeVoiceReplyStream,
  transcribeVoiceInput,
};
