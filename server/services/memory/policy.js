function normalizeMemoryCandidate(content) {
  return String(content || '')
    .replace(/\r\n/g, '\n')
    .trim();
}

// A memory is one short fact. Longer text is source material, not memory.
const MAX_MEMORY_CHARS = 150;

function getMemoryStorageDecision(content) {
  const normalized = normalizeMemoryCandidate(content);
  if (!normalized) {
    return {
      allow: false,
      normalized,
      reason: 'empty',
    };
  }
  if (normalized.length > MAX_MEMORY_CHARS) {
    return {
      allow: false,
      normalized,
      reason: 'too_long',
    };
  }

  return {
    allow: true,
    normalized,
    reason: null,
  };
}

module.exports = {
  MAX_MEMORY_CHARS,
  getMemoryStorageDecision,
  normalizeMemoryCandidate,
};
