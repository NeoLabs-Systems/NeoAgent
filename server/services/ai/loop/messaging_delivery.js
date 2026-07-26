'use strict';

const {
  splitOutgoingMessageForPlatform,
} = require('../../messaging/formatting_guides');
const {
  normalizeOutgoingMessage,
} = require('../messagingFallback');
const { withProviderRetry } = require('../providerRetry');
const {
  abortableDelay,
  getErrorCode,
  getHttpStatus,
} = require('../../../utils/retry');
const { shortenRunId, summarizeForLog } = require('../logFormat');
const {
  TICK_MS,
  REPEAT_UPDATE_MS,
  buildInitialProgressLedger,
  buildProgressNudge,
  evaluateProgressLiveness,
} = require('./progress_monitor');

const SAFE_PRE_DELIVERY_NETWORK_CODES = new Set([
  'EAI_AGAIN',
  'ENOTFOUND',
  'ECONNREFUSED',
  'ENETUNREACH',
  'EHOSTUNREACH',
  'UND_ERR_CONNECT_TIMEOUT',
]);

function isoNow() {
  return new Date().toISOString();
}

function timestampMs(value, fallback = 0) {
  const resolved = value ? Date.parse(value) : NaN;
  return Number.isFinite(resolved) ? resolved : fallback;
}

function requireSuccessfulMessagingDelivery(result, label = 'Messaging delivery') {
  if (result?.success === true && result?.suppressed !== true) {
    return result;
  }
  const reason = String(
    result?.error
    || result?.reason
    || result?.result?.error
    || result?.result?.reason
    || 'the platform did not confirm delivery',
  ).trim();
  const error = new Error(`${label} failed: ${reason}`);
  error.code = 'MESSAGING_DELIVERY_FAILED';
  error.deliveryResult = result || null;
  error.safeToRetry = result?.safeToRetry === true;
  error.deliveryAmbiguous = result?.deliveryAmbiguous === true;
  throw error;
}

function isSafeMessagingDeliveryRetry(error) {
  if (!error || error.retryable === false || error.deliveryAmbiguous === true) return false;
  if (error.safeToRetry === true) return true;
  const result = error.deliveryResult;
  if (result?.deliveryAmbiguous === true || result?.retryable === false) return false;
  if (result?.success === false) return true;

  // A rate-limit response explicitly rejected the request. DNS/connect failures
  // happen before a platform can accept it. Timeouts, resets, broken pipes, and
  // generic 5xx responses are intentionally excluded because the message may
  // already have been accepted and retrying would duplicate it.
  if (getHttpStatus(error) === 429) return true;
  return SAFE_PRE_DELIVERY_NETWORK_CODES.has(String(getErrorCode(error) || ''));
}

