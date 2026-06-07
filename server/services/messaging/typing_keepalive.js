'use strict';

const { getErrorMessage } = require('../bootstrap_helpers');

function startTypingKeepalive({
  messagingManager,
  userId,
  agentId,
  runId,
  platform,
  chatId,
  intervalMs = 4000,
  onError = null
}) {
  let stopped = false;
  let timer = null;
  let releaseWait = null;
  let stopPromise = null;
  const reportedFailures = new Set();

  const reportFailure = (operation, error) => {
    if (reportedFailures.has(operation)) return;
    reportedFailures.add(operation);
    if (typeof onError === 'function') {
      try {
        onError(operation, error);
      } catch (reportError) {
        console.error(
          '[MessagingAutomation] Typing failure reporter failed:',
          getErrorMessage(reportError)
        );
      }
    }
  };

  const matchesRunDelivery = (event) => (
    event?.runId
    && runId
    && event.runId === runId
    && event.userId === userId
    && event.platform === platform
    && event.to === chatId
  );

  const onMessageSent = (event) => {
    if (matchesRunDelivery(event) && event.deliveryKind !== 'interim') {
      stop().catch((error) => reportFailure('stop typing keepalive', error));
    }
  };

  if (typeof messagingManager?.on === 'function' && typeof messagingManager?.off === 'function') {
    messagingManager.on('message_sent', onMessageSent);
  }

  const wait = () =>
    new Promise((resolve) => {
      releaseWait = resolve;
      timer = setTimeout(resolve, intervalMs);
    });

  const sendTyping = async (isTyping, operation) => {
    try {
      await messagingManager.sendTyping(
        userId,
        platform,
        chatId,
        isTyping,
        { agentId }
      );
    } catch (error) {
      reportFailure(operation, error);
    }
  };

  const loop = (async () => {
    while (!stopped) {
      await sendTyping(true, 'send typing indicator');

      if (stopped) break;
      await wait();
    }
  })();

  const stop = async () => {
    if (stopPromise) return stopPromise;
    stopPromise = (async () => {
      if (typeof messagingManager?.off === 'function') {
        messagingManager.off('message_sent', onMessageSent);
      }
      stopped = true;
      if (timer) {
        clearTimeout(timer);
        timer = null;
      }
      if (releaseWait) {
        releaseWait();
        releaseWait = null;
      }
      await loop.catch((error) => reportFailure('typing keepalive loop', error));
      await sendTyping(false, 'clear typing indicator');
    })();
    return stopPromise;
  };

  return stop;
}

module.exports = {
  startTypingKeepalive
};
