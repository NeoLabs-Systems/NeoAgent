'use strict';

/**
 * Embedding helpers for the semantic memory system.
 *
 * Provider selection (in priority order):
 *   1. Google (text-embedding-004, 768 dims) — when provider hint is 'google' and GOOGLE_AI_KEY is set
 *   2. OpenAI (text-embedding-3-small, 1536 dims) — when OPENAI_API_KEY is set
 *   3. Keyword fallback — when no API key is available
 */

const https = require('https');

const OPENAI_MODEL = 'text-embedding-3-small';
const OPENAI_DIM = 1536;
const GOOGLE_MODEL = 'text-embedding-004';
const GOOGLE_DIM = 768;

// Exported so callers can sanity-check stored vector dimensions if needed
const EMBED_DIM = OPENAI_DIM;
const EMBED_DIM_GOOGLE = GOOGLE_DIM;

async function getGeminiEmbedding(text) {
  const apiKey = process.env.GOOGLE_AI_KEY;
  if (!apiKey) return null;
  if (!text || !text.trim()) return null;

  const truncated = text.slice(0, 25000);

  return new Promise((resolve) => {
    const body = JSON.stringify({
      model: `models/${GOOGLE_MODEL}`,
      content: { parts: [{ text: truncated }] }
    });

    const path = `/v1beta/models/${GOOGLE_MODEL}:embedContent?key=${apiKey}`;
    const options = {
      hostname: 'generativelanguage.googleapis.com',
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          const vec = parsed.embedding?.values;
          if (!vec) return resolve(null);
          resolve(new Float32Array(vec));
        } catch {
          resolve(null);
        }
      });
    });

    req.on('error', () => resolve(null));
    req.setTimeout(15000, () => { req.destroy(); resolve(null); });
    req.write(body);
    req.end();
  });
}

async function getOpenAIEmbedding(text) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;
  if (!text || !text.trim()) return null;

  const truncated = text.slice(0, 25000);

  return new Promise((resolve) => {
    const body = JSON.stringify({
      model: OPENAI_MODEL,
      input: truncated,
      encoding_format: 'float'
    });

    const options = {
      hostname: 'api.openai.com',
      path: '/v1/embeddings',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.error) return resolve(null);
          const vec = parsed.data?.[0]?.embedding;
          if (!vec) return resolve(null);
          resolve(new Float32Array(vec));
        } catch {
          resolve(null);
        }
      });
    });

    req.on('error', () => resolve(null));
    req.setTimeout(15000, () => { req.destroy(); resolve(null); });
    req.write(body);
    req.end();
  });
}

/**
 * Get an embedding vector for a piece of text.
 * @param {string} text
 * @param {string} [provider] - 'google' to prefer Gemini embeddings
 * @returns {Float32Array|null}
 */
async function getEmbedding(text, provider) {
  if (!text || !text.trim()) return null;
  if (provider === 'google' && process.env.GOOGLE_AI_KEY) {
    const vec = await getGeminiEmbedding(text);
    if (vec) return vec;
  }
  return getOpenAIEmbedding(text);
}

/**
 * Cosine similarity between two Float32Arrays.
 * Returns a value in [-1, 1]; higher = more similar.
 */
function cosineSimilarity(a, b) {
  if (!a || !b || a.length !== b.length) return 0;
  let dot = 0, magA = 0, magB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    magA += a[i] * a[i];
    magB += b[i] * b[i];
  }
  const denom = Math.sqrt(magA) * Math.sqrt(magB);
  return denom === 0 ? 0 : dot / denom;
}

/**
 * Serialize a Float32Array to a JSON string for SQLite TEXT storage.
 */
function serializeEmbedding(vec) {
  if (!vec) return null;
  return JSON.stringify(Array.from(vec));
}

/**
 * Deserialize a JSON string back to a Float32Array.
 */
function deserializeEmbedding(str) {
  if (!str) return null;
  try {
    const arr = JSON.parse(str);
    return new Float32Array(arr);
  } catch {
    return null;
  }
}

/**
 * Keyword-based fallback similarity when embeddings are unavailable.
 * Returns 0–1 based on term overlap.
 */
function keywordSimilarity(query, text) {
  if (!query || !text) return 0;
  const tokens = (s) => s.toLowerCase().split(/\W+/).filter(t => t.length > 2);
  const qTokens = new Set(tokens(query));
  const tTokens = tokens(text);
  if (!qTokens.size || !tTokens.length) return 0;
  let hits = 0;
  for (const t of tTokens) { if (qTokens.has(t)) hits++; }
  return hits / Math.max(qTokens.size, tTokens.length);
}

module.exports = {
  getEmbedding,
  cosineSimilarity,
  serializeEmbedding,
  deserializeEmbedding,
  keywordSimilarity,
  EMBED_DIM,
  EMBED_DIM_GOOGLE
};