// Harness-driven progress: the originating chat must see autonomous updates during
// long runs even when a weak model never calls send_interim_update itself. The
// supervisor paces this call (FIRST/REPEAT thresholds + a repeat guard). The update
// text is always authored by the run's own agent loop (composeProgressUpdate); we
// never emit a hard-coded status line. If the loop can't compose one this tick, we
// skip the visible send and only nudge the model, then try again next tick.
async function sendRuntimeMessagingHeartbeat(engine, runId, options = {}) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta || runMeta.aborted) return { sent: false, skipped: true };
  if (runMeta.triggerSource !== 'messaging') {
    return { sent: false, skipped: true };
  }
  if (runMeta.messagingContext?.behavior?.isGroup === true) {
    return { sent: false, skipped: true, reason: 'group_progress_suppressed' };
  }
  const createdAt = isoNow();
  const heartbeatCount = Number(runMeta.progressLedger?.heartbeatCount || 0) + 1;
  runMeta.lastSupervisorNudgeAt = createdAt;
  engine.updateRunProgress(runId, { heartbeatCount });

  const ledger = runMeta.progressLedger || {};
  const { platform, chatId } = runMeta.messagingContext || {};

  if (engine.messagingManager && !runMeta.terminalInterim && platform && chatId
    && typeof runMeta.composeProgressUpdate === 'function') {
    let statusMsg = '';
    try {
      const composed = await runMeta.composeProgressUpdate({
        stalled: options.stalled === true,
        signal: runMeta.messagingProgressSupervisor?.abortController?.signal || null,
      });
      if (normalizeOutgoingMessage(composed, platform)) statusMsg = String(composed).trim();
    } catch { /* no dynamic update available this tick */ }
    const currentRunMeta = engine.getRunMeta(runId);
    if (
      currentRunMeta !== runMeta
      || runMeta.aborted
      || runMeta.status !== 'running'
      || runMeta.terminalInterim
      || runMeta.finalDeliverySent
      || runMeta.deliveryState?.finalContentDelivered === true
    ) {
      return { sent: false, skipped: true, terminal: true };
    }
    if (statusMsg) try {
      const delivery = await engine.messagingManager.sendMessage(runMeta.userId, platform, chatId, statusMsg, {
        runId,
        agentId: runMeta.agentId,
        signal: runMeta.messagingProgressSupervisor?.abortController?.signal
          || runMeta.abortController?.signal
          || null,
      });
      if (delivery?.success === true && delivery?.suppressed !== true) {
        const nowIso = isoNow();
        runMeta.progressLedger = { ...ledger, lastUserVisibleUpdateAt: nowIso };
        runMeta.lastInterimMessage = statusMsg;
        engine.updateRunProgress(runId, { lastUserVisibleUpdateAt: nowIso });
        engine.recordRunEvent(runMeta.userId, runId, 'progress_heartbeat_sent', {
          stalled: options.stalled === true,
          currentTool: ledger.currentTool || null,
          currentStep: ledger.currentStep || null,
          phase: ledger.currentPhase || 'idle',
          userVisible: true,
          createdAt,
        }, { agentId: runMeta.agentId });
        // Still nudge the model so its next turn can deliver a richer, real update.
        engine.enqueueSystemSteering(
          runId,
          buildProgressNudge({ stalled: options.stalled === true }),
          { reason: options.stalled === true ? 'stalled_progress_check' : 'progress_check' },
        );
        return { sent: true, heartbeat: true };
      }
    } catch (err) {
      console.warn('[Engine] Progress heartbeat send failed:', err?.message || err);
    }
  }

  engine.recordRunEvent(runMeta.userId, runId, 'progress_heartbeat_sent', {
    stalled: options.stalled === true,
    currentTool: ledger.currentTool || null,
    currentStep: ledger.currentStep || null,
    phase: ledger.currentPhase || 'idle',
    userVisible: false,
    createdAt,
  }, { agentId: runMeta.agentId });
  engine.enqueueSystemSteering(
    runId,
    buildProgressNudge({ stalled: options.stalled === true }),
    { reason: options.stalled === true ? 'stalled_progress_check' : 'progress_check' },
  );
  return { sent: false, heartbeat: true, queued: true };
}

function shouldSendMessagingFinalFallback(_engine, runMeta, content, platform = null) {
  const cleanedContent = normalizeOutgoingMessage(content || '', platform, {
    collapseWhitespace: false,
  });
  const lastFinalDeliveryMessage = normalizeOutgoingMessage(
    runMeta?.lastSentMessage
    || (Array.isArray(runMeta?.sentMessages) ? runMeta.sentMessages[runMeta.sentMessages.length - 1] : '')
    || '',
    platform,
  );
  return Boolean(
    cleanedContent
    && !runMeta?.terminalInterim
    && runMeta?.noResponse !== true
    && runMeta?.explicitMessageSent !== true
    && runMeta?.finalDeliverySent !== true
    && runMeta?.deliveryState?.finalContentDelivered !== true
    && !lastFinalDeliveryMessage
  );
}

