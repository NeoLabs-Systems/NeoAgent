'use strict';

function hasTerminalMessagingDelivery(runMeta = null) {
  return runMeta?.finalDeliverySent === true
    || runMeta?.finalResponseSent === true
    || runMeta?.finalContentDelivered === true
    || runMeta?.deliveryState?.finalResponseSent === true
    || runMeta?.deliveryState?.finalContentDelivered === true
    || runMeta?.noResponse === true;
}

function isRateLimitError(error = null) {
  return /429|rate.?limit|free-models-per/i.test(String(error?.message || ''));
}

function shouldRetryMessagingRun({
  triggerSource,
  options = {},
  runMeta = null,
  error = null,
  retryCount = 0,
  retryLimit = 0,
} = {}) {
  return triggerSource === 'messaging'
    && Boolean(options.source)
    && Boolean(options.chatId)
    && !hasTerminalMessagingDelivery(runMeta)
    && error?.disableAutonomousRetry !== true
    && !isRateLimitError(error)
    && Number(retryCount || 0) < Number(retryLimit || 0);
}

function shouldSendMessagingErrorFallback({
  triggerSource,
  options = {},
  runMeta = null,
} = {}) {
  return triggerSource === 'messaging'
    && Boolean(options.source)
    && Boolean(options.chatId)
    && !hasTerminalMessagingDelivery(runMeta);
}

module.exports = {
  hasTerminalMessagingDelivery,
  isRateLimitError,
  shouldRetryMessagingRun,
  shouldSendMessagingErrorFallback,
};
