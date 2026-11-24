'use strict';

// Graded evidence that a memory matches a query, local and language independent.
// Word weights come from the user's own memories: a word in half of them says
// little, whatever language it is in.

const TERM = /[\p{L}\p{N}_]{2,}/gu;
const MAX_QUERY_TERMS = 32;
const MIN_PREFIX = 4;
// A word that common in the corpus cannot be the only thing two texts share.
const COMMON_SHARE = 0.15;
// Three letters can be "dog" or "the". Only a word the user's memories almost
// never use can be trusted to be the former.
const SHORT_WORD_SHARE = 0.03;
// A long message mentions more than any one memory can cover.
const LONG_QUERY_TERMS = 12;
const MEMORY_SIDE_WEIGHT = 0.8;
const MIN_NOISE_SAMPLE = 8;
const SMALL_SAMPLE_NOISE = 0.25;
const RUN_MATCH_COVERAGE = 0.6;

function wordsOf(text) {
  return String(text || '').toLowerCase().match(TERM) || [];
}

function isStrongWord(word) {
  return word.length >= MIN_PREFIX || /\d/.test(word);
}

function wordMatches(term, words, minPrefix = MIN_PREFIX) {
  if (words.has(term)) return true;
  if (term.length < minPrefix) return false;
  for (const word of words) {
    if (word.length >= minPrefix && (word.startsWith(term) || term.startsWith(word))) return true;
  }
  return false;
}

// Short words a memory never used carry no weight: they are almost always
// function words ("how", "wie"). Longer unseen words count against coverage, since
// "my dentist's phone" is not answered by a memory about "my phone".
function weighQueryTerms(query, { documentFrequency, totalDocuments }) {
  const total = Math.max(1, Number(totalDocuments) || 0);
  const seen = new Map();
  for (const raw of String(query || '').match(TERM) || []) {
    const term = raw.toLowerCase();
    if (seen.has(term) || seen.size >= MAX_QUERY_TERMS) continue;
    const acronym = raw.length >= 2 && raw === raw.toUpperCase() && /\p{L}/u.test(raw);
    const strong = isStrongWord(term) || acronym;
    const frequency = documentFrequency(term);
    const unseenWeight = strong ? Math.log(total + 1) / 2 : 0;
    const rareEnough = strong
      ? frequency <= Math.max(2, total * COMMON_SHARE)
      : term.length >= 3 && frequency <= Math.max(1, total * SHORT_WORD_SHARE);
    const distinctive = frequency > 0 && rareEnough;
    let weight = unseenWeight;
    if (frequency > 0) {
      weight = Math.max(0.05, Math.log((total + 1) / (frequency + 0.5)));
      // In a handful of memories every word looks common. A distinctive match must
      // still outweigh a word no memory uses.
      if (distinctive) weight = Math.max(weight, unseenWeight);
    }
    seen.set(term, { term, weight, distinctive });
  }
  return [...seen.values()];
}

function lexicalSignal(terms, text) {
  if (!terms.length) return 0;
  const words = new Set(wordsOf(text));
  let matched = 0;
  let total = 0;
  let distinctive = false;
  for (const term of terms) {
    total += term.weight;
    if (!wordMatches(term.term, words)) continue;
    matched += term.weight;
    distinctive = distinctive || term.distinctive;
  }
  if (!distinctive || total <= 0) return 0;
  const queryCoverage = matched / total;
  if (terms.length <= LONG_QUERY_TERMS) return queryCoverage;
  const queryWords = new Set(terms.map((term) => term.term));
  const strongWords = [...words].filter(isStrongWord);
  const covered = strongWords.filter((word) => wordMatches(word, queryWords)).length;
  return Math.max(queryCoverage, MEMORY_SIDE_WEIGHT * (covered / Math.max(1, strongWords.length)));
}

// How much of a query's long words a text covers, for text outside the memory
// corpus. 0 unless at least two match, or the query has only one.
function textCoverage(query, text) {
  const strong = [...new Set(wordsOf(query))].filter(isStrongWord);
  if (!strong.length) return 0;
  const words = new Set(wordsOf(text));
  const hits = strong.filter((word) => wordMatches(word, words)).length;
  if (hits < Math.min(2, strong.length)) return 0;
  const coverage = hits / strong.length;
  return coverage >= RUN_MATCH_COVERAGE ? coverage : 0;
}

// Cosines sit on a different scale per model: unrelated text can score 0.2 on one
// and 0.6 on another. The middle of this query's candidates is mostly unrelated
// memory, so it shows where noise lies for this model and this query.
function semanticNoiseFloor(cosines) {
  const sorted = cosines.filter((value) => value !== 0).sort((a, b) => a - b);
  if (!sorted.length) return 0;
  const median = sorted[Math.floor(sorted.length / 2)];
  // A handful of memories may all be on topic, so their middle proves nothing.
  return sorted.length >= MIN_NOISE_SAMPLE ? median : Math.min(median, SMALL_SAMPLE_NOISE);
}

function calibrateSemantic(cosine, noiseFloor) {
  if (!(cosine > noiseFloor) || noiseFloor >= 1) return 0;
  return (cosine - noiseFloor) / (1 - noiseFloor);
}

module.exports = {
  calibrateSemantic,
  lexicalSignal,
  semanticNoiseFloor,
  textCoverage,
  weighQueryTerms,
  wordMatches,
  wordsOf,
};
