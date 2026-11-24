'use strict';

const { createHash } = require('crypto');
const fs = require('fs');
const path = require('path');
const { DATA_DIR } = require('../../../runtime/paths');
const { getEmbeddingWithMetadata } = require('../memory/embeddings');
const { resolveToolMeta } = require('./tools/metadata');
const { searchTools } = require('./toolSelector');

// Finds tools by what a request means, in whatever language it is in. Words alone do
// not work: the tools are described in English and the owner may not be speaking it.
// It uses the memory system's embedding provider, not another model turn. Without
// one, or when it is slow or failing, matching words is what is left. A request too
// short to name a capability does not pay for any of this.
const QUERY_BUDGET_MS = 800;
const RANKED_TOOLS = 12;
const MAX_DOCUMENT_CHARS = 2000;
const WARM_CONCURRENCY = 3;
const WARM_RETRY_MS = 10 * 60 * 1000;
const MIN_EMBEDDED_SHARE = 0.8;
const VECTOR_FILE = path.join(DATA_DIR, 'tool_vectors.json');

const warming = new Set();
const warmFailedAt = new Map();
let vectors = null;
// One embedding space, as its provider declares it: "provider:model:dimensions:digest".
const VECTOR_KEY = /^[^:]+:[^:]+:\d+:[0-9a-f]{64}$/;

// Tool descriptions change rarely and cost a call each, so they outlive a restart.
function loadVectors() {
  if (vectors) return vectors;
  vectors = new Map();
  try {
    for (const [key, encoded] of Object.entries(JSON.parse(fs.readFileSync(VECTOR_FILE, 'utf8')))) {
      // Older files keyed vectors without their size, and by the host that served them.
      if (!VECTOR_KEY.test(key)) continue;
      const bytes = Buffer.from(encoded, 'base64');
      vectors.set(key, new Float32Array(bytes.buffer, bytes.byteOffset, bytes.length / 4));
    }
  } catch {
    // First start, or a damaged file: they are embedded again.
  }
  return vectors;
}

// Written off the event loop: the file holds every tool's vector and is large.
async function saveVectors() {
  const stored = {};
  for (const [key, vector] of vectors) {
    stored[key] = Buffer.from(vector.buffer, vector.byteOffset, vector.byteLength).toString('base64');
  }
  const temporary = `${VECTOR_FILE}.${process.pid}.tmp`;
  try {
    await fs.promises.writeFile(temporary, JSON.stringify(stored));
    await fs.promises.rename(temporary, VECTOR_FILE);
  } catch {
    await fs.promises.rm(temporary, { force: true });
  }
}

function toolDocument(tool) {
  const meta = resolveToolMeta(tool?.name, tool);
  return [
    String(tool?.name || '').replace(/_/g, ' '),
    tool?.description,
    meta.capabilities.join(' '),
    meta.whenToUse.join(' '),
  ].filter(Boolean).join('\n').slice(0, MAX_DOCUMENT_CHARS);
}

function vectorKey(embedding, document) {
  const digest = createHash('sha256').update(document).digest('hex');
  const dimensions = embedding.dimensions || embedding.vector?.length || 0;
  return `${embedding.provider}:${embedding.model}:${dimensions}:${digest}`;
}

function cosine(left, right) {
  let dot = 0;
  let leftNorm = 0;
  let rightNorm = 0;
  for (let index = 0; index < left.length; index += 1) {
    dot += left[index] * right[index];
    leftNorm += left[index] * left[index];
    rightNorm += right[index] * right[index];
  }
  return leftNorm && rightNorm ? dot / Math.sqrt(leftNorm * rightNorm) : 0;
}

// Embedded in the background, a run never waits for it, and the next one has them.
// A provider that is failing is left alone for a while instead of asked again.
function warmToolVectors(allTools, provider, embedding, context = {}) {
  const known = loadVectors();
  const pending = allTools
    .map(toolDocument)
    .filter((document) => document && !known.has(vectorKey(embedding, document)));
  const warmKey = `${embedding.provider}:${embedding.model}`;
  if (!pending.length || warming.has(warmKey)) return Promise.resolve();
  if (Date.now() - (warmFailedAt.get(warmKey) || 0) < WARM_RETRY_MS) return Promise.resolve();
  warming.add(warmKey);
  let failed = 0;
  const worker = async () => {
    while (pending.length) {
      const document = pending.shift();
      const result = await getEmbeddingWithMetadata(document, provider, { ...context, inputType: 'document' })
        .catch(() => null);
      if (result?.vector) known.set(vectorKey(result, document), result.vector);
      else failed += 1;
    }
  };
  return Promise.all(Array.from({ length: WARM_CONCURRENCY }, worker))
    .then(() => {
      if (failed) warmFailedAt.set(warmKey, Date.now());
      else warmFailedAt.delete(warmKey);
      return saveVectors();
    })
    .finally(() => warming.delete(warmKey));
}

async function embedQuery(request, provider, context, signal) {
  const budget = new AbortController();
  const timer = setTimeout(() => budget.abort(), QUERY_BUDGET_MS);
  timer.unref?.();
  const abort = () => budget.abort();
  signal?.addEventListener('abort', abort, { once: true });
  try {
    return await getEmbeddingWithMetadata(request, provider, {
      ...context,
      inputType: 'query',
      signal: budget.signal,
    });
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener('abort', abort);
  }
}

/**
 * The tools closest to this request, best first, with how close they are. Which
 * of them get activated is the selector's call.
 */
async function retrieveTools(allTools, request, { provider = null, userId = null, agentId = null, signal = null } = {}) {
  const text = String(request || '').trim();
  if (!text) return [];
  const context = { userId, agentId };
  const query = await embedQuery(text, provider, context, signal);
  if (query?.vector) {
    void warmToolVectors(allTools, provider, query, context);
    const known = loadVectors();
    const ranked = allTools
      .map((tool) => {
        const vector = known.get(vectorKey(query, toolDocument(tool)));
        return vector && vector.length === query.vector.length
          ? { name: tool.name, similarity: Number(cosine(query.vector, vector).toFixed(3)) }
          : null;
      })
      .filter(Boolean)
      .sort((left, right) => right.similarity - left.similarity);
    // Part of the list is no ranking at all: a tool not embedded yet could not win.
    if (ranked.length >= allTools.length * MIN_EMBEDDED_SHARE) return ranked.slice(0, RANKED_TOOLS);
  }
  // Sharing a common word with a description says nothing: it takes a word of the tool's own name.

  return searchTools(allTools, text, { limit: RANKED_TOOLS, minScore: 7 }).map((tool) => ({ name: tool.name, similarity: null }));
}

module.exports = {
  retrieveTools,
  warmToolVectors,
};
