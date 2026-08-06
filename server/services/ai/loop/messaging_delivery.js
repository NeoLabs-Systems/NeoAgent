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

const SAFE_PRE_DELIVERY_NETWORK_CODES = new Set([
  'EAI_AGAIN',
  'ENOTFOUND',
  'ECONNREFUSED',
  'ENETUNREACH',
  'EHOSTUNREACH',
  'UND_ERR_CONNECT_TIMEOUT',
]);

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

module.exports = {
  deliverMessagingFinalFallback,
  requireSuccessfulMessagingDelivery,
  shouldSendMessagingFinalFallback,
};
