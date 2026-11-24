'use strict';

const { fetchResponseText } = require('../../network/http');

// Calls to a NeoRouter's OpenAI-style API with a connection from
// connection.js. NeoRouter picks the model ("auto") and falls back across its
// providers, so these stay small.
async function call(connection, path, { method = 'GET', body, signal, timeoutMs = 30000, maxResponseBytes = 4 * 1024 * 1024, withHeaders = false } = {}) {
  const { response, text } = await fetchResponseText(`${connection.apiBase}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${connection.apiKey}`,
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
    maxResponseBytes,
    serviceName: 'NeoRouter',
    signal,
    timeoutMs,
  });
  let data = null;
  try {
    data = JSON.parse(text || 'null');
  } catch {
    data = null;
  }
  if (!response.ok) {
    const error = new Error(`NeoRouter: ${data?.error?.message || `HTTP ${response.status}`}`);
    error.status = response.status;
    throw error;
  }
  return withHeaders ? { data, headers: response.headers } : data;
}

// The models of a kind the key may use, and how many more the router has
// that the key's free/plan/paid choice leaves out.
async function modelList(connection, type = 'chat', { signal } = {}) {
  const data = await call(connection, `/models?type=${encodeURIComponent(type)}`, { signal });
  return { models: Array.isArray(data?.data) ? data.data : [], notAllowed: data?.neorouter?.not_allowed_for_key || {} };
}

async function listModels(connection, type = 'chat', options = {}) {
  return (await modelList(connection, type, options)).models;
}

// System One decision models, as opposed to NeoRouter's safety classifiers.
// Auto models carry the flag when they can answer decisions.
const isDecisionModel = (model) => model?.neorouter?.decision === true;

// The body names the host that served the request ("google-2/gemini-embedding-001");
// the pin header names the model and size every host for this key serves, which is
// what makes two vectors comparable. Without the header the host is all there is.
async function embed(connection, text, { inputType, signal } = {}) {
  const { data, headers } = await call(connection, '/embeddings', {
    method: 'POST',
    body: { model: 'auto', input: text, input_type: inputType === 'document' ? 'document' : 'query' },
    signal,
    timeoutMs: 15000,
    withHeaders: true,
  });
  const vector = data?.data?.[0]?.embedding;
  if (!Array.isArray(vector) || !vector.length) return null;
  const space = String(headers?.get?.('x-neorouter-embedding-pin') || '').trim();
  return { vector, model: space || String(data.model || 'auto'), servedBy: String(data.model || '') };
}

async function generateImages(connection, { prompt, n = 1, signal }) {
  const data = await call(connection, '/images/generations', {
    method: 'POST',
    body: { model: 'auto', prompt, n, response_format: 'b64_json' },
    signal,
    timeoutMs: 180000,
    maxResponseBytes: 64 * 1024 * 1024,
  });
  return (data?.data || []).map((image) => image.b64_json).filter(Boolean);
}

async function searchWeb(connection, { query, count = 5, freshness, signal }) {
  const recency = { pd: 'day', pw: 'week', pm: 'month', py: 'year' }[freshness];
  const data = await call(connection, '/search', {
    method: 'POST',
    body: { query, max_results: count, ...(recency ? { recency } : {}) },
    signal,
    timeoutMs: 20000,
  });
  return (data?.results || []).map((item, index) => ({
    rank: index + 1,
    title: item.title || '',
    url: item.url || '',
    description: item.content || item.snippet || item.description || '',
  }));
}

module.exports = { call, embed, generateImages, isDecisionModel, listModels, modelList, searchWeb };