async function deliverMessagingFinalFallback(engine, {
  runId,
  userId,
  agentId,
  platform,
  chatId,
  content,
}) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta || !engine.messagingManager) return { sent: false, skipped: true };
  const cleanedContent = normalizeOutgoingMessage(content || '', platform, {
    collapseWhitespace: false,
  });
  if (!shouldSendMessagingFinalFallback(engine, runMeta, cleanedContent, platform)) {
    return { sent: false, skipped: true };
  }

  const behavior = runMeta.messagingContext?.behavior;
  const behaviorPipeline = engine.app?.locals?.behaviorPipeline;
  if (
    behavior
    && behavior.enabled !== false
    && behaviorPipeline
    && typeof behaviorPipeline.refineAndMaybeDeliver === 'function'
  ) {
    const result = await behaviorPipeline.refineAndMaybeDeliver({
      userId,
      agentId,
      msg: behavior.message,
      config: behavior.config,
      draft: cleanedContent,
      messagingManager: engine.messagingManager,
      runId,
      signal: runMeta.abortController?.signal || null,
      turnEpoch: behavior.turnEpoch,
      deliver: true,
    });
    if (!result.delivered) {
      if (result.suppressed !== true) {
        const error = new Error(
          result.delivery?.error || result.delivery?.reason || 'Behavior delivery was not confirmed.',
        );
        error.code = 'MESSAGING_DELIVERY_FAILED';
        throw error;
      }
      runMeta.noResponse = true;
      if (runMeta.deliveryState) runMeta.deliveryState.noResponse = true;
      return {
        sent: false,
        suppressed: result.suppressed === true,
        reason: result.reasonCodes?.[0] || 'behavior_suppressed',
      };
    }
    runMeta.lastSentMessage = result.content;
    if (!Array.isArray(runMeta.sentMessages)) runMeta.sentMessages = [];
    runMeta.sentMessages.push(result.content);
    engine.markRunFinalDelivery(runId, result.content);
    return { sent: true, behavior: true, content: result.content };
  }

  const chunks = splitOutgoingMessageForPlatform(platform, cleanedContent);
  console.info(
    `[Run ${shortenRunId(runId)}] messaging_fallback chunks=${chunks.length} to=${summarizeForLog(chatId, 80)}`
  );
  const deliveredChunks = [];
  for (let i = 0; i < chunks.length; i++) {
    if (i > 0) {
      const delay = Math.max(1000, Math.min(chunks[i].length * 30, 4000));
      await engine.messagingManager.sendTyping(userId, platform, chatId, true, { agentId }).catch(() => {});
      await abortableDelay(delay, runMeta.abortController?.signal || null);
    }
    try {
      await withProviderRetry(async () => {
        const deliveryResult = await engine.messagingManager.sendMessage(
          userId,
          platform,
          chatId,
          chunks[i],
          {
            runId,
            agentId,
            idempotencyKey: `${runId}:final:${i}`,
            signal: runMeta.abortController?.signal || null,
          },
        );
        return requireSuccessfulMessagingDelivery(deliveryResult, 'Final messaging delivery');
      }, {
        ...engine.messagingDeliveryRetry,
        label: `MessagingDelivery ${platform}`,
        signal: runMeta.abortController?.signal || null,
        isRetryable: isSafeMessagingDeliveryRetry,
      });
    } catch (error) {
      error.disableAutonomousRetry = true;
      error.deliveredChunks = deliveredChunks.slice();
      throw error;
    }
    deliveredChunks.push(chunks[i]);
    runMeta.lastSentMessage = chunks[i];
    if (!Array.isArray(runMeta.sentMessages)) runMeta.sentMessages = [];
    runMeta.sentMessages.push(chunks[i]);
  }

  runMeta.lastSentMessage = deliveredChunks[deliveredChunks.length - 1] || cleanedContent;
  engine.markRunFinalDelivery(runId, runMeta.lastSentMessage);
  return { sent: true, chunks: deliveredChunks };
}

