'use strict';

const crypto = require('crypto');

const ENTITY_KIND_PATTERNS = [
  ['email', /^[^\s@]+@[^\s@]+\.[^\s@]+$/],
  ['url', /^https?:\/\//i],
  ['version', /^v?\d+(?:\.\d+){1,3}$/i],
  ['identifier', /^[a-z0-9][a-z0-9_-]{2,}$/i],
];

function clamp(value, min, max, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : fallback;
}

function stableHash(value) {
  return crypto
    .createHash('sha256')
    .update(String(value || '').trim().toLowerCase())
    .digest('hex');
}

function canonicalEntityKey(name) {
  return String(name || '')
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}._@:/+-]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .slice(0, 160);
}

function classifyEntity(name) {
  const value = String(name || '').trim();
  for (const [kind, pattern] of ENTITY_KIND_PATTERNS) {
    if (pattern.test(value)) return kind;
  }
  if (/^[A-Z][A-Z0-9_-]{2,}$/.test(value)) return 'acronym';
  if (/\.(js|ts|dart|py|json|md|yaml|yml|sql|rs|go|java|kt|swift|css|html)$/i.test(value)) {
    return 'file';
  }
  return 'concept';
}

function uniqueByKey(items, getKey) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const key = getKey(item);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push(item);
  }
  return result;
}

function extractEntities(text, { maxEntities = 16 } = {}) {
  const raw = String(text || '');
  const candidates = [];

  for (const match of raw.matchAll(/[^\s@]+@[^\s@]+\.[^\s@]+/g)) {
    candidates.push(match[0]);
  }
  for (const match of raw.matchAll(/https?:\/\/[^\s)]+/gi)) {
    candidates.push(match[0].replace(/[.,;]+$/g, ''));
  }
  for (const match of raw.matchAll(/\b[A-Z][\p{L}\p{N}_+./:-]*(?:\s+[A-Z][\p{L}\p{N}_+./:-]*){0,4}\b/gu)) {
    const value = match[0].trim();
    if (value.length > 2) candidates.push(value);
  }
  for (const match of raw.matchAll(/\b[\p{L}\p{N}_./-]+\.(?:js|ts|dart|py|json|md|yaml|yml|sql|rs|go|java|kt|swift|css|html)\b/giu)) {
    candidates.push(match[0]);
  }

  return uniqueByKey(
    candidates
      .map((name) => {
        const normalized = String(name || '').trim().replace(/\s+/g, ' ');
        const key = canonicalEntityKey(normalized);
        if (!key || key.length < 2) return null;
        return {
          key,
          name: normalized.slice(0, 160),
          kind: classifyEntity(normalized),
        };
      })
      .filter(Boolean),
    (entity) => entity.key,
  ).slice(0, maxEntities);
}

function extractKeywords(text, { maxKeywords = 24 } = {}) {
  const counts = new Map();
  const tokens = String(text || '')
    .toLowerCase()
    .match(/[\p{L}\p{N}_-]{5,}/gu) || [];
  for (const token of tokens) {
    if (/^\d+$/.test(token)) continue;
    counts.set(token, (counts.get(token) || 0) + 1);
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, maxKeywords)
    .map(([keyword]) => keyword);
}

function splitSentences(text) {
  return String(text || '')
    .split(/(?<=[.!?])\s+|\n+/u)
    .map((part) => part.trim())
    .filter(Boolean);
}

function buildFacts({ content, category, sourceRef, metadata } = {}) {
  const sentences = splitSentences(content);
  const entities = extractEntities(content);
  const keywords = extractKeywords(content, { maxKeywords: 10 });
  const subject = entities[0]?.name || String(category || 'memory').replace(/_/g, ' ');
  const predicate = String(category || 'episodic').replace(/_/g, ' ');
  const sourceType = sourceRef?.sourceType || metadata?.sourceType || null;

  const factTexts = sentences.length
    ? sentences.slice(0, 6)
    : [String(content || '').trim()].filter(Boolean);

  return factTexts.map((text, index) => ({
    subject: String(subject || 'memory').slice(0, 180),
    predicate: index === 0 ? predicate : 'detail',
    object: text.slice(0, 900),
    category,
    confidence: sourceType === 'llm_import' ? 0.74 : 0.68,
    metadata: {
      keywords,
      sourceType,
      extractedBy: 'local_memory_intelligence',
    },
  }));
}

function summarizeForPrompt(memory) {
  const entities = Array.isArray(memory.entities) ? memory.entities : [];
  const content = String(memory.content || '').replace(/\s+/g, ' ').trim();
  const entitySuffix = entities.length
    ? ` (${entities.slice(0, 4).map((entity) => entity.name || entity).join(', ')})`
    : '';
  return `${content}${entitySuffix}`.slice(0, 900);
}

function rankFuse(rank, weight = 1) {
  if (!Number.isFinite(rank) || rank < 0) return 0;
  return weight / (60 + rank + 1);
}

function scoreMemoryCandidate({
  semanticRank = -1,
  lexicalRank = -1,
  entityRank = -1,
  baseScore = 0,
  importance = 5,
  accessCount = 0,
  freshness = 1,
} = {}) {
  const fused = (
    rankFuse(semanticRank, 1.0) +
    rankFuse(lexicalRank, 0.85) +
    rankFuse(entityRank, 0.95)
  ) * 20;
  const quality = 0.15 + clamp(importance, 1, 10, 5) / 22;
  const usage = Math.min(0.08, Math.log1p(Math.max(0, Number(accessCount) || 0)) / 50);
  return Math.max(baseScore, fused + quality + usage) * freshness;
}

module.exports = {
  buildFacts,
  canonicalEntityKey,
  extractEntities,
  extractKeywords,
  scoreMemoryCandidate,
  stableHash,
  summarizeForPrompt,
};
