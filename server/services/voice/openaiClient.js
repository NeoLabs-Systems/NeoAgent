'use strict';

const fs = require('fs');
const path = require('path');
const { OpenAI } = require('openai');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');
const { decryptLocalValue } = require('../../utils/local_secrets');

let cachedClient = null;

function resolveOpenAiApiKey() {
  if (typeof process.env.OPENAI_API_KEY === 'string' && process.env.OPENAI_API_KEY.trim()) {
    return process.env.OPENAI_API_KEY.trim();
  }

  try {
    const keysPath = path.join(AGENT_DATA_DIR, 'API_KEYS.json');
    const keys = JSON.parse(fs.readFileSync(keysPath, 'utf8'));
    const candidate = decryptLocalValue(keys.OPENAI_API_KEY)
      || decryptLocalValue(keys.openai_api_key)
      || decryptLocalValue(keys.openai);
    return typeof candidate === 'string' && candidate.trim() ? candidate.trim() : '';
  } catch {
    return '';
  }
}

function getOpenAiClient(options = {}) {
  const overrideApiKey = typeof options.apiKey === 'string' ? options.apiKey.trim() : '';
  const overrideBaseUrl = typeof options.baseUrl === 'string' ? options.baseUrl.trim() : '';

  if (overrideApiKey) {
    return new OpenAI({
      apiKey: overrideApiKey,
      baseURL: overrideBaseUrl || undefined,
    });
  }

  if (cachedClient) return cachedClient;
  const apiKey = resolveOpenAiApiKey();
  if (!apiKey) return null;
  cachedClient = new OpenAI({ apiKey });
  return cachedClient;
}

module.exports = {
  getOpenAiClient,
  resolveOpenAiApiKey,
};
