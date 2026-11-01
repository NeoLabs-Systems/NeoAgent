'use strict';

const { chunkDocument } = require('./ingestion_chunking');
const { normalizeMemoryCandidate } = require('./consolidation');
const { MAX_MEMORY_CHARS } = require('./policy');

// Source text per model call. About eight emails fit, which keeps a whole
// mailbox sweep to a dozen or so calls.
const BATCH_CHAR_BUDGET = 12000;
const MAX_KNOWN_MEMORIES = 40;

// Long documents are read in chunks; a short email stays one unit.
function buildExtractionUnits(documents) {
  const units = [];
  for (const document of documents) {
    for (const chunk of chunkDocument(document)) {
      units.push({ document, content: chunk.content });
    }
  }
  return units;
}

function batchUnits(units, budget = BATCH_CHAR_BUDGET) {
  const batches = [];
  let current = [];
  let size = 0;
  for (const unit of units) {
    if (current.length && size + unit.content.length > budget) {
      batches.push(current);
      current = [];
      size = 0;
    }
    current.push(unit);
    size += unit.content.length;
  }
  if (current.length) batches.push(current);
  return batches;
}

function describeOwner(owner = {}) {
  const parts = [owner.name, owner.email ? `<${owner.email}>` : ''].filter(Boolean);
  return parts.length ? parts.join(' ') : 'the account owner';
}

function formatUnit(unit, index) {
  const { document } = unit;
  return [
    `[${index + 1}] ${document.sourceType}${document.sourceTimestamp ? ` · ${document.sourceTimestamp}` : ''}`,
    unit.content,
  ].join('\n');
}

const FACTS_SCHEMA = JSON.stringify({
  facts: [{
    memory: 'User works at Acme GmbH as a data engineer since March 2026.',
    subject: 'User',
    predicate: 'works at',
    object: 'Acme GmbH',
    relation: 'new | updates | extends',
    category: 'identity | preferences | projects | contacts | events | tasks | episodic',
    importance: 7,
    confidence: 0.9,
    is_static: false,
    valid_from: '2026-03-01',
    valid_to: null,
    source: 1,
  }],
}, null, 2);

function buildDocumentFactsPrompt({ owner, units, knownMemories = [], now = new Date() }) {
  const known = knownMemories.slice(0, MAX_KNOWN_MEMORIES);
  return [
    'Return JSON only.',
    `You keep the long-term memory of a personal assistant for ${describeOwner(owner)}, called "the user" below.`,
    `Today is ${now.toISOString().slice(0, 10)}. Read the numbered sources from the user's accounts and write down only what about the user's life will still matter in months and helps the assistant serve them.`,
    '',
    'Worth remembering, when a source clearly shows it: where the user works or studies and in what role, a job they accepted, started or left, a business they run, where they live or are moving, the people who matter to them and who those people are, major upcoming events and commitments with their dates, long-running projects, contracts and memberships they rely on, and preferences or habits they state. These are examples; judge any other case by the same standard.',
    'Not worth remembering: newsletters, marketing, receipts and shipping notices for everyday purchases, password resets, verification codes, security alerts, social media notifications, automated reports, scheduling back-and-forth, small talk, anything that stops mattering within weeks, and facts about other people that say nothing about the user.',
    'Never store secrets: passwords, codes, card, account or ID numbers, tokens.',
    '',
    'Rules:',
    `- One fact per memory: a complete sentence about the user, at most ${MAX_MEMORY_CHARS} characters, in the third person starting with "User" (e.g. "User accepted a job offer from Acme GmbH (March 2026).").`,
    '- Only what the source states. Do not guess: a job offer received is not a job, an interview invitation is not employment, a mail from a company does not make the user its customer.',
    `- Read each source from the user's side: a source sent by ${describeOwner(owner)} shows what the user said or did; anything else shows what someone told the user.`,
    '- Give absolute dates (month and year at least) when timing matters; resolve relative dates against the source date.',
    '- One memory per topic: when several sources are about the same thing (an offer accepted, then the welcome mail), write one memory that combines them.',
    '- Do not repeat anything in "Already known", not even reworded. If a source shows a known fact has changed (new employer, new address), write the new fact with relation "updates" and the same subject and predicate. The memory text states only the current fact, never the old value.',
    '- Write in the language of "Already known"; if it is empty, write in English.',
    '- Most sources hold nothing worth remembering. An empty list is the right answer then; never pad it with weak facts.',
    '- "source" is the number of the source the fact comes from.',
    '',
    'Already known:',
    known.length ? known.map((memory) => `- ${memory}`).join('\n') : '(nothing yet)',
    '',
    'Sources:',
    units.map(formatUnit).join('\n\n'),
    '',
    `Schema:\n${FACTS_SCHEMA}`,
  ].join('\n');
}

// Keeps facts that pass the memory rules and point at a real source.
function normalizeDocumentFacts(raw, units) {
  const facts = [];
  const seen = new Set();
  for (const item of Array.isArray(raw?.facts) ? raw.facts : []) {
    const unit = units[Number(item?.source) - 1];
    const candidate = normalizeMemoryCandidate(item);
    if (!unit || !candidate) continue;
    const key = candidate.memory.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    facts.push({ candidate, document: unit.document });
  }
  return facts;
}

module.exports = {
  batchUnits,
  buildDocumentFactsPrompt,
  buildExtractionUnits,
  normalizeDocumentFacts,
};
