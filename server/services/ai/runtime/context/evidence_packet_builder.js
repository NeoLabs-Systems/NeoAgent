'use strict';

/**
 * Build a typed evidence packet for model context.
 * Facts remain traceable to source IDs; no undifferentiated memory dump.
 */
function buildEvidencePacket({
  queryIntent = 'current_task',
  facts = [],
  episodes = [],
  procedures = [],
  toolEvidence = [],
  conflicts = [],
  missingInformation = [],
  maxFacts = 12,
  maxEpisodes = 4,
  maxProcedures = 4,
  maxToolEvidence = 20,
} = {}) {
  const normalizeFact = (fact) => ({
    fact_id: fact.fact_id || fact.id || null,
    statement: String(fact.statement || fact.content || '').slice(0, 500),
    confidence: Number(fact.confidence ?? 0.5),
    valid_at: fact.valid_at || fact.validAt || null,
    source_ids: Array.isArray(fact.source_ids || fact.sourceIds)
      ? (fact.source_ids || fact.sourceIds).slice(0, 8)
      : [],
    trust: fact.trust || fact.asserted_by || fact.assertedBy || 'assistant_inference',
  });

  return {
    query_intent: queryIntent,
    facts: (facts || []).slice(0, maxFacts).map(normalizeFact).filter((f) => f.statement),
    episodes: (episodes || []).slice(0, maxEpisodes).map((episode) => ({
      run_id: episode.run_id || episode.runId || null,
      outcome: String(episode.outcome || episode.summary || '').slice(0, 400),
      relevance: Number(episode.relevance ?? 0),
    })),
    procedures: (procedures || []).slice(0, maxProcedures).map((proc) => ({
      skill_id: proc.skill_id || proc.id || null,
      validated_version: proc.validated_version || proc.version || null,
      name: proc.name || null,
    })),
    tool_evidence: (toolEvidence || []).slice(0, maxToolEvidence).map((item, index) => ({
      id: item.id || `tool_ev_${index + 1}`,
      tool: item.tool || item.toolName || null,
      summary: String(item.summary || item.resultPreview || '').slice(0, 600),
      success: item.success !== false,
      source_ids: item.source_ids || [],
    })),
    conflicts: Array.isArray(conflicts) ? conflicts.slice(0, 8) : [],
    missing_information: Array.isArray(missingInformation) ? missingInformation.slice(0, 8) : [],
  };
}

function appendToolEvidence(packet, toolName, result, { success = true } = {}) {
  const next = packet && typeof packet === 'object'
    ? { ...packet, tool_evidence: [...(packet.tool_evidence || [])] }
    : buildEvidencePacket();
  const summary = typeof result === 'string'
    ? result
    : JSON.stringify(result ?? {}).slice(0, 600);
  next.tool_evidence.push({
    id: `tool_ev_${next.tool_evidence.length + 1}`,
    tool: toolName,
    summary,
    success,
    source_ids: [`tool:${toolName}`],
  });
  return next;
}

module.exports = {
  buildEvidencePacket,
  appendToolEvidence,
};
