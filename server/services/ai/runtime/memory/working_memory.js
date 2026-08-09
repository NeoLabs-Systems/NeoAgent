'use strict';

/**
 * In-run working memory. Never written to durable semantic memory.
 */
function createWorkingMemory(seed = {}) {
  const state = {
    contractVersion: seed.contractVersion || 0,
    openQuestions: Array.isArray(seed.openQuestions) ? [...seed.openQuestions] : [],
    artifacts: Array.isArray(seed.artifacts) ? [...seed.artifacts] : [],
    defects: Array.isArray(seed.defects) ? [...seed.defects] : [],
    evidence: Array.isArray(seed.evidence) ? [...seed.evidence] : [],
    sideEffects: Array.isArray(seed.sideEffects) ? [...seed.sideEffects] : [],
    decisions: Array.isArray(seed.decisions) ? [...seed.decisions] : [],
    draftResponse: seed.draftResponse || '',
  };

  return {
    snapshot() {
      return JSON.parse(JSON.stringify(state));
    },
    setContractVersion(version) {
      state.contractVersion = Number(version) || 0;
    },
    addEvidence(item) {
      state.evidence.push({
        id: item.id || `ev_${state.evidence.length + 1}`,
        ...item,
        at: item.at || new Date().toISOString(),
      });
    },
    addArtifact(item) {
      const artifactId = String(item?.artifactId || item?.id || '').trim();
      if (!artifactId || state.artifacts.some((artifact) => artifact.artifactId === artifactId)) {
        return;
      }
      state.artifacts.push({ ...item, artifactId });
    },
    addDefect(item) {
      state.defects.push(item);
    },
    addSideEffect(item) {
      state.sideEffects.push(item);
    },
    addDecision(decision) {
      state.decisions.push({
        kind: decision.kind,
        at: decision.createdAt || new Date().toISOString(),
        summary: decision.content?.slice?.(0, 200) || decision.completionClaim?.summary || decision.kind,
      });
      if (state.decisions.length > 50) state.decisions.shift();
    },
    setDraftResponse(text) {
      state.draftResponse = String(text || '');
    },
    clearDefects() {
      state.defects = [];
    },
  };
}

module.exports = {
  createWorkingMemory,
};
