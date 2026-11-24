'use strict';

// Two statements with one value swapped read almost the same to an embedding and
// to a keyword match, yet the newer one replaces the older one. These checks look
// only at the shape of the text, so they work the same in every language.

const VALUE = /^(?:v?\d[\d.,:/-]*[\p{L}%]{0,3}|[^\s@]+@[^\s@]+\.[^\s@]+|https?:\/\/\S+)$/iu;
// "in Rome in 2019" and "in Rome in 2021" are usually both true.
const YEAR = /^(?:19|20)\d{2}$/;
const MIN_SHARED_CONTEXT = 0.6;

function tokensOf(text) {
  return String(text || '')
    .split(/\s+/)
    .map((token) => token.replace(/^[\s"'„“”‘’(\[]+|[\s"'“”‘’)\],.;:!?]+$/gu, ''))
    .filter(Boolean);
}

function isValueToken(token) {
  return VALUE.test(token);
}

// Capitalized words after the first name what a statement is about. If they
// differ, the statements are about different things: Anna's appointment is not
// replaced by Bob's.
function namesOf(tokens) {
  return tokens
    .slice(1)
    .filter((token) => !isValueToken(token) && /^\p{Lu}/u.test(token))
    .map((token) => token.toLowerCase())
    .sort()
    .join('\u0000');
}

function contextOverlap(left, right) {
  const words = (tokens) => new Set(
    tokens.filter((token) => !isValueToken(token) && token.length >= 3).map((token) => token.toLowerCase()),
  );
  const a = words(left);
  const b = words(right);
  if (!a.size || !b.size) return 0;
  let shared = 0;
  for (const word of a) if (b.has(word)) shared += 1;
  return shared / Math.min(a.size, b.size);
}

function followingWord(tokens, value) {
  const index = tokens.findIndex((token) => token.toLowerCase() === value);
  return tokens[index + 1]?.toLowerCase() || null;
}

// True when both statements say the same thing except for one number, address
// or similar value: "port 5544" and "port 5600". Names are left out on purpose,
// because "Neo's sister is Anna" and "Neo's sister is Maria" can both be true.
// Those replacements need a model or a person to say so (relation "updates",
// memory_save `replaces`).
function isValueChange(nextText, previousText) {
  const next = tokensOf(nextText);
  const previous = tokensOf(previousText);
  const values = (tokens) => new Set(tokens.filter(isValueToken).map((token) => token.toLowerCase()));
  const nextValues = values(next);
  const previousValues = values(previous);
  const added = [...nextValues].filter((value) => !previousValues.has(value));
  const removed = [...previousValues].filter((value) => !nextValues.has(value));
  if (added.length !== 1 || removed.length !== 1) return false;
  if (YEAR.test(added[0]) || YEAR.test(removed[0])) return false;
  if (namesOf(next) !== namesOf(previous)) return false;
  if (contextOverlap(next, previous) < MIN_SHARED_CONTEXT) return false;
  // "has 2 cats" and "has 3 dogs" count different things.
  const nextFollowing = followingWord(next, added[0]);
  const previousFollowing = followingWord(previous, removed[0]);
  return !nextFollowing || !previousFollowing || nextFollowing === previousFollowing;
}

// A reworded copy keeps its numbers. Statements that disagree on a value are not
// copies however close they read, even when they are about different things.
function valuesDiffer(left, right) {
  const values = (text) => new Set(tokensOf(text).filter(isValueToken).map((token) => token.toLowerCase()));
  const a = values(left);
  const b = values(right);
  if (!a.size || !b.size) return false;
  return [...a].some((value) => !b.has(value)) && [...b].some((value) => !a.has(value));
}

// Embedding models differ on how close "close" is, and merging two facts destroys
// one of them. A reworded copy still shares a real word with the original.
function sharesContentWord(left, right) {
  const words = (text) => new Set(
    tokensOf(text).filter((token) => token.length >= 4 && !isValueToken(token)).map((token) => token.toLowerCase()),
  );
  const a = words(left);
  return [...words(right)].some((word) => a.has(word));
}

// "prefers dark mode" and "prefers light mode" embed as near duplicates. A single
// swapped word cannot prove a replacement, but it does prove they are not the same
// statement, so neither may be dropped as a copy of the other.
function isOneWordSwap(left, right) {
  const words = (text) => tokensOf(text).map((token) => token.toLowerCase());
  const a = words(left);
  const b = words(right);
  if (a.length !== b.length || a.length < 3) return false;
  const remaining = [...b];
  let unmatched = 0;
  for (const word of a) {
    const index = remaining.indexOf(word);
    if (index >= 0) remaining.splice(index, 1);
    else unmatched += 1;
  }
  return unmatched === 1;
}

module.exports = {
  isOneWordSwap,
  isValueChange,
  sharesContentWord,
  valuesDiffer,
};
