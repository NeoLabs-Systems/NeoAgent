'use strict';

const { getErrorMessage } = require('../bootstrap_helpers');

async function processInboundQueue({
  userQueues,
  userId,
  msg,
  executeMessage,
  onProcessingError = null
}) {
  const agentId = msg.agentId || null;
  const queueKey = `${userId}:${agentId || 'main'}`;
  if (!userQueues[queueKey]) {
    userQueues[queueKey] = { running: false, pending: [], cancelRequested: false };
  }
  const queue = userQueues[queueKey];

  if (queue.cancelRequested && !queue.running) {
    queue.pending = [];
    queue.cancelRequested = false;
  }

  if (queue.running) {
    const last = queue.pending[queue.pending.length - 1];
    if (
      last
      && last.platform === msg.platform
      && last.chatId === msg.chatId
      && String(last.sender || '') === String(msg.sender || '')
    ) {
      last.content += `\n${msg.content}`;
      last.messageId = msg.messageId;
    } else {
      queue.pending.push({ ...msg });
    }
    return { queued: true };
  }

  queue.running = true;
  let currentMessage = msg;
  let processedCount = 0;
  let failedCount = 0;
  let cancelled = false;

  try {
    while (currentMessage) {
      let outcome;
      try {
        outcome = await executeMessage(currentMessage);
      } catch (error) {
        outcome = { runId: null, result: null, error };
      }
      processedCount += 1;

      if (outcome?.error) {
        failedCount += 1;
        await notifyProcessingError(onProcessingError, {
          error: outcome.error,
          runId: outcome.runId,
          userId,
          failedMessage: currentMessage
        });
      }

      if (queue.cancelRequested) {
        queue.pending = [];
        cancelled = true;
        break;
      }

      currentMessage = queue.pending.shift() || null;
    }
  } finally {
    queue.running = false;
    queue.pending = [];
    queue.cancelRequested = false;
    if (userQueues[queueKey] === queue) {
      delete userQueues[queueKey];
    }
  }

  return {
    processedCount,
    failedCount,
    cancelled
  };
}

async function notifyProcessingError(handler, details) {
  if (typeof handler !== 'function') {
    console.error(
      `[MessagingAutomation] Agent run failed platform=${details.failedMessage.platform} user=${details.userId}:`,
      getErrorMessage(details.error)
    );
    return;
  }

  try {
    await handler(details);
  } catch (error) {
    console.error(
      '[MessagingAutomation] Failed to report an agent run error:',
      getErrorMessage(error)
    );
  }
}

module.exports = {
  processInboundQueue
};
