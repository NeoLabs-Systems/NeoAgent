'use strict';

const crypto = require('crypto');
const { listModels } = require('./client');

// What a NeoRouter can do for each role, from its model lists: how many
// models it has, and for live voice which protocols reach them. Shown next to
// the role switches, and used to set up live voice after connecting.
const ROLE_TYPES = Object.freeze({
  chat: 'chat',
  system_one: 'moderation',
  transcription: 'transcription',
  live: 'live',
  embeddings: 'embedding',
  images: 'image',
  search: 'search',
});
// NeoAgent's System One asks decision models (Jev), not classifiers.
const DECISION_MODEL = /(^|\/)jev|decide/i;
const CACHE_MS = 5 * 60 * 1000;
const cache = new Map();

function cacheKey(connection) {
  return crypto.createHash('sha256').update(`${connection.apiBase}\n${connection.apiKey}`).digest('hex');
}

async function load(connection, signal) {
  const roles = {};
  const liveProtocols = new Set();
  const results = await Promise.allSettled(Object.entries(ROLE_TYPES).map(async ([role, type]) => {
    let models = (await listModels(connection, type, { signal })).filter((model) => !String(model.id).startsWith('auto'));
    if (role === 'system_one') models = models.filter((model) => DECISION_MODEL.test(model.id));
    if (role === 'live') for (const model of models) for (const protocol of model.neorouter?.protocols || []) liveProtocols.add(protocol);
    roles[role] = models.length;
  }));
  const failure = results.find((result) => result.status === 'rejected');
  if (failure && Object.keys(roles).length === 0) throw failure.reason;
  return { roles, liveProtocols: [...liveProtocols] };
}

/** { roles: { chat: 12, live: 0, … }, liveProtocols: ['gemini_live'] } */
async function describeOffer(connection, { signal, fresh = false } = {}) {
  const key = cacheKey(connection);
  const cached = cache.get(key);
  if (!fresh && cached && cached.expiresAt > Date.now()) return cached.offer;
  const offer = await load(connection, signal);
  cache.set(key, { offer, expiresAt: Date.now() + CACHE_MS });
  return offer;
}

module.exports = { DECISION_MODEL, describeOffer };
