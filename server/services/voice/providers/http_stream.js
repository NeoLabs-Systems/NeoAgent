'use strict';

const MAX_RESPONSE_BYTES = 40 * 1024 * 1024;

async function providerResponse(url, init, label) {
  const response = await fetch(url, init);
  if (response.ok) return response;
  const body = (await response.text()).slice(0, 2000);
  const error = new Error(`${label} (${response.status}): ${body || 'empty response'}`);
  error.status = response.status;
  throw error;
}

async function readBounded(response, maxBytes = MAX_RESPONSE_BYTES) {
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

module.exports = {
  providerResponse,
  readBounded,
};
