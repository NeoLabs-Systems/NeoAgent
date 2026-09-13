'use strict';

function hasTerminalMessagingDelivery(runMeta = null) {
  return runMeta?.finalDeliverySent === true
    || runMeta?.finalResponseSent === true
    || runMeta?.finalContentDelivered === true
    || runMeta?.deliveryState?.finalResponseSent === true
    || runMeta?.deliveryState?.finalContentDelivered === true
    || runMeta?.noResponse === true;
}

function shouldRetryMessagingRun() {
  // Messaging recovery must stay inside the current run. Re-entering
  // runWithModel starts over from the original task and repeats tool work.
  return false;
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
  shouldRetryMessagingRun,
  shouldSendMessagingErrorFallback,
};
