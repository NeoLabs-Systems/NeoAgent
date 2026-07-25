'use strict';

const { requestStructuredJson } = require('../model_client');
const { buildDecisionPacket, loadRecentRoomMessages } = require('../signals');
const { getThreadState, setThreadState, bumpTurnEpoch } = require('../state');
const { isModuleEnabled } = require('../config');

const SYSTEM_PROMPT = `You are NeoAgent's group turn-taking gate.
Decide whether the agent should speak now or stay silent in a multi-party chat.
Default posture in groups: prefer holding back. Speak only when the agent would add clear value, is addressed, can usefully answer an open need, should correct a harmful misunderstanding, or media/context clearly calls for a response.
Never invent hardcoded phrase rules. Judge from the provided room context and policy knobs.
Return JSON only with keys:
decision ("speak" or "stay_silent"),
confidence (0-1 number),
reasonCodes (array of short snake_case strings),
urgency ("low"|"medium"|"high"),
rationale (one short sentence).`;

function normalizeDecision(raw, fallback) {
  const decision = String(raw?.decision || fallback.decision || 'stay_silent').trim().toLowerCase();
  return {
    decision: decision === 'speak' ? 'speak' : 'stay_silent',
    confidence: Math.max(0, Math.min(1, Number(raw?.confidence ?? fallback.confidence ?? 0.5) || 0.5)),
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
}

function localFallbackDecision(packet, config) {
  if (!packet.chat.isGroup) {
    return normalizeDecision({
      decision: 'speak',
      confidence: 1,
      reasonCodes: ['direct_chat'],
      urgency: 'medium',
      rationale: 'Direct chats always engage.',
    }, { tokenPath: 'gate_skip' });
  }

  // Conservative local fallback if the model call fails: engage only when clearly addressed or media arrives.
  if (packet.event.wasMentioned || packet.policy.requireAddressHint === false && packet.event.hasMedia) {
    if (packet.event.wasMentioned || packet.event.hasMedia) {
      return normalizeDecision({
        decision: 'speak',
        confidence: 0.55,
        reasonCodes: packet.event.wasMentioned ? ['addressed'] : ['media_present'],
        urgency: 'medium',
        rationale: 'Fallback gate engaged on strong address/media signal.',
      }, { tokenPath: 'gate_fallback' });
    }
  }
  if (packet.event.wasMentioned) {
    return normalizeDecision({
      decision: 'speak',
      confidence: 0.6,
      reasonCodes: ['addressed'],
      urgency: 'medium',
      rationale: 'Fallback gate engaged because the agent was addressed.',
    }, { tokenPath: 'gate_fallback' });
  }
  return normalizeDecision({
    decision: 'stay_silent',
    confidence: 0.7,
    reasonCodes: ['prefer_hold_back', 'model_unavailable'],
    urgency: 'low',
    rationale: 'Fallback gate holds back in groups when address is unclear.',
  }, { tokenPath: 'gate_fallback' });
}

function cooldownBlocks(packet, config, threadState) {
  const cooldown = Number(config.cooldownSeconds || 0);
  if (!cooldown || !threadState?.lastSpokeAt) return false;
  if (packet.event.wasMentioned) return false;
  const elapsed = (Date.now() - Date.parse(threadState.lastSpokeAt)) / 1000;
  return Number.isFinite(elapsed) && elapsed < cooldown;
}

async function shouldEngage(ctx) {
  const {
    userId,
    agentId,
    msg,
    config,
    signal = null,
    memoryHints = [],
  } = ctx;

  if (!msg?.isGroup || !isModuleEnabled(config, 'turn_taking') || config.enabled === false) {
    const threadState = bumpTurnEpoch(userId, agentId, msg.platform, msg.chatId);
    return {
      decision: 'speak',
      confidence: 1,
      reasonCodes: msg?.isGroup ? ['turn_taking_disabled'] : ['direct_chat'],
      urgency: 'medium',
      rationale: msg?.isGroup ? 'Turn-taking disabled; engaging.' : 'Direct chat always engages.',
      tokenPath: 'gate_skip',
      turnEpoch: threadState.turnEpoch,
      packet: null,
    };
  }

  const threadState = bumpTurnEpoch(userId, agentId, msg.platform, msg.chatId);
  const roomMessages = loadRecentRoomMessages({
    userId,
    agentId,
    platform: msg.platform,
    chatId: msg.chatId,
    limit: 12,
  });
  const packet = buildDecisionPacket({
    msg,
    config,
    threadState,
    roomMessages,
    localMemoryHints: memoryHints,
  });

  if (cooldownBlocks(packet, config, threadState)) {
    const decision = normalizeDecision({
      decision: 'stay_silent',
      confidence: 0.8,
      reasonCodes: ['cooldown'],
      urgency: 'low',
      rationale: 'Recently spoke; holding back unless clearly needed.',
    }, { tokenPath: 'gate_only' });
    setThreadState(userId, agentId, msg.platform, msg.chatId, {
      lastDecision: decision.decision,
      lastDecisionAt: new Date().toISOString(),
      recentSilenceCount: Number(threadState.recentSilenceCount || 0) + 1,
    });
    return { ...decision, turnEpoch: threadState.turnEpoch, packet };
  }

  let decision;
  try {
    const result = await requestStructuredJson({
      userId,
      agentId,
      preference: config.decisionModelPreference || 'cheap',
      system: SYSTEM_PROMPT,
      prompt: JSON.stringify(packet),
      signal,
      maxTokens: 220,
    });
    decision = normalizeDecision(result.parsed || {}, {
      decision: 'stay_silent',
      confidence: 0.55,
      reasonCodes: ['parse_fallback'],
      urgency: 'low',
      rationale: 'Could not parse gate response; holding back.',
      tokenPath: 'gate_only',
      model: result.modelSelectionId || result.model,
    });
    decision.model = result.modelSelectionId || result.model;
  } catch (error) {
    if (signal?.aborted) throw error;
    decision = localFallbackDecision(packet, config);
    decision.error = error?.message || String(error);
  }

  // Soft bias: high hold-back strength converts weak speak decisions into silence.
  if (
    decision.decision === 'speak'
    && Number(decision.confidence || 0) < Number(config.holdBackStrength || 0.72)
    && !packet.event.wasMentioned
    && !packet.event.hasMedia
  ) {
    decision = normalizeDecision({
      ...decision,
      decision: 'stay_silent',
      reasonCodes: [...(decision.reasonCodes || []), 'hold_back_strength'],
      rationale: decision.rationale || 'Confidence below hold-back threshold.',
    }, { tokenPath: decision.tokenPath || 'gate_only', model: decision.model });
  }

  setThreadState(userId, agentId, msg.platform, msg.chatId, {
    lastDecision: decision.decision,
    lastDecisionAt: new Date().toISOString(),
    recentSilenceCount: decision.decision === 'stay_silent'
      ? Number(threadState.recentSilenceCount || 0) + 1
      : 0,
    lastSpokeAt: decision.decision === 'speak'
      ? new Date().toISOString()
      : threadState.lastSpokeAt,
  });

  return {
    ...decision,
    turnEpoch: threadState.turnEpoch,
    packet,
  };
}

module.exports = {
  id: 'turn_taking',
  shouldEngage,
  normalizeDecision,
  localFallbackDecision,
};
