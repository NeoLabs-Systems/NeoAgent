function normalizeMemoryCandidate(content) {
  return String(content || '')
    .replace(/\r\n/g, '\n')
    .trim();
}

function isStructuredRunSummary(text) {
  if (!text) return false;
  if (/^recent\s+[a-z0-9_-]+\s+run\b/i.test(text)) return true;

  const hasTitle = /(^|\n)Title:\s+/i.test(text);
  const hasRequest = /(^|\n)Request:\s+/i.test(text);
  const hasOutcome = /(^|\n)Outcome:\s+/i.test(text);
  return hasOutcome && (hasTitle || hasRequest);
}

function isTransientOperationalMemory(content) {
  const text = normalizeMemoryCandidate(content);
  if (!text) return false;
  if (isStructuredRunSummary(text)) return true;

  const lower = text.toLowerCase();
  const hasRecency = /\b(recent|latest|current|today|tonight|just now|this run|last run)\b/.test(lower);
  const hasRunEntity = /\b(task|scheduled run|schedule run|agent run|task run|workflow run|job run)\b/.test(lower);
  const hasExecutionState = /\b(status|completed|succeeded|failed|errored|finished|started|triggered|executed|ran)\b/.test(lower);

  if (hasRecency && hasRunEntity && hasExecutionState) {
    return true;
  }

  if (/(^|\n)(status|outcome|result):\s+/i.test(text) && hasRunEntity) {
    return true;
  }

  return false;
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

  if (isTransientOperationalMemory(normalized)) {
    return {
      allow: false,
      normalized,
      reason: 'transient_operational',
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
  isTransientOperationalMemory,
  normalizeMemoryCandidate,
};
