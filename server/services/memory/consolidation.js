'use strict';

const MEMORY_RELATIONS = new Set(['new', 'updates', 'extends', 'derives']);
const MEMORY_CATEGORIES = new Set([
  'identity',
  'preferences',
  'projects',
  'contacts',
  'events',
  'tasks',
  'episodic',
  'procedural',
  'assistant_self',
]);

function cleanText(value, maxLength) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, maxLength);
}

function normalizeDate(value) {
  const text = cleanText(value, 80);
  if (!text) return null;
  const timestamp = Date.parse(text);
  return Number.isFinite(timestamp) ? new Date(timestamp).toISOString() : null;
}

function normalizeConfidence(value) {
  const confidence = Number(value);
  if (!Number.isFinite(confidence)) return 0.7;
  return Math.max(0, Math.min(1, confidence));
}

function normalizeMemoryCandidate(candidate) {
  if (!candidate || typeof candidate !== 'object' || Array.isArray(candidate)) {
    return null;
  }

  const subject = cleanText(candidate.subject, 180);
  const predicate = cleanText(candidate.predicate, 120).toLowerCase();
  const object = cleanText(candidate.object, 900);
  const memory = cleanText(candidate.memory, 1200);
  if (!subject || !predicate || !object || !memory) return null;

  const relation = cleanText(candidate.relation, 24).toLowerCase();
  const category = cleanText(candidate.category, 40).toLowerCase();

  const finalRelation = MEMORY_RELATIONS.has(relation) ? relation : 'new';
  let finalConfidence = normalizeConfidence(candidate.confidence);
  if (finalRelation === 'derives') {
    finalConfidence = Math.min(finalConfidence, 0.6);
  }

  return {
    memory,
    subject,
    predicate,
    object,
    relation: finalRelation,
    category: MEMORY_CATEGORIES.has(category) ? category : 'episodic',
    confidence: finalConfidence,
    importance: Math.max(1, Math.min(10, Number(candidate.importance) || 5)),
    isStatic: candidate.is_static === true || candidate.isStatic === true,
    validFrom: normalizeDate(candidate.valid_from || candidate.validFrom),
    validTo: normalizeDate(candidate.valid_to || candidate.validTo),
    forgetAfter: normalizeDate(candidate.forget_after || candidate.forgetAfter),
    evidence: cleanText(candidate.evidence, 500),
  };
}

function normalizeMemoryCandidates(value, limit = 12) {
  if (!Array.isArray(value)) return [];
  const candidates = [];
  const seen = new Set();

  for (const item of value) {
    const candidate = normalizeMemoryCandidate(item);
    if (!candidate) continue;
    const key = [
      candidate.subject.toLowerCase(),
      candidate.predicate,
      candidate.object.toLowerCase(),
    ].join('\u0000');
    if (seen.has(key)) continue;
    seen.add(key);
    candidates.push(candidate);
    if (candidates.length >= limit) break;
  }

  return candidates;
}

function buildMemoryConsolidationInstructions(currentDateTime) {
  return [
    'Also extract durable memory candidates from the thread.',
    `Current date/time: ${currentDateTime}. Resolve relative dates against this value.`,
    'A memory candidate must be an atomic fact that will improve a future conversation.',
    'Prefer explicit user statements and verified outcomes. Do not turn assistant guesses, suggestions, questions, or unverified claims into user facts.',
    'Exclude secrets, credentials, private tokens, raw tool output, routine task narration, and facts useful only inside this thread.',
    'Use relation="updates" when a fact replaces an older value for the same subject and predicate.',
    'Use relation="extends" when it adds compatible detail without replacing the prior fact.',
    'Use relation="derives" only for a strongly supported inference and lower its confidence.',
    'Use is_static=true only for stable identity or durable preference facts.',
    'Use category="procedural" only for reusable workflows or repeatable tool-use procedures, not one-off task status.',
    'Use category="assistant_self" when the user clearly trains how the assistant should write or behave with them (tone, length, language mix, humor, casing preferences, etc.). Prefer freeform memory text over rigid labels. Only store this when explicit or repeatedly reinforced — not from one joke.',
    'Set valid_from, valid_to, or forget_after as ISO-8601 timestamps when the thread provides temporal boundaries.',
    'Return an empty memory_candidates array when nothing is worth retaining.',
  ].join(' ');
}

module.exports = {
  buildMemoryConsolidationInstructions,
  normalizeMemoryCandidate,
  normalizeMemoryCandidates,
};
