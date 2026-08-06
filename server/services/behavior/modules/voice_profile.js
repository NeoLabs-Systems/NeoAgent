'use strict';

/**
 * Living relationship style: freeform notes only.
 * No enum personality knobs, no seeded "dry/terse/sass" defaults.
 * Memory + user notes evolve the voice; the model interprets them.
 */

function cleanText(value, maxLength = 1200) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, maxLength);
}

function normalizeNotes(value, limit = 12) {
  const list = Array.isArray(value)
    ? value
    : (value ? String(value).split(/\n+/) : []);
  const notes = [];
  const seen = new Set();
  for (const item of list) {
    const note = cleanText(item, 280);
    if (!note) continue;
    const key = note.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    notes.push(note);
    if (notes.length >= limit) break;
  }
  return notes;
}

/** Accept freeform style blobs from identity.voice / ai_personality. */
function collectStyleNotes({
  selfStateIdentity = {},
  aiPersonality = null,
  behaviorNotes = '',
} = {}) {
  const notes = [];

  const voice = selfStateIdentity?.voice || selfStateIdentity?.voice_profile || null;
  if (typeof voice === 'string') {
    notes.push(voice);
  } else if (voice && typeof voice === 'object') {
    if (Array.isArray(voice.notes)) notes.push(...voice.notes);
    else if (typeof voice.notes === 'string') notes.push(voice.notes);
    // Legacy structured profiles: fold any leftover fields into prose, don't re-enforce enums.
    for (const [key, value] of Object.entries(voice)) {
      if (key === 'notes' || value == null || value === '') continue;
      if (typeof value === 'string' || typeof value === 'number') {
        notes.push(`${key}: ${value}`);
      }
    }
  }

  if (aiPersonality && typeof aiPersonality === 'object' && !Array.isArray(aiPersonality)) {
    if (Array.isArray(aiPersonality.notes)) notes.push(...aiPersonality.notes);
    if (aiPersonality.style_notes) notes.push(aiPersonality.style_notes);
    if (typeof aiPersonality.voice === 'string') notes.push(aiPersonality.voice);
    else if (aiPersonality.voice && typeof aiPersonality.voice === 'object') {
      if (aiPersonality.voice.notes) notes.push(...normalizeNotes(aiPersonality.voice.notes));
    }
    // Freeform leftover fields as soft hints
    for (const [key, value] of Object.entries(aiPersonality)) {
      if (['notes', 'style_notes', 'voice', 'voice_profile'].includes(key)) continue;
      if (typeof value === 'string' && value.trim()) notes.push(`${key}: ${value.trim()}`);
    }
  } else if (typeof aiPersonality === 'string' && aiPersonality.trim()) {
    notes.push(aiPersonality.trim());
  }

  if (behaviorNotes) notes.push(behaviorNotes);

  return normalizeNotes(notes);
}

function formatStyleNotesForPrompt(notes) {
  const list = normalizeNotes(notes);
  if (!list.length) return '';
  return [
    '## Living Style Notes',
    'How this relationship usually texts. Interpret freely; do not treat as rigid knobs or scripts.',
    'They may gently shape register (tone, length, casing, humor, language mix).',
    'Safety, truth, and the current request still win. Do not announce these notes.',
    ...list.map((note) => `- ${note}`),
  ].join('\n');
}

/**
 * Turn a consolidated assistant_self fact into a freeform style note.
 * Returns null when the fact is not style-related.
 */
function styleNoteFromFact({ predicate, object, memory } = {}) {
  const pred = cleanText(predicate, 80).toLowerCase();
  const obj = cleanText(object || memory, 280);
  if (!pred || !obj) return null;
  if (!/(style|voice|tone|text|reply|write|speak|humor|sass|roast|casing|emoji|language|brevity|warmth|personality|register)/.test(pred)
    && !/(style|voice|tone|lowercase|humor|sass|roast|emoji|kurz|formal|informal)/.test(obj.toLowerCase())) {
    // Still allow explicit assistant_self writing facts via memory text.
    if (!/(how (you|the assistant) (should )?(write|text|reply|talk)|schreibweise|texting)/i.test(`${pred} ${obj}`)) {
      return null;
    }
  }
  if (pred === 'writing_style' || pred === 'voice' || pred === 'tone' || pred === 'texting_style') {
    return obj;
  }
  return `${pred}: ${obj}`;
}

function mergeStyleNotes(existing, incoming, limit = 12) {
  return normalizeNotes([...(existing || []), ...(incoming || [])], limit);
}

module.exports = {
  collectStyleNotes,
  formatStyleNotesForPrompt,
  styleNoteFromFact,
  mergeStyleNotes,
  normalizeNotes,
};
