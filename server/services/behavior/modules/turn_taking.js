'use strict';

const { requestDecision, requestStructuredJson } = require('../model_client');
const { resolveAddressing } = require('../addressing');
const { buildDecisionPacket, loadRecentRoomMessages } = require('../signals');
const { getThreadState, setThreadState } = require('../state');
const { isModuleEnabled } = require('../config');

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
urgency ("low"|"medium"|"high"),
rationale (one short sentence).`;

// Jev answers the same gate as the model above: one request, a few hundred
// milliseconds, with probabilities instead of self-reported scores.
const JEV_GATE_QUESTIONS = Object.freeze({
  speak: {
    type: 'noul',
    instructions: 'The agent named in `agent.names` should post a reply to `latest_message` now.',
    criteria: {
      true: 'Someone asks the agent something, asks the group a question the agent can answer with what `agent.can` do, follows up on the agent\'s last message, or says something harmful that should be corrected.',
      false: 'Side chatter, greetings, feelings, or talk meant for another person in the chat, where nobody needs the agent.',
    },
  },
  for_someone_else: {
    type: 'noul',
    instructions: '`latest_message` is meant for a specific other person in the chat, not for the agent or the whole group.',
  },
  urgency: {
    type: 'score',
    instructions: 'How time-sensitive is a reply to `latest_message`?',
    criteria: ['Not time-sensitive', 'Should be answered soon', 'Needed right now'],
  },
});
// Without a description of what the agent can do, Jev treats open questions
// to the room as not the agent's business.
const AGENT_CAPABILITIES = 'answer questions, look things up on the web, and do tasks with its tools and connected apps';
// Jev's scores are calibrated probabilities, so the room threshold that was
// tuned on self-reported model scores can sit a little lower for them.
const JEV_THRESHOLD_OFFSET = 0.08;
const URGENCY_LEVELS = ['low', 'medium', 'high'];

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

function jevGateState(packet) {
  return {
    agent: {
      names: packet.room.agentNames.length ? packet.room.agentNames : ['the assistant'],
      can: AGENT_CAPABILITIES,
    },
    chat: { platform: packet.chat.platform, name: packet.chat.groupName },
    latest_message: {
      sender: packet.sender.name || packet.sender.username || 'participant',
      content: packet.event.content,
      has_media: packet.event.hasMedia,
    },
    recent_messages: packet.room.recentMessages,
    seconds_since_agent_spoke: packet.room.secondsSinceAgentSpoke,
    room_hints: packet.roomHints,
  };
}

// The need score is the chance a reply is wanted now and is meant for the
// agent, so messages aimed at someone else stay quiet even when useful.
function decisionFromJev(answers) {
  const speak = answers.speak.noul;
  const forSomeoneElse = answers.for_someone_else.noul;
  const reasonCodes = ['jev_gate', speak >= 0.5 ? 'agent_can_help' : 'hold_back'];
  if (forSomeoneElse >= 0.5) reasonCodes.push('meant_for_someone_else');
  return normalizeDecision({
    decision: speak >= 0.5 ? 'speak' : 'stay_silent',
    needScore: speak * (1 - forSomeoneElse),
    confidence: Math.max(speak, 1 - speak),
    reasonCodes,
    urgency: URGENCY_LEVELS[Math.round(Math.max(0, Math.min(2, answers.urgency.score)))],
    rationale: `speak ${speak.toFixed(2)}, meant for someone else ${forSomeoneElse.toFixed(2)}`,
  }, { tokenPath: 'jev_gate', model: 'jev' });
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

  if (packet.event.wasMentioned || packet.event.repliedToAgent || packet.event.addressedByName) {
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

  const addressing = resolveAddressing({ userId, agentId, msg });
  if (addressing.structurallyAddressed) {
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

  if (addressing.addressedByName) {
    return {
      decision: 'speak',
      needScore: 1,
      confidence: 0.9,
      reasonCodes: ['addressed_by_name'],
      urgency: 'medium',
      rationale: 'The message names the agent without a platform mention tag.',
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
    addressing,
  });

  let decision;
  const jevAnswers = await requestDecision({
    agentEngine,
    userId,
    agentId,
    phase: 'jev_turn_taking',
    signal,
    state: jevGateState(packet),
    questions: JEV_GATE_QUESTIONS,
  });
  if (jevAnswers) {
    decision = decisionFromJev(jevAnswers);
  } else {
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
  }

  const secondsSinceSpoke = packet.room.secondsSinceAgentSpoke;
  const followUp = secondsSinceSpoke != null && secondsSinceSpoke < 120;
  let needThreshold = Number(config.minimumNeedScore ?? 0.58);
  if (followUp) needThreshold = Math.min(needThreshold, 0.45);
  if (decision.tokenPath === 'jev_gate') needThreshold -= JEV_THRESHOLD_OFFSET;

  // Confidence measures certainty. Need score measures whether speaking is worthwhile.
  if (
    decision.decision === 'speak'
    && Number(decision.needScore || 0) < needThreshold
    && !packet.event.wasMentioned
    && !packet.event.repliedToAgent
    && !packet.event.addressedByName
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
