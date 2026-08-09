'use strict';

const { throwIfAborted } = require('../../../utils/abort');

const MAX_AUDIO_BYTES = 32 * 1024 * 1024;
const MAX_TEXT_BYTES = 40 * 1024 * 1024;

async function providerResponse(url, init, label) {
  const response = await fetch(url, init);
  if (response.ok) return response;
  const body = (await response.text()).slice(0, 2000);
  const error = new Error(`${label} (${response.status}): ${body || 'empty response'}`);
  error.status = response.status;
  throw error;
}

async function readBounded(response, maxBytes = MAX_TEXT_BYTES) {
  const chunks = [];
  let total = 0;
  for await (const chunk of response.body) {
    const bytes = Buffer.from(chunk);
    total += bytes.length;
    if (total > maxBytes) {
      const error = new Error('Voice provider response exceeded its safety limit.');
      error.code = 'VOICE_PROVIDER_RESPONSE_TOO_LARGE';
      throw error;
    }
    chunks.push(bytes);
  }
  return Buffer.concat(chunks);
}

async function streamBytes(response, onChunk, options = {}) {
  let total = 0;
  for await (const raw of response.body) {
    throwIfAborted(options.signal, 'Voice provider stream aborted.');
    const chunk = Buffer.from(raw);
    total += chunk.length;
    if (total > (options.maxBytes || MAX_AUDIO_BYTES)) {
      const error = new Error('Voice provider response exceeded its safety limit.');
      error.code = 'VOICE_PROVIDER_RESPONSE_TOO_LARGE';
      throw error;
    }
    if (chunk.length) await onChunk(chunk);
  }
}

module.exports = {
  MAX_AUDIO_BYTES,
  MAX_TEXT_BYTES,
  providerResponse,
  readBounded,
  streamBytes,
};
