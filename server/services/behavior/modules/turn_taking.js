'use strict';

const { resolveAddressing } = require('../addressing');
const { buildDecisionPacket, loadRecentRoomMessages } = require('../signals');
const { getThreadState, setThreadState } = require('../state');
const { normalizeDecision, holdBackDecision } = require('../gate/decisions');
const { bypassDecision, addressDecision } = require('../gate/rules');
const { askSystemOne, SYSTEM_ONE_THRESHOLD_OFFSET } = require('../gate/system_one_judge');
const { askModel } = require('../gate/model_judge');

// SystemOne judges the room whenever it answers. When SystemOne is on, an
// outage holds back rather than handing the decision to the chat model.
async function judgeRoom(ctx, packet) {
  const systemOneDecision = await askSystemOne(ctx, packet);
  if (systemOneDecision) return systemOneDecision;
  if (ctx.systemOneEnabled) return holdBackDecision('system_one_unavailable');
  try {
    return await askModel(ctx, packet);
  } catch (error) {
    if (ctx.signal?.aborted) throw error;
    return holdBackDecision('model_unavailable');
  }
}

// Confidence measures certainty. Need score measures whether speaking is
// worthwhile, so a judged "speak" still has to clear the room threshold.
function applyNeedThreshold(decision, config, secondsSinceSpoke) {
  let needThreshold = Number(config.minimumNeedScore ?? 0.58);
  if (secondsSinceSpoke != null && secondsSinceSpoke < 120) needThreshold = Math.min(needThreshold, 0.45);
  if (decision.tokenPath === 'system_one_gate') needThreshold -= SYSTEM_ONE_THRESHOLD_OFFSET;
  if (decision.decision !== 'speak' || Number(decision.needScore || 0) >= needThreshold) {
    return { ...decision, needThreshold };
  }
  const held = normalizeDecision({
    ...decision,
    decision: 'stay_silent',
    reasonCodes: [...(decision.reasonCodes || []), 'below_need_threshold'],
  }, { tokenPath: decision.tokenPath || 'gate_only', model: decision.model });
  return decision.systemOneScores
    ? { ...held, systemOneScores: decision.systemOneScores, needThreshold }
    : { ...held, needThreshold };
}

async function shouldEngage(ctx) {
  const startedAt = Date.now();
  const { userId, agentId, msg, config, turnEpoch } = ctx;
  const finish = (decision) => ({ ...decision, latencyMs: Date.now() - startedAt, turnEpoch });

  const bypass = bypassDecision(msg, config);
  if (bypass) return finish(bypass);

  const addressing = resolveAddressing({ userId, agentId, msg });
  const addressed = addressDecision(msg, config, addressing);
  if (addressed) return finish(addressed);

  const threadState = getThreadState(userId, agentId, msg.platform, msg.chatId);
  const packet = buildDecisionPacket({
    msg,
    config,
    threadState,
    roomMessages: loadRecentRoomMessages({
      userId,
      agentId,
      platform: msg.platform,
      chatId: msg.chatId,
      limit: config.decisionContextMessageLimit,
    }),
    addressing,
  });

  const decision = applyNeedThreshold(
    await judgeRoom(ctx, packet),
    config,
    packet.room.secondsSinceAgentSpoke,
  );

  setThreadState(userId, agentId, msg.platform, msg.chatId, {
    lastDecision: decision.decision,
    lastDecisionAt: new Date().toISOString(),
    recentSilenceCount: decision.decision === 'stay_silent'
      ? Number(threadState.recentSilenceCount || 0) + 1
      : 0,
  });

  return finish(decision);
}

module.exports = {
  id: 'turn_taking',
  decide: shouldEngage,
};
