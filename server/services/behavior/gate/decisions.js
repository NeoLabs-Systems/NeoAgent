'use strict';

const URGENCY_LEVELS = ['low', 'medium', 'high'];

// A turn settled by a rule, with no model involved.
function ruleDecision(decision, reasonCode, { confidence = 1 } = {}) {
  const speak = decision === 'speak';
  return {
    decision,
    needScore: speak ? 1 : 0,
    confidence,
    reasonCodes: [reasonCode],
    urgency: speak ? 'medium' : 'low',
    tokenPath: 'gate_skip',
  };
}

// The gate holds back when no judge could answer.
function holdBackDecision(failureCode) {
  return {
    ...normalizeDecision({
      decision: 'stay_silent',
      needScore: 0,
      confidence: 0.7,
      reasonCodes: ['prefer_hold_back', failureCode],
      urgency: 'low',
    }, { tokenPath: 'gate_fallback' }),
    failureCode,
  };
}

function normalizeDecision(raw, fallback) {
  const decision = String(raw?.decision || fallback.decision || 'stay_silent').trim().toLowerCase();
  const score = (value, fallbackValue) => {
    const number = Number(value);
    const normalized = Number.isFinite(number) ? number : Number(fallbackValue);
    return Math.max(0, Math.min(1, Number.isFinite(normalized) ? normalized : 0.5));
  };
  const normalized = {
    decision: decision === 'speak' ? 'speak' : 'stay_silent',
    needScore: score(raw?.needScore, fallback.needScore),
    confidence: score(raw?.confidence, fallback.confidence),
    reasonCodes: Array.isArray(raw?.reasonCodes)
      ? raw.reasonCodes.map((item) => String(item || '').trim()).filter(Boolean).slice(0, 8)
      : (fallback.reasonCodes || []),
    urgency: URGENCY_LEVELS.includes(String(raw?.urgency || ''))
      ? String(raw.urgency)
      : (fallback.urgency || 'low'),
    tokenPath: fallback.tokenPath || 'gate_only',
    model: raw?.model || fallback.model || null,
  };
  const usage = Number(raw?.usage ?? fallback.usage);
  if (Number.isFinite(usage)) normalized.usage = usage;
  return normalized;
}

module.exports = {
  URGENCY_LEVELS,
  ruleDecision,
  holdBackDecision,
  normalizeDecision,
};
