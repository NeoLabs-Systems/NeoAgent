'use strict';

const {
  splitOutgoingMessageForPlatform,
  normalizeOutgoingMessageForPlatform,
} = require('../messaging/formatting_guides');

function sleep(ms, signal = null) {
  const delay = Math.max(0, Number(ms) || 0);
  if (!delay) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      resolve();
    }, delay);
    const onAbort = () => {
      cleanup();
      const error = new Error('Delivery aborted.');
      error.name = 'AbortError';
      reject(error);
    };
    const cleanup = () => {
      clearTimeout(timer);
      if (signal) signal.removeEventListener('abort', onAbort);
    };
    if (signal) {
      if (signal.aborted) {
        cleanup();
        const error = new Error('Delivery aborted.');
        error.name = 'AbortError';
        reject(error);
        return;
      }
      signal.addEventListener('abort', onAbort, { once: true });
    }
  });
}

function splitIntoNaturalBubbles(platform, content, { maxBubbles = 4 } = {}) {
  const normalized = normalizeOutgoingMessageForPlatform(platform, content, {
    stripNoResponseMarker: false,
  });
  if (!normalized) return [];
  if (normalized.toUpperCase() === '[NO RESPONSE]') return [normalized];

  const paragraphChunks = splitOutgoingMessageForPlatform(platform, normalized);
  const bubbles = [];
  for (const chunk of paragraphChunks) {
    const sentences = String(chunk)
      .split(/(?<=[.!?])\s+(?=[^\s])/)
      .map((part) => part.trim())
      .filter(Boolean);
    if (sentences.length <= 1) {
      bubbles.push(chunk);
      continue;
    }
    for (const sentence of sentences) bubbles.push(sentence);
  }

  const limited = [];
  for (const bubble of bubbles) {
    if (!bubble) continue;
    if (limited.length < maxBubbles) {
      limited.push(bubble);
    } else {
      limited[limited.length - 1] = `${limited[limited.length - 1]} ${bubble}`.trim();
    }
  }
  return limited.length ? limited : [normalized];
}

async function deliverSocialReply({
  messagingManager,
  userId,
  agentId,
  platform,
  chatId,
  content,
  config,
  runId = null,
  signal = null,
  mediaPath = null,
}) {
  const style = config?.deliveryStyle === 'single' ? 'single' : 'natural_bubbles';
  if (style === 'single' || mediaPath) {
    return messagingManager.sendMessage(userId, platform, chatId, content, {
      agentId,
      runId,
      mediaPath,
      signal,
      deliveryKind: 'final',
    });
  }

  const bubbles = splitIntoNaturalBubbles(platform, content, {
    maxBubbles: config?.maxBubbles || 4,
  });
  if (bubbles.length <= 1) {
    return messagingManager.sendMessage(userId, platform, chatId, bubbles[0] || content, {
      agentId,
      runId,
      signal,
      deliveryKind: 'final',
    });
  }

  let lastResult = null;
  for (let index = 0; index < bubbles.length; index += 1) {
    if (signal?.aborted) {
      const error = new Error('Delivery aborted.');
      error.name = 'AbortError';
      throw error;
    }
    try {
      await messagingManager.sendTyping?.(userId, platform, chatId, true, { agentId, runId, signal });
    } catch {
      // typing is best-effort
    }
    if (index > 0) {
      await sleep(config?.bubbleGapMs || 650, signal);
    }
    lastResult = await messagingManager.sendMessage(userId, platform, chatId, bubbles[index], {
      agentId,
      runId,
      signal,
      deliveryKind: index === bubbles.length - 1 ? 'final' : 'partial',
      metadata: {
        socialDelivery: true,
        bubbleIndex: index,
        bubbleCount: bubbles.length,
      },
    });
  }
  try {
    await messagingManager.sendTyping?.(userId, platform, chatId, false, { agentId, runId, signal });
  } catch {
    // ignore
  }
  return {
    success: true,
    bubbled: true,
    bubbleCount: bubbles.length,
    result: lastResult,
  };
}

module.exports = {
  splitIntoNaturalBubbles,
  deliverSocialReply,
};
