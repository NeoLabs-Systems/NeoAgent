'use strict';

const MODEL_CALL_TIMEOUT_MS = 5 * 60 * 1000;

function formatElapsedDuration(durationMs) {
  const totalSeconds = Math.max(1, Math.floor(Number(durationMs || 0) / 1000));
  if (totalSeconds < 60) return `${totalSeconds}s`;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  if (seconds === 0) return `${minutes}m`;
  return `${minutes}m ${seconds}s`;
}

function resolveModelCallTimeoutMs(options = {}) {
  const requested = Number(options?.modelCallTimeoutMs);
  if (Number.isFinite(requested) && requested > 0) {
    return Math.max(10, requested);
  }
  return MODEL_CALL_TIMEOUT_MS;
}

function abortError(reason = null) {
  if (reason instanceof Error) return reason;
  const error = new Error(String(reason || 'Model call aborted.'));
  error.name = 'AbortError';
  error.code = 'ABORT_ERR';
  return error;
}

async function withModelCallTimeout(promise, options = {}, label = 'Model call') {
  const timeoutMs = resolveModelCallTimeoutMs(options);
  const signal = options?.modelAbortController?.signal || options?.signal || null;
  let timer = null;
  let abortListener = null;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => {
      const error = new Error(`${label} timed out after ${formatElapsedDuration(timeoutMs)}.`);
      error.code = 'MODEL_CALL_TIMEOUT';
      options?.modelAbortController?.abort(error);
      reject(error);
    }, timeoutMs);
  });
  const aborted = new Promise((_, reject) => {
    if (!signal) return;
    abortListener = () => reject(abortError(signal.reason));
    if (signal.aborted) abortListener();
    else signal.addEventListener('abort', abortListener, { once: true });
  });

  try {
    return await Promise.race([Promise.resolve(promise), timeout, aborted]);
  } finally {
    if (timer) clearTimeout(timer);
    if (abortListener) signal?.removeEventListener('abort', abortListener);
  }
}

async function runAbortableModelCall(factory, options = {}, label = 'Model call') {
  const modelAbortController = new AbortController();
  const parentSignals = [...new Set([
    options?.signal,
    ...(Array.isArray(options?.signals) ? options.signals : []),
  ].filter((signal) => signal && typeof signal.addEventListener === 'function'))];
  const parentListeners = new Map();
  for (const parentSignal of parentSignals) {
    const abortFromParent = () => modelAbortController.abort(parentSignal.reason);
    parentListeners.set(parentSignal, abortFromParent);
    if (parentSignal.aborted) abortFromParent();
    else parentSignal.addEventListener('abort', abortFromParent, { once: true });
  }

  try {
    const promise = Promise.resolve().then(() => factory(modelAbortController.signal));
    return await withModelCallTimeout(
      promise,
      { ...options, modelAbortController },
      label,
    );
  } finally {
    for (const [parentSignal, abortFromParent] of parentListeners) {
      parentSignal.removeEventListener('abort', abortFromParent);
    }
  }
}

module.exports = {
  abortError,
  resolveModelCallTimeoutMs,
  runAbortableModelCall,
  withModelCallTimeout,
};
