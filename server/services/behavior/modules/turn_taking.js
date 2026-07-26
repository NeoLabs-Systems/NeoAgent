'use strict';

const { requestStructuredJson } = require('../model_client');
const { buildDecisionPacket, loadRecentRoomMessages } = require('../signals');
const { getThreadState, setThreadState } = require('../state');
const { isModuleEnabled } = require('../config');

const SYSTEM_PROMPT = `You are NeoAgent's group turn-taking gate.
Decide whether the agent should speak now or stay silent in a multi-party chat.
Default posture in groups: prefer holding back. Speak only when the agent would add clear value, is addressed, can usefully answer an open need, should correct a harmful misunderstanding, or media/context clearly calls for a response.
Judge the meaning and flow of the provided room context. Do not use phrase matching or keyword rules.
Return JSON only with keys:
decision ("speak" or "stay_silent"),
needScore (0-1 number measuring how worthwhile an agent contribution is now),
confidence (0-1 number),
reasonCodes (array of short snake_case strings),
urgency ("low"|"medium"|"high"),
rationale (one short sentence).`;

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
    urgency: ['low', 'medium', 'high'].includes(String(raw?.urgency || ''))
      ? String(raw.urgency)
      : (fallback.urgency || 'low'),
    rationale: String(raw?.rationale || fallback.rationale || '').trim().slice(0, 240),
    tokenPath: fallback.tokenPath || 'gate_only',
    model: raw?.model || fallback.model || null,
  };
  const usage = Number(raw?.usage ?? fallback.usage);
  if (Number.isFinite(usage)) normalized.usage = usage;
  return normalized;
}

function localFallbackDecision(packet, config) {
  if (!packet.chat.isGroup) {
    return normalizeDecision({
      decision: 'speak',
      needScore: 1,
      confidence: 1,
      reasonCodes: ['direct_chat'],
      urgency: 'medium',
      rationale: 'Direct chats always engage.',
    }, { tokenPath: 'gate_skip' });
  }

  if (packet.event.wasMentioned || packet.event.repliedToAgent) {
    return normalizeDecision({
      decision: 'speak',
      needScore: 1,
      confidence: 0.85,
      reasonCodes: [packet.event.repliedToAgent ? 'reply_to_agent' : 'addressed'],
      urgency: 'medium',
      rationale: 'Fallback engaged because platform metadata directly addresses the agent.',
    }, { tokenPath: 'gate_fallback' });
  }
  return normalizeDecision({
    decision: 'stay_silent',
    needScore: 0,
    confidence: 0.7,
    reasonCodes: ['prefer_hold_back', 'model_unavailable'],
    urgency: 'low',
    rationale: 'Fallback gate holds back in groups when address is unclear.',
  }, { tokenPath: 'gate_fallback' });
}

async function shouldEngage(ctx) {
  const startedAt = Date.now();
  const {
    userId,
    agentId,
    msg,
    config,
    signal = null,
    memoryHints = [],
    agentEngine,
    turnEpoch,
  } = ctx;

  if (!msg?.isGroup || !isModuleEnabled(config, 'turn_taking') || config.enabled === false) {
    return {
      decision: 'speak',
      needScore: 1,
      confidence: 1,
      reasonCodes: msg?.isGroup ? ['turn_taking_disabled'] : ['direct_chat'],
      urgency: 'medium',
      rationale: msg?.isGroup ? 'Turn-taking disabled; engaging.' : 'Direct chat always engages.',
      tokenPath: 'gate_skip',
      latencyMs: Date.now() - startedAt,
      turnEpoch,
    };
  }

  if (msg.wasMentioned || msg.repliedToAgent) {
    return {
      decision: 'speak',
      needScore: 1,
      confidence: 1,
      reasonCodes: [msg.repliedToAgent ? 'reply_to_agent' : 'addressed'],
      urgency: 'medium',
      rationale: 'Platform metadata directly addresses the agent.',
      tokenPath: 'gate_skip',
      latencyMs: Date.now() - startedAt,
      turnEpoch,
    };
  }

  const mode = config.participationMode || 'automatic';
  if (mode === 'always') {
    return {
      decision: 'speak',
      needScore: 1,
      confidence: 1,
      reasonCodes: ['participation_always'],
      urgency: 'medium',
      rationale: 'Room participation is configured to always engage.',
      tokenPath: 'gate_skip',
      latencyMs: Date.now() - startedAt,
      turnEpoch,
    };
  }
  if (mode === 'mention_only') {
    return {
      decision: 'stay_silent',
      needScore: 0,
      confidence: 1,
      reasonCodes: ['mention_only'],
      urgency: 'low',
      rationale: 'Room participation requires a structural mention or reply.',
      tokenPath: 'gate_skip',
      latencyMs: Date.now() - startedAt,
      turnEpoch,
    };
  }

  const threadState = getThreadState(userId, agentId, msg.platform, msg.chatId);
  const roomMessages = loadRecentRoomMessages({
    userId,
    agentId,
    platform: msg.platform,
    chatId: msg.chatId,
    limit: config.decisionContextMessageLimit,
  });
  const packet = buildDecisionPacket({
    msg,
    config,
    threadState,
    roomMessages,
    localMemoryHints: memoryHints,
  });

  let decision;
  try {
    const result = await requestStructuredJson({
      agentEngine,
      userId,
      agentId,
      modelId: config.decisionModelId,
      purpose: config.decisionModelPurpose,
      system: SYSTEM_PROMPT,
      prompt: JSON.stringify(packet),
      signal,
      maxTokens: 220,
      fallback: {
        decision: 'stay_silent',
        needScore: 0,
        confidence: 0.55,
        reasonCodes: ['parse_fallback'],
        urgency: 'low',
        rationale: 'The decision could not be parsed.',
      },
    });
    decision = normalizeDecision(result.parsed || {}, {
      decision: 'stay_silent',
      needScore: 0,
      confidence: 0.55,
      reasonCodes: ['parse_fallback'],
      urgency: 'low',
      rationale: 'Could not parse gate response; holding back.',
      tokenPath: 'gate_only',
      model: result.modelSelectionId || result.model,
    });
    decision.model = result.modelSelectionId || result.model;
    decision.usage = Number(result.usage || 0);
  } catch (error) {
    if (signal?.aborted) throw error;
    decision = localFallbackDecision(packet, config);
    decision.failureCode = 'model_unavailable';
  }

  // Confidence measures certainty. Need score measures whether speaking is worthwhile.
  if (
    decision.decision === 'speak'
    && Number(decision.needScore || 0) < Number(config.minimumNeedScore ?? 0.72)
    && !packet.event.wasMentioned
    && !packet.event.repliedToAgent
  ) {
    decision = normalizeDecision({
      ...decision,
      decision: 'stay_silent',
      reasonCodes: [...(decision.reasonCodes || []), 'below_need_threshold'],
      rationale: decision.rationale || 'The contribution value is below the room threshold.',
    }, { tokenPath: decision.tokenPath || 'gate_only', model: decision.model });
  }

  setThreadState(userId, agentId, msg.platform, msg.chatId, {
    lastDecision: decision.decision,
    lastDecisionAt: new Date().toISOString(),
    recentSilenceCount: decision.decision === 'stay_silent'
      ? Number(threadState.recentSilenceCount || 0) + 1
      : 0,
  });

  return {
    ...decision,
    latencyMs: Date.now() - startedAt,
    turnEpoch,
  };
}

module.exports = {
  id: 'turn_taking',
  decide: shouldEngage,
  shouldEngage,
  normalizeDecision,
  localFallbackDecision,
};
