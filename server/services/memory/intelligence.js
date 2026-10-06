'use strict';

const crypto = require('crypto');

const ENTITY_KIND_PATTERNS = [
  ['email', /^[^\s@]+@[^\s@]+\.[^\s@]+$/],
  ['url', /^https?:\/\//i],
  ['version', /^v?\d+(?:\.\d+){1,3}$/i],
  ['file', /\.(js|ts|dart|py|json|md|yaml|yml|sql|rs|go|java|kt|swift|css|html)$/i],
  ['domain', /^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}$/i],
  ['identifier', /^(?=.*[\d_])[a-z0-9][a-z0-9_-]{2,}$/i],
  ['acronym', /^[A-Z][A-Z0-9_-]{2,}$/],
];

const CAPITALIZED_WORD = String.raw`[A-Z](?:[\p{L}\p{N}_+/-]|\.(?=[\p{L}\p{N}]))*`;
const CAPITALIZED_PHRASE = new RegExp(
  String.raw`\b${CAPITALIZED_WORD}(?:[ \t]+${CAPITALIZED_WORD}){0,4}`,
  'gu',
);
// A match starts a sentence (or a list item / header value) when only quotes,
// brackets or bullets separate it from the text start or a terminator.
const SENTENCE_START = /(?:^|[.!?:;\n])[\s"'“„‘(\[*•>#-]*$/u;
const AFTER_CLOCK_TIME = /\d{1,2}:\d{2}(?::\d{2})?\s*\(?$/;

let calendarWords = null;

// Month, weekday and timezone names in every UI language, generated from Intl
// so they track the shipped languages instead of a hand-maintained list.
function getCalendarWords() {
  if (calendarWords) return calendarWords;
  const { UI_LANGUAGE_CODES } = require('../../config/ui_languages');
  const words = new Set();
  const add = (value) => {
    const word = String(value || '').replace(/\.$/, '').toLowerCase();
    if (/^\p{L}{2,}$/u.test(word)) words.add(word);
  };
  const seasons = [new Date(Date.UTC(2024, 0, 15)), new Date(Date.UTC(2024, 6, 15))];
  const timeZones = ['UTC', ...Intl.supportedValuesOf('timeZone')];
  for (const locale of UI_LANGUAGE_CODES) {
    for (let month = 0; month < 12; month += 1) {
      const date = new Date(Date.UTC(2024, month, 1));
      for (const style of ['long', 'short']) {
        add(new Intl.DateTimeFormat(locale, { month: style, timeZone: 'UTC' }).format(date));
      }
    }
    for (let day = 1; day <= 7; day += 1) {
      const date = new Date(Date.UTC(2024, 0, day));
      for (const style of ['long', 'short']) {
        add(new Intl.DateTimeFormat(locale, { weekday: style, timeZone: 'UTC' }).format(date));
      }
    }
    for (const timeZone of timeZones) {
      for (const date of seasons) {
        const part = new Intl.DateTimeFormat(locale, { timeZone, timeZoneName: 'short' })
          .formatToParts(date)
          .find((item) => item.type === 'timeZoneName');
        add(part?.value);
      }
    }
  }
  calendarWords = words;
  return words;
}

function isCalendarWord(word) {
  const value = String(word || '').replace(/[^\p{L}\p{N}]+$/u, '');
  return /^\d+$/.test(value) || getCalendarWords().has(value.toLowerCase());
}

// '' for names made only of date parts ("Fri", "12 Aug"). Mixed names stay
// whole: "Jan Müller" or "Karl May" are people, not dates.
function trimCalendarWords(name) {
  const words = String(name || '').trim().split(/\s+/).filter(Boolean);
  return words.every(isCalendarWord) ? '' : words.join(' ');
}

// Structural noise left by older extraction: header labels ("Date: Fri"),
// bracketed mail addresses, and names made only of date parts.
function isNoiseEntityName(name) {
  const value = String(name || '').trim();
  return /^[<>(\["']/.test(value)
    || /^\p{L}+:\s/u.test(value)
    || trimCalendarWords(value) !== value
    || value.replace(/[^\p{L}\p{N}]/gu, '').length < 2;
}

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
  return 'concept';
}

function capitalizedCandidates(raw) {
  const candidates = [];
  for (const match of raw.matchAll(CAPITALIZED_PHRASE)) {
    const before = raw.slice(0, match.index);
    const after = raw.slice(match.index + match[0].length);
    if (after.startsWith(':') && /(?:^|\n)[ \t]*$/.test(before)) continue; // header label
    if (/^[A-Z]{2,5}$/.test(match[0]) && AFTER_CLOCK_TIME.test(before)) continue; // timezone
    const name = trimCalendarWords(match[0]);
    if (name.length < 3) continue;
    if (!SENTENCE_START.test(before)) {
      candidates.push({ name, inSentence: true });
      continue;
    }
    // Capitalization at a sentence start says nothing about the first word, so
    // keep the phrase and its tail, both unconfirmed; another memory has to
    // mention them mid-sentence before they count as entities.
    candidates.push({ name, inSentence: false });
    const tail = name.split(' ').slice(1).join(' ');
    if (tail.length >= 3) candidates.push({ name: tail, inSentence: false });
  }
  return candidates;
}

// Returns entities with `inSentence` set when at least one occurrence was
// capitalized mid-sentence (or is structurally an entity: email, URL, file).
function extractEntities(text, { maxEntities = 16 } = {}) {
  const raw = String(text || '');
  const candidates = [];

  for (const match of raw.matchAll(/[^\s@<>()"',;]+@[^\s@<>()"',;]+\.[^\s@<>()"',;]+/g)) {
    candidates.push({ name: match[0].replace(/[.]+$/g, ''), inSentence: true });
  }
  for (const match of raw.matchAll(/https?:\/\/[^\s)]+/gi)) {
    candidates.push({ name: match[0].replace(/[.,;]+$/g, ''), inSentence: true });
  }
  candidates.push(...capitalizedCandidates(raw));
  for (const match of raw.matchAll(/\b[\p{L}\p{N}_./-]+\.(?:js|ts|dart|py|json|md|yaml|yml|sql|rs|go|java|kt|swift|css|html)\b/giu)) {
    candidates.push({ name: match[0], inSentence: true });
  }

  const byKey = new Map();
  for (const candidate of candidates) {
    const name = candidate.name.trim().replace(/\s+/g, ' ').slice(0, 160);
    const key = canonicalEntityKey(name);
    if (!key || key.length < 2 || isNoiseEntityName(name)) continue;
    const existing = byKey.get(key);
    if (existing) {
      existing.inSentence = existing.inSentence || candidate.inSentence;
      continue;
    }
    byKey.set(key, { key, name, kind: classifyEntity(name), inSentence: candidate.inSentence });
  }
  return [...byKey.values()].slice(0, maxEntities);
}

// Words the texts use in lowercase form. A capitalized word whose lowercase form
// is in here is an ordinary word that happened to start a sentence.
function collectLowercaseWords(texts, words = new Set()) {
  for (const text of texts) {
    for (const match of String(text || '').matchAll(/(?<![\p{L}\p{N}])\p{Ll}\p{L}*/gu)) {
      words.add(match[0]);
    }
  }
  return words;
}

// An entity counts when some mention capitalized it mid-sentence, or when its
// first word is never written in lowercase (so it is not a common word).
function isConfirmedEntity({ name, hasInSentenceMention }, lowercaseWords) {
  if (hasInSentenceMention) return true;
  const firstWord = String(name || '').trim().split(/\s+/)[0] || '';
  return !lowercaseWords.has(firstWord.toLowerCase());
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

// Local fallback used when the LLM consolidation pass did not supply structured
// facts (manual saves, imports). It emits one memory-level fact anchored on the
// leading entity. Per-entity sentence copies only duplicated the memory text in
// the fact index without adding anything recall could use.
function buildFacts({ content, category, sourceRef, metadata } = {}) {
  const text = String(content || '').trim();
  if (!text) return [];

  const sentences = splitSentences(text);
  const entities = extractEntities(text);
  const keywords = extractKeywords(text, { maxKeywords: 10 });
  const sourceType = sourceRef?.sourceType || metadata?.sourceType || null;
  const predicate = String(category || 'episodic').replace(/_/g, ' ');
  const confidence = sourceType === 'llm_import' ? 0.74 : 0.68;
  const factMetadata = {
    keywords,
    sourceType,
    extractedBy: 'local_memory_intelligence',
  };

  return [{
    subject: String(entities[0]?.name || predicate).slice(0, 180),
    predicate,
    object: (sentences[0] || text).slice(0, 900),
    category,
    confidence,
    metadata: factMetadata,
  }];
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
  confidence = 0.7,
  accessCount = 0,
  freshness = 1,
} = {}) {
  const fused = (
    rankFuse(semanticRank, 1.0) +
    rankFuse(lexicalRank, 0.85) +
    rankFuse(entityRank, 0.95)
  ) * 20;
  const quality = 0.15 + clamp(importance, 1, 10, 5) / 22;
  const confidenceMultiplier = 0.65 + clamp(confidence, 0, 1, 0.7) * 0.35;
  const usage = Math.min(0.08, Math.log1p(Math.max(0, Number(accessCount) || 0)) / 50);
  return Math.max(baseScore, fused + quality + usage) * freshness * confidenceMultiplier;
}

module.exports = {
  buildFacts,
  canonicalEntityKey,
  classifyEntity,
  collectLowercaseWords,
  extractEntities,
  extractKeywords,
  isConfirmedEntity,
  isNoiseEntityName,
  scoreMemoryCandidate,
  stableHash,
  summarizeForPrompt,
};
