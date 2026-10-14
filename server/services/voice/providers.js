'use strict';

const { runWithAbortTimeout } = require('../../utils/abort');
const deepgram = require('./providers/deepgram_provider');
const gemini = require('./providers/gemini_provider');
const openai = require('./providers/openai_provider');
const defaults = require('./providers/provider_defaults');

const DEFAULT_STT_TIMEOUT_MS = 60000;

const IMPLEMENTATIONS = Object.freeze({ openai, deepgram, gemini });

// Bounded speech-to-text for recorded audio: messaging voice notes, dictation,
// the transcribe_audio tool, and social video. Live calls never pass through
// here; the live model hears the caller directly.
async function transcribeVoiceInput(filePath, options = {}) {
  const provider = defaults.normalizeSttProvider(options.provider);
  if (!IMPLEMENTATIONS[provider]) throw new Error(`Unknown speech-to-text provider: ${options.provider}`);
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

module.exports = {
  ...defaults,
  transcribeVoiceInput,
};
