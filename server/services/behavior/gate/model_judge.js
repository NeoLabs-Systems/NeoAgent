'use strict';

const { requestStructuredJson } = require('../model_client');
const { normalizeDecision } = require('./decisions');

const SYSTEM_PROMPT = `You are NeoAgent's group turn-taking gate.
Decide whether the agent should speak now or stay silent in a multi-party chat.
Hold back on side chatter and talk that is clearly only between other people.
Speak when the agent is named or addressed, someone asks the agent a question, the room is waiting after the agent just spoke, the agent can usefully answer an open need, or a harmful misunderstanding should be corrected.
Judge the meaning and flow of the provided room context. Do not use phrase matching or keyword rules.
Return JSON only with keys:
decision ("speak" or "stay_silent"),
needScore (0-1 number measuring how worthwhile an agent contribution is now),
confidence (0-1 number),
reasonCodes (array of short snake_case strings),
urgency ("low"|"medium"|"high").`;

const PARSE_FALLBACK = Object.freeze({
  decision: 'stay_silent',
  needScore: 0,
  confidence: 0.55,
  reasonCodes: ['parse_fallback'],
  urgency: 'low',
});

async function askModel(ctx, packet) {
  const { config } = ctx;
  const result = await requestStructuredJson({
    agentEngine: ctx.agentEngine,
    userId: ctx.userId,
    agentId: ctx.agentId,
    modelId: config.decisionModelId,
    purpose: config.decisionModelPurpose,
    system: SYSTEM_PROMPT,
    prompt: JSON.stringify(packet),
    signal: ctx.signal,
    maxTokens: 220,
    fallback: PARSE_FALLBACK,
  });
  const model = result.modelSelectionId || result.model;
  return {
    ...normalizeDecision(result.parsed || {}, {
      ...PARSE_FALLBACK,
      tokenPath: 'gate_only',
      model,
    }),
    model,
    usage: Number(result.usage || 0),
  };
}

module.exports = {
  askModel,
};
