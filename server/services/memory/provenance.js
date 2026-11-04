'use strict';

const { createHash } = require('crypto');
const { parseJsonObject } = require('../../utils/text');

// Where a memory came from decides how the model may use it:
//   verified:   the user said it, or a tool result in the same run showed it
//   retrieved:  stored from somewhere else or never checked: mail, documents,
//               imports, shared rooms, the agent's own notes, rows older than this
//   assumption: inferred by a model and never confirmed
const VERIFIED_TRUST = new Set(['user_stated', 'tool_observed']);
const LOW_CONFIDENCE = 0.5;

function isVerifiedTrust(trustLevel) {
  return VERIFIED_TRUST.has(trustLevel);
}

function ownerVerification(content) {
  return { source: 'owner', digest: createHash('sha256').update(String(content || '').trim()).digest('hex') };
}

function memoryProvenance(memory) {
  const metadata = memory?.metadata || parseJsonObject(memory?.metadata_json, {});
  if (metadata.trustLevel === 'model_inference' || metadata.relation === 'derives') return 'assumption';
  if (isVerifiedTrust(metadata.trustLevel) && metadata.verification?.source === 'owner'
    && metadata.verification.digest === ownerVerification(memory.content).digest) return 'verified';
  if (memory?.confidence != null && Number(memory.confidence) < LOW_CONFIDENCE) return 'assumption';
  return 'retrieved';
}

// A restatement from a weaker source does not demote what a stronger one
// established, and the user confirming an inference settles it.
function mergeMemoryMetadata(existing, incoming) {
  const merged = { ...existing, ...incoming };
  if (isVerifiedTrust(existing.trustLevel) && !isVerifiedTrust(incoming.trustLevel)) {
    merged.trustLevel = existing.trustLevel;
    merged.relation = existing.relation;
  } else if (isVerifiedTrust(incoming.trustLevel) && merged.relation === 'derives') {
    merged.relation = 'new';
  }
  return merged;
}

// Exact, complete authored text is evidence of what was stated. Word overlap,
// object values and model-supplied quotes cannot verify a paraphrased relation.
function statementInText(text, statement) {
  const normalize = (value) => String(value || '').normalize('NFC').replace(/\s+/gu, ' ').trim();
  return Boolean(normalize(statement)) && normalize(text) === normalize(statement);
}

function textOfMessage(message) {
  return typeof message?.content === 'string' ? message.content : '';
}

function keepSupportedStatements(statements, { messages = [] }) {
  const authored = messages.filter((message) => message?.role === 'user').map(textOfMessage);
  return statements.filter((statement) => authored.some((text) => statementInText(text, statement)));
}

// Extraction creates a new subject/predicate/value assertion. Without a trusted
// structured receipt we cannot prove that relation, even if its object appears
// in the thread. Keep useful candidates as assumptions, never verified updates.
function groundMemoryCandidates(candidates, { messages = [], finalReply = '' } = {}) {
  const user = messages.filter((message) => message?.role === 'user').map(textOfMessage);
  const assistant = [...messages.filter((message) => message?.role === 'assistant').map(textOfMessage), finalReply];
  const grounded = [];
  let dropped = 0;
  for (const candidate of candidates) {
    const quote = String(candidate.evidence || '').trim();
    // An exact model-authored quote is not a new memory about the owner.
    if (quote && assistant.some((text) => text.includes(quote)) && !user.some((text) => text.includes(quote))) {
      dropped += 1;
      continue;
    }
    grounded.push({
      candidate: { ...candidate, relation: 'derives', confidence: Math.min(Number(candidate.confidence) || LOW_CONFIDENCE, LOW_CONFIDENCE) },
      trustLevel: 'model_inference',
    });
  }
  return { grounded, dropped };
}

module.exports = {
  ownerVerification,
  groundMemoryCandidates,
  isVerifiedTrust,
  keepSupportedStatements,
  memoryProvenance,
  mergeMemoryMetadata,
  statementInText,
};
