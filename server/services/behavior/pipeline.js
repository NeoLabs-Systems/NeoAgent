'use strict';

const { resolveBehaviorConfig, isModuleEnabled } = require('./config');
const {
  bumpTurnEpoch,
  getThreadState,
  isTurnCurrent,
  markSpoke,
} = require('./state');
const { createBehaviorRegistry } = require('./registry');
const { BEHAVIOR_MODULES } = require('./modules');
const { createServiceLogger } = require('../../utils/logger');

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

  async function handleInbound({ userId, agentId, msg, signal = null }) {
    const config = effectiveConfig(userId, agentId, msg);
    const turnEpoch = Number(msg.behaviorTurnEpoch)
      || noteInbound({ userId, agentId, msg });
    if (
      msg.isGroup
      && msg.accessPolicyAllowUntagged === false
      && !msg.wasMentioned
      && !msg.repliedToAgent
    ) {
      return {
        engage: false,
        decision: {
          decision: 'stay_silent',
          needScore: 0,
          confidence: 1,
          reasonCodes: ['untagged_disabled_for_shared_space'],
          urgency: 'low',
          rationale: 'Untagged responses are disabled for this shared space.',
          tokenPath: 'gate_skip',
          latencyMs: 0,
          turnEpoch,
        },
        config,
        promptBlocks: [],
        observeResult: null,
      };
    }
    if (config.enabled === false) {
      const speakTurnEpoch = claimSpeakTurn({ userId, agentId, msg });
      return {
        engage: true,
        decision: {
          decision: 'speak',
          needScore: 1,
          confidence: 1,
          reasonCodes: ['behavior_disabled'],
          urgency: 'medium',
          rationale: 'Behavior modules are disabled; using the standard response path.',
          tokenPath: 'gate_skip',
          latencyMs: 0,
          turnEpoch: speakTurnEpoch,
        },
        config,
        promptBlocks: [],
        observeResult: null,
      };
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
    if (msg.isGroup) scheduleBackground(baseCtx);

    const memoryHints = [];
    if (observeResult?.scopeId) memoryHints.push(`channel:${observeResult.scopeId}`);

    let decision;
    if (!isModuleEnabled(config, 'turn_taking')) {
      decision = {
        decision: 'speak',
        needScore: 1,
        confidence: 1,
        reasonCodes: ['turn_taking_disabled'],
        urgency: 'medium',
        rationale: 'Turn-taking is disabled; using the standard response path.',
        tokenPath: 'gate_skip',
        latencyMs: 0,
        turnEpoch,
      };
    } else {
      decision = (await registry.run('decide', {
        ...baseCtx,
        memoryHints,
      })).find((item) => item.moduleId === 'turn_taking')?.value;
    }
    if (!decision) {
      throw new Error('The turn-taking module did not return a decision.');
    }

    if (io && userId) {
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
        rationale: decision.rationale || '',
        tokenPath: decision.tokenPath || 'gate_only',
        turnEpoch: decision.turnEpoch,
        model: decision.model || null,
        at: new Date().toISOString(),
      });
    }

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

    if (!content || content.toUpperCase() === '[NO RESPONSE]') {
      return {
        ...tom,
        delivered: false,
        suppressed: true,
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
  };
}

module.exports = {
  createBehaviorPipeline,
};
