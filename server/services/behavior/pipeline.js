'use strict';

const { resolveBehaviorConfig, isModuleEnabled } = require('./config');
const {
  bumpTurnEpoch,
  getThreadState,
  isTurnCurrent,
  markSpoke,
} = require('./state');
const { recordDecision, listDecisions } = require('./gate/decision_log');
const { createBehaviorRegistry } = require('./registry');
const { BEHAVIOR_MODULES } = require('./modules');
const { createServiceLogger } = require('../../utils/logger');
const { isJevEnabled } = require('../ai/jev');
const { ruleDecision } = require('./gate/decisions');

const logger = createServiceLogger('Behavior');

function createBehaviorPipeline(deps = {}) {
  const memoryManager = deps.memoryManager || null;
  const agentEngine = deps.agentEngine || null;
  const io = deps.io || null;
  const registry = createBehaviorRegistry(BEHAVIOR_MODULES);

  function effectiveConfig(userId, agentId, msg) {
    const config = resolveBehaviorConfig(userId, agentId, {
      platform: msg.platform,
      chatId: msg.chatId,
      isGroup: Boolean(msg.isGroup),
    });
    return config;
  }

  function noteInbound({ userId, agentId, msg }) {
    // Snapshot the current epoch without claiming a new speak-turn.
    // Speak turns are claimed only when the gate decides to engage, so
    // silent room traffic cannot invalidate an in-flight reply.
    const state = getThreadState(userId, agentId, msg.platform, msg.chatId);
    msg.behaviorTurnEpoch = state.turnEpoch;
    return state.turnEpoch;
  }

  function claimSpeakTurn({ userId, agentId, msg }) {
    const state = bumpTurnEpoch(userId, agentId, msg.platform, msg.chatId);
    msg.behaviorTurnEpoch = state.turnEpoch;
    return state.turnEpoch;
  }

  function scheduleBackground(baseCtx) {
    const task = async (backgroundSignal) => {
      const ctx = { ...baseCtx, signal: backgroundSignal };
      await registry.run('afterTurn', ctx);
    };
    const key = [
      'social-background',
      baseCtx.userId,
      baseCtx.agentId || 'main',
      baseCtx.msg.platform,
      baseCtx.msg.chatId,
    ].join(':');
    const promise = agentEngine?.trackBackgroundTask
      ? agentEngine.trackBackgroundTask(task, { key, coalesce: true, signal: baseCtx.signal })
      : Promise.resolve().then(() => task(baseCtx.signal));
    promise.catch((error) => {
      if (!baseCtx.signal?.aborted) logger.warn('background analysis failed:', error?.message || error);
    });
  }

  function emitDecision(userId, agentId, msg, decision) {
    if (!io || !userId) return;
    io.to(`user:${userId}`).emit('behavior:decision', {
      platform: msg.platform,
      chatId: msg.chatId,
      agentId,
      isGroup: Boolean(msg.isGroup),
      decision: decision.decision,
      confidence: decision.confidence,
      needScore: decision.needScore,
      reasonCodes: decision.reasonCodes || [],
      urgency: decision.urgency,
      tokenPath: decision.tokenPath || 'gate_only',
      turnEpoch: decision.turnEpoch,
      model: decision.model || null,
      at: new Date().toISOString(),
    });
  }

  async function decideInbound({ userId, agentId, msg, signal = null }) {
    const config = effectiveConfig(userId, agentId, msg);
    const turnEpoch = Number(msg.behaviorTurnEpoch)
      || noteInbound({ userId, agentId, msg });
    const skipped = (engage, decision) => ({
      engage,
      decision: { ...decision, latencyMs: 0 },
      config,
      promptBlocks: [],
      observeResult: null,
    });

    if (
      msg.isGroup
      && msg.accessPolicyAllowUntagged === false
      && !msg.wasMentioned
      && !msg.repliedToAgent
    ) {
      return skipped(false, {
        ...ruleDecision('stay_silent', 'untagged_disabled_for_shared_space'),
        turnEpoch,
      });
    }
    if (config.enabled === false) {
      return skipped(true, {
        ...ruleDecision('speak', 'behavior_disabled'),
        turnEpoch: claimSpeakTurn({ userId, agentId, msg }),
      });
    }

    const baseCtx = {
      userId,
      agentId,
      msg,
      config,
      signal,
      memoryManager,
      agentEngine,
      turnEpoch,
      isModuleEnabled: (moduleId) => isModuleEnabled(config, moduleId),
    };

    const observations = await registry.run('observe', baseCtx);
    const observeResult = observations.find((item) => item.moduleId === 'social_memory')?.value || null;
    // With Jev on, no model runs for a group message until Jev says speak.
    const jevEnabled = Boolean(msg.isGroup) && isJevEnabled(userId, agentId);
    if (msg.isGroup && !jevEnabled) scheduleBackground(baseCtx);

    const memoryHints = observeResult?.scopeId ? [`channel:${observeResult.scopeId}`] : [];
    const decision = isModuleEnabled(config, 'turn_taking')
      ? (await registry.run('decide', { ...baseCtx, memoryHints, jevEnabled }))
        .find((item) => item.moduleId === 'turn_taking')?.value
      : {
        ...ruleDecision('speak', 'turn_taking_disabled'),
        latencyMs: 0,
        turnEpoch,
      };
    if (!decision) {
      throw new Error('The turn-taking module did not return a decision.');
    }
    emitDecision(userId, agentId, msg, decision);

    if (decision.decision !== 'speak') {
      return {
        engage: false,
        decision,
        config,
        promptBlocks: [],
        observeResult,
      };
    }

    // Claim the speak turn only after engagement is confirmed.
    const speakTurnEpoch = claimSpeakTurn({ userId, agentId, msg });
    decision.turnEpoch = speakTurnEpoch;
    if (jevEnabled) scheduleBackground(baseCtx);

    const promptBlocks = await registry.composeContext({
      ...baseCtx,
      turnEpoch: speakTurnEpoch,
    });

    return {
      engage: true,
      decision,
      config,
      promptBlocks,
      observeResult,
    };
  }

  async function handleInbound(input) {
    const result = await decideInbound(input);
    if (input.msg.isGroup) recordDecision(input.userId, input.agentId, input.msg, result.decision);
    return result;
  }

  async function refineAndMaybeDeliver({
    userId,
    agentId,
    msg,
    config,
    draft,
    messagingManager,
    runId = null,
    signal = null,
    mediaPath = null,
    deliver = false,
    turnEpoch = null,
  }) {
    const expectedEpoch = Number(turnEpoch || msg.behaviorTurnEpoch || 0);
    if (msg.isGroup && !isTurnCurrent(
      userId,
      agentId,
      msg.platform,
      msg.chatId,
      expectedEpoch,
    )) {
      return {
        action: 'suppress',
        content: '[NO RESPONSE]',
        delivered: false,
        suppressed: true,
        reasonCodes: ['stale_turn'],
      };
    }
    const combinedGroupReview = msg.isGroup
      && isModuleEnabled(config, 'persona')
      && isModuleEnabled(config, 'theory_of_mind');
    const persona = combinedGroupReview
      ? {
        action: 'send',
        content: draft,
        reasonCodes: ['persona_refine_combined_with_tom'],
      }
      : await registry.get('persona').refineDraft({
        userId,
        agentId,
        msg,
        config,
        draft,
        signal,
        agentEngine,
        memoryManager,
        messagingManager,
        runId,
      });
    const tom = await registry.get('theory_of_mind').refineDraft({
      userId,
      agentId,
      msg,
      config,
      draft: persona.content,
      signal,
      agentEngine,
      runId,
    });

    const content = tom.content;
    const reasonCodes = [
      ...(persona.reasonCodes || []),
      ...(tom.reasonCodes || []),
    ];
    if (!deliver || !messagingManager) {
      return {
        ...tom,
        delivered: false,
        content,
        reasonCodes,
        personaAction: persona.action,
      };
    }

    // A reaction lands before any text, the way people tap one and then reply.
    let reacted = false;
    if (persona.reaction && msg.messageId) {
      try {
        await messagingManager.sendReaction(userId, msg.platform, msg.chatId, msg.messageId, persona.reaction, {
          agentId,
          runId,
          signal,
        });
        reacted = true;
      } catch (error) {
        if (signal?.aborted) throw error;
        logger.warn('reaction delivery failed:', error?.message || error);
      }
    }

    if (!content || content.toUpperCase() === '[NO RESPONSE]') {
      return {
        ...tom,
        delivered: false,
        suppressed: true,
        reacted,
        content,
        reasonCodes,
        personaAction: persona.action,
      };
    }

    const deliveryConfig = isModuleEnabled(config, 'delivery')
      ? config
      : { ...config, deliveryStyle: 'single' };
    const delivery = await registry.get('delivery').deliver({
      messagingManager,
      userId,
      agentId,
      platform: msg.platform,
      chatId: msg.chatId,
      content,
      config: deliveryConfig,
      runId,
      signal,
      mediaPath,
      turnEpoch: expectedEpoch,
      beforeBubble: () => !msg.isGroup || isTurnCurrent(
        userId,
        agentId,
        msg.platform,
        msg.chatId,
        expectedEpoch,
      ),
    });

    if (
      (delivery?.success !== false && delivery?.suppressed !== true)
      || Number(delivery?.deliveredBubbles || 0) > 0
    ) {
      markSpoke(userId, agentId, msg.platform, msg.chatId);
    }

    return {
      ...tom,
      delivered: delivery?.success !== false && delivery?.suppressed !== true,
      suppressed: delivery?.suppressed === true,
      reacted,
      delivery,
      content,
      reasonCodes,
      personaAction: persona.action,
    };
  }

  function getDiagnostics(userId, agentId, platform, chatId) {
    const config = resolveBehaviorConfig(userId, agentId, {
      platform,
      chatId,
      isGroup: true,
    });
    const state = getThreadState(userId, agentId, platform, chatId);
    return {
      config,
      state,
      modules: Object.fromEntries(
        Object.keys(config.modules || {}).map((id) => [id, isModuleEnabled(config, id)]),
      ),
    };
  }

  return {
    registry,
    noteInbound,
    handleInbound,
    refineAndMaybeDeliver,
    getDiagnostics,
    listDecisions,
  };
}

module.exports = {
  createBehaviorPipeline,
};
