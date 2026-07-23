'use strict';

/**
 * Embedding helpers for the semantic memory system.
 *
 * Provider selection (in priority order):
 *   1. Google (gemini-embedding-2, 768 dims) — when provider hint is 'google' and GOOGLE_AI_KEY is set
 *   2. OpenAI (text-embedding-3-small, 1536 dims) — when OPENAI_API_KEY is set
 *   3. Keyword fallback — when no API key is available
 */

const https = require('https');
const {
  createAbortError,
  isAbortError,
  throwIfAborted,
} = require('../../utils/abort');

const OPENAI_MODEL = 'text-embedding-3-small';
const OPENAI_DIM = 1536;
const GOOGLE_MODEL = 'gemini-embedding-2';
const GOOGLE_DIM = 768;
const EMBEDDING_TIMEOUT_MS = 15000;
const MAX_EMBEDDING_RESPONSE_BYTES = 2 * 1024 * 1024;

// Exported so callers can sanity-check stored vector dimensions if needed
const EMBED_DIM = OPENAI_DIM;
const EMBED_DIM_GOOGLE = GOOGLE_DIM;

function toEmbeddingVector(value, expectedDimensions) {
  if (!Array.isArray(value) || value.length !== expectedDimensions) return null;
  const vector = new Float32Array(value.length);
  for (let index = 0; index < value.length; index += 1) {
    const number = Number(value[index]);
    if (!Number.isFinite(number)) return null;
    vector[index] = number;
  }
  return vector;
}

function requestEmbeddingJson({ hostname, path, headers, body, signal }) {
  throwIfAborted(signal, 'Embedding request aborted.');
  return new Promise((resolve, reject) => {
    let settled = false;
    let request = null;
    let response = null;
    let timer = null;

    const cleanup = () => {
      if (timer) clearTimeout(timer);
      signal?.removeEventListener('abort', onAbort);
    };
    const finish = (error, value = null) => {
      if (settled) return;
      settled = true;
      cleanup();
      if (error) reject(error);
      else resolve(value);
    };
    const onAbort = () => {
      const error = createAbortError(signal, 'Embedding request aborted.');
      response?.destroy(error);
      request?.destroy(error);
      finish(error);
    };
    signal?.addEventListener('abort', onAbort, { once: true });

    timer = setTimeout(() => {
      request?.destroy();
      response?.destroy();
      finish(null, null);
    }, EMBEDDING_TIMEOUT_MS);

    request = https.request({
      hostname,
      path,
      method: 'POST',
      headers: {
        ...headers,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    }, (incoming) => {
      response = incoming;
      if (settled) {
        incoming.destroy();
        return;
      }
      if (incoming.statusCode < 200 || incoming.statusCode >= 300) {
        incoming.destroy();
        finish(null, null);
        return;
      }
      const contentLength = Number(incoming.headers?.['content-length']);
      if (
        Number.isFinite(contentLength)
        && contentLength > MAX_EMBEDDING_RESPONSE_BYTES
      ) {
        incoming.destroy();
        finish(null, null);
        return;
      }

      const chunks = [];
      let totalBytes = 0;
      incoming.on('data', (chunk) => {
        if (settled) return;
        const buffer = Buffer.from(chunk);
        totalBytes += buffer.byteLength;
        if (totalBytes > MAX_EMBEDDING_RESPONSE_BYTES) {
          incoming.destroy();
          finish(null, null);
          return;
        }
        chunks.push(buffer);
      });
      incoming.on('end', () => {
        if (settled) return;
        try {
          finish(null, JSON.parse(Buffer.concat(chunks, totalBytes).toString('utf8')));
        } catch {
          finish(null, null);
        }
      });
      incoming.on('error', (error) => {
        if (isAbortError(error, signal)) finish(createAbortError(signal));
        else finish(null, null);
      });
      incoming.on('aborted', () => {
        if (signal?.aborted) finish(createAbortError(signal));
        else finish(null, null);
      });
    });

    request.on('error', (error) => {
      if (isAbortError(error, signal)) finish(createAbortError(signal));
      else finish(null, null);
    });
    request.end(body);
  });
}

function formatGoogleEmbeddingInput(text, inputType) {
  if (inputType === 'query') return `task: search result | query: ${text}`;
  if (inputType === 'document') return `title: none | text: ${text}`;
  return `task: sentence similarity | query: ${text}`;
}

async function getGeminiEmbedding(text, options = {}) {
  const apiKey = process.env.GOOGLE_AI_KEY;
  if (!apiKey) return null;
  if (!text || !text.trim()) return null;

  const truncated = formatGoogleEmbeddingInput(
    text.slice(0, 25000),
    options.inputType,
  );
  const body = JSON.stringify({
    model: `models/${GOOGLE_MODEL}`,
    content: { parts: [{ text: truncated }] },
    output_dimensionality: GOOGLE_DIM,
  });
  const data = await requestEmbeddingJson({
    hostname: 'generativelanguage.googleapis.com',
    path: `/v1beta/models/${GOOGLE_MODEL}:embedContent`,
    headers: { 'x-goog-api-key': apiKey },
    body,
    signal: options.signal,
  });
  return toEmbeddingVector(data?.embedding?.values, GOOGLE_DIM);
}

async function getOpenAIEmbedding(text, options = {}) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;
  if (!text || !text.trim()) return null;

  const truncated = text.slice(0, 25000);

  const body = JSON.stringify({
    model: OPENAI_MODEL,
    input: truncated,
    encoding_format: 'float',
  });
  const data = await requestEmbeddingJson({
    hostname: 'api.openai.com',
    path: '/v1/embeddings',
    headers: { Authorization: `Bearer ${apiKey}` },
    body,
    signal: options.signal,
  });
  return toEmbeddingVector(data?.data?.[0]?.embedding, OPENAI_DIM);
}

/**
 * Get an embedding vector for a piece of text.
 * @param {string} text
 * @param {string} [provider] - 'google' to prefer Gemini embeddings
 * @returns {Float32Array|null}
 */
async function getEmbedding(text, provider, options = {}) {
  const result = await getEmbeddingWithMetadata(text, provider, options);
  return result?.vector || null;
}

async function getEmbeddingWithMetadata(text, provider, options = {}) {
  if (!text || !text.trim()) return null;
  throwIfAborted(options.signal, 'Embedding request aborted.');
  if (provider === 'google' && process.env.GOOGLE_AI_KEY) {
    const vec = await getGeminiEmbedding(text, options);
    if (vec) {
      return {
        vector: vec,
        provider: 'google',
        model: GOOGLE_MODEL,
        dimensions: vec.length,
      };
    }
  }
  const vec = await getOpenAIEmbedding(text, options);
  if (!vec) return null;
  return {
    vector: vec,
    provider: 'openai',
    model: OPENAI_MODEL,
    dimensions: vec.length,
  };
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
  getEmbeddingWithMetadata,
  cosineSimilarity,
  serializeEmbedding,
  deserializeEmbedding,
  keywordSimilarity,
  EMBED_DIM,
  EMBED_DIM_GOOGLE,
  GOOGLE_MODEL,
  OPENAI_MODEL,
};
