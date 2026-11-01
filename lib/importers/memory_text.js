'use strict';

// Turns another agent's Markdown memory into NeoAgent-sized memories.

// NeoAgent keeps memories short; longer entries are split into pieces.
const MAX_FACT_CHARS = 150;

// Markdown memory → entries: Hermes separates entries with a line holding
// only "§"; OpenClaw writes bullets and paragraphs under headings. Each entry
// keeps the heading it sat under, so it can be categorised.
function splitMemoryEntries(text) {
  const source = String(text || '');
  if (/\n§\n/.test(`\n${source}\n`)) {
    return source.split(/\n?^§$\n?/m)
      .map((entry) => entry.trim())
      .filter(Boolean)
      .map((entry) => ({ text: collapse(entry), heading: '' }));
  }

  const entries = [];
  let heading = '';
  let paragraph = [];
  const flush = () => {
    const joined = collapse(paragraph.join(' '));
    if (joined) entries.push({ text: joined, heading });
    paragraph = [];
  };
  for (const rawLine of source.split('\n')) {
    const line = rawLine.trim();
    const headingMatch = line.match(/^#{1,6}\s+(.*)$/);
    if (headingMatch) {
      flush();
      heading = headingMatch[1].trim();
      continue;
    }
    if (!line || /^(-{3,}|\*{3,})$/.test(line)) {
      flush();
      continue;
    }
    const bullet = line.match(/^(?:[-*+]|\d+[.)])\s+(.*)$/);
    if (bullet) {
      flush();
      paragraph.push(bullet[1]);
      flush();
      continue;
    }
    paragraph.push(line);
  }
  flush();
  return entries.filter((entry) => !isPlaceholder(entry.text));
}

function collapse(text) {
  return String(text || '').replace(/\*\*(.+?)\*\*/g, '$1').replace(/\s+/g, ' ').trim();
}

// Template lines left untouched: "- **Name:**" with nothing after it, or
// "(optional)" hints from the agent's starter files.
function isPlaceholder(text) {
  const value = text.replace(/[*_`]/g, '').trim();
  if (!value) return true;
  if (/^[^:]{1,40}:\s*$/.test(value)) return true;
  if (/^\(.*\)$/.test(value) || /^_?\(.*\)_?$/.test(value)) return true;
  return false;
}

const HEADING_CATEGORIES = [
  [/\b(people|family|friends?|contacts?|relationships?)\b/i, 'contacts'],
  [/\b(prefers?|preferences?|likes?|tastes?|style|habits?)\b/i, 'preferences'],
  [/\b(projects?|work|job|career|goals?)\b/i, 'projects'],
  [/\b(events?|dates?|birthdays?|appointments?|schedule)\b/i, 'events'],
  [/\b(tasks?|todos?|to-dos?)\b/i, 'tasks'],
  [/\b(how to|procedures?|workflows?|process|lessons?|steps)\b/i, 'procedural'],
  [/\b(about|identity|profile|bio)\b/i, 'identity'],
];

function categoryFor(heading, fallback) {
  const match = HEADING_CATEGORIES.find(([pattern]) => pattern.test(heading || ''));
  return match ? match[1] : fallback;
}

// One entry → memories that fit MAX_FACT_CHARS. Sentences are packed
// together; a short lead like "Home automation:" is repeated on each piece so
// every memory still says what it is about.
function toShortFacts(text) {
  const value = collapse(text);
  if (value.length <= MAX_FACT_CHARS) return value ? [value] : [];

  const leadMatch = value.match(/^([^:.!?]{2,32}):\s+/);
  const lead = leadMatch ? `${leadMatch[1]}: ` : '';
  const body = lead ? value.slice(leadMatch[0].length) : value;
  const room = MAX_FACT_CHARS - lead.length;
  const pieces = [];
  let current = '';
  for (const sentence of body.match(/[^.!?;]+[.!?;]*\s*/g) || [body]) {
    for (const part of wrapWords(sentence.trim(), room)) {
      const candidate = current ? `${current} ${part}` : part;
      if (candidate.length <= room) {
        current = candidate;
      } else {
        if (current) pieces.push(current);
        current = part;
      }
    }
  }
  if (current) pieces.push(current);
  return pieces.map((piece) => `${lead}${piece}`);
}

function wrapWords(text, max) {
  if (text.length <= max) return [text];
  const parts = [];
  let current = '';
  for (const word of text.split(/\s+/)) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length <= max) {
      current = candidate;
    } else {
      if (current) parts.push(current);
      current = word.slice(0, max);
    }
  }
  if (current) parts.push(current);
  return parts;
}

module.exports = {
  MAX_FACT_CHARS,
  categoryFor,
  collapse,
  splitMemoryEntries,
  toShortFacts,
};