async function tickMessagingProgressSupervisor(engine, runId) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta || runMeta.aborted || runMeta.triggerSource !== 'messaging') {
    return { sent: false, skipped: true };
  }
  if (runMeta.terminalInterim) {
    return { sent: false, skipped: true };
  }
  if (runMeta.progressSupervisorTickInFlight === true) {
    return { sent: false, skipped: true, inFlight: true };
  }
  runMeta.progressSupervisorTickInFlight = true;
  let settleTick;
  const tickPromise = new Promise((resolve) => { settleTick = resolve; });
  runMeta.progressSupervisorTickPromise = tickPromise;

  try {
    const ledger = runMeta.progressLedger || buildInitialProgressLedger({
      startedAt: runMeta.startedAtIso || isoNow(),
    });
    runMeta.progressLedger = ledger;
    const liveness = evaluateProgressLiveness(runMeta);
    const stalled = liveness.stalled;

    if (stalled && !ledger.stallNotifiedAt) {
      engine.updateRunProgress(runId, {
        stallNotifiedAt: isoNow(),
        progressState: 'stalled',
      });
      engine.recordRunEvent(runMeta.userId, runId, 'progress_stalled', {
        currentTool: ledger.currentTool || null,
        currentStep: ledger.currentStep || null,
        phase: ledger.currentPhase || 'idle',
      }, { agentId: runMeta.agentId });
    }

    if (!liveness.shouldNudge) {
      return { sent: false, skipped: true };
    }

    const lastSupervisorNudgeAtMs = timestampMs(runMeta.lastSupervisorNudgeAt, 0);
    if (lastSupervisorNudgeAtMs > 0 && (Date.now() - lastSupervisorNudgeAtMs) < REPEAT_UPDATE_MS) {
      return { sent: false, skipped: true };
    }

    if (ledger.currentPhase === 'tool' || ledger.currentPhase === 'model') {
      return await sendRuntimeMessagingHeartbeat(engine, runId, { stalled });
    }

    if (ledger.currentPhase !== 'idle') {
      return { sent: false, skipped: true };
    }

    const queued = engine.enqueueSystemSteering(runId, buildProgressNudge({ stalled }), {
      reason: stalled ? 'stalled_progress_check' : 'progress_check',
    });
    if (!queued) {
      return { sent: false, skipped: true };
    }
    runMeta.lastSupervisorNudgeAt = isoNow();
    engine.updateRunProgress(runId, {
      lastUserVisibleUpdateAt: ledger.lastUserVisibleUpdateAt || null,
    });
    return { sent: false, queued: true };
  } finally {
    settleTick();
    if (engine.getRunMeta(runId) === runMeta) {
      runMeta.progressSupervisorTickInFlight = false;
      if (runMeta.progressSupervisorTickPromise === tickPromise) {
        runMeta.progressSupervisorTickPromise = null;
      }
    }
  }
}

function startMessagingProgressSupervisor(engine, runId) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta || runMeta.triggerSource !== 'messaging' || !runMeta.messagingContext?.platform || !runMeta.messagingContext?.chatId) {
    return false;
  }
  if (runMeta.messagingProgressSupervisor?.timer) {
    return true;
  }
  const abortController = new AbortController();
  const timer = setInterval(() => {
    tickMessagingProgressSupervisor(engine, runId).catch((error) => {
      console.warn('[Engine] Messaging progress supervisor failed:', error?.message || error);
    });
  }, TICK_MS);
  timer.unref?.();
  runMeta.messagingProgressSupervisor = { timer, abortController };
  return true;
}

function stopMessagingProgressSupervisor(engine, runId) {
  const runMeta = engine.getRunMeta(runId);
  const inFlight = runMeta?.progressSupervisorTickPromise || null;
  const timer = runMeta?.messagingProgressSupervisor?.timer || null;
  if (timer) {
    clearInterval(timer);
  }
  runMeta?.messagingProgressSupervisor?.abortController?.abort('Progress supervisor stopped.');
  if (runMeta?.messagingProgressSupervisor) {
    runMeta.messagingProgressSupervisor = null;
  }
  return inFlight || Promise.resolve();
}

module.exports = {
  deliverMessagingFinalFallback,
  requireSuccessfulMessagingDelivery,
  sendRuntimeMessagingHeartbeat,
  shouldSendMessagingFinalFallback,
  startMessagingProgressSupervisor,
  stopMessagingProgressSupervisor,
  tickMessagingProgressSupervisor,
};
