'use strict';

const { resolveBehaviorConfig, isModuleEnabled } = require('./config');
const { getThreadState, setThreadState } = require('./state');
const turnTaking = require('./modules/turn_taking');
const socialMemory = require('./modules/social_memory');
const norms = require('./modules/norms');
const persona = require('./modules/persona');
const theoryOfMind = require('./modules/theory_of_mind');
const socialSignals = require('./modules/social_signals');
const socialObservability = require('./modules/social_observability');
const { deliverSocialReply } = require('./delivery');

function createBehaviorPipeline(deps = {}) {
  const memoryManager = deps.memoryManager || null;
  const io = deps.io || null;

  async function handleInbound({ userId, agentId, msg, signal = null }) {
    const config = resolveBehaviorConfig(userId, agentId, {
      platform: msg.platform,
      chatId: msg.chatId,
      isGroup: Boolean(msg.isGroup),
    });

    const baseCtx = {
      userId,
      agentId,
      msg,
      config,
      signal,
      memoryManager,
    };

    // Always record a lightweight signal entry when enabled.
    socialSignals.recordSignal({
      ...baseCtx,
      signalType: 'inbound_message',
      details: {
        hasMedia: Boolean(msg.localMediaPath || msg.mediaType),
        wasMentioned: msg.wasMentioned === true,
      },
    });

    // Observe/ingest before the gate so silence still learns the room cheaply.
    const observeResult = await socialMemory.observeInbound(baseCtx);

    // Background norms/observability never block the reply path.
    queueMicrotask(() => {
      norms.maybeRefreshNorms(baseCtx).catch((error) => {
        console.warn('[Behavior] norms refresh failed:', error?.message || error);
      });
      socialObservability.maybeAnalyze(baseCtx).catch((error) => {
        console.warn('[Behavior] observability failed:', error?.message || error);
      });
    });

    const memoryHints = [];
    if (observeResult?.scopeId) memoryHints.push(`channel:${observeResult.scopeId}`);

    const decision = await turnTaking.shouldEngage({
      ...baseCtx,
      memoryHints,
    });

    if (io && userId) {
      io.to(`user:${userId}`).emit('behavior:decision', {
        platform: msg.platform,
        chatId: msg.chatId,
        agentId,
        isGroup: Boolean(msg.isGroup),
        decision: decision.decision,
        confidence: decision.confidence,
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

    const socialHints = await socialMemory.buildSpeakHints(baseCtx);
    const promptBlocks = [
      persona.buildPersonaBlock(baseCtx),
      norms.getNormsPromptBlock(baseCtx),
      socialHints.promptBlock,
    ].filter(Boolean);

    return {
      engage: true,
      decision,
      config,
      promptBlocks,
      socialHints,
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
  }) {
    const tom = await theoryOfMind.refineDraft({
      userId,
      agentId,
      msg,
      config,
      draft,
      signal,
    });

    const content = tom.content;
    if (!deliver || !messagingManager) {
      return { ...tom, delivered: false, content };
    }

    if (!content || content.toUpperCase() === '[NO RESPONSE]') {
      return { ...tom, delivered: false, suppressed: true, content };
    }

    const delivery = await deliverSocialReply({
      messagingManager,
      userId,
      agentId,
      platform: msg.platform,
      chatId: msg.chatId,
      content,
      config,
      runId,
      signal,
      mediaPath,
    });

    setThreadState(userId, agentId, msg.platform, msg.chatId, {
      lastSpokeAt: new Date().toISOString(),
      recentSilenceCount: 0,
    });

    return {
      ...tom,
      delivered: true,
      delivery,
      content,
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
    handleInbound,
    refineAndMaybeDeliver,
    getDiagnostics,
  };
}

module.exports = {
  createBehaviorPipeline,
};
