function normalizeMemoryCandidate(content) {
  return String(content || '')
    .replace(/\r\n/g, '\n')
    .trim();
}

function getMemoryStorageDecision(content) {
  const normalized = normalizeMemoryCandidate(content);
  if (!normalized) {
    return {
      allow: false,
      normalized,
      reason: 'empty',
    };
  }

  return {
    allow: true,
    normalized,
    reason: null,
  };
}

module.exports = {
  getMemoryStorageDecision,
  normalizeMemoryCandidate,
};
