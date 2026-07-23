'use strict';

function createAbortError(signalOrReason = null, fallback = 'Operation aborted.') {
  const reason = signalOrReason && typeof signalOrReason === 'object'
    && 'aborted' in signalOrReason
    ? signalOrReason.reason
    : signalOrReason;
  if (reason instanceof Error) return reason;
  const error = new Error(
    String(reason || fallback),
  );
  error.name = 'AbortError';
  error.code = 'ABORT_ERR';
  return error;
}

function isAbortError(error, signal = null) {
  return signal?.aborted === true
    || error?.name === 'AbortError'
    || error?.code === 'ABORT_ERR';
}

function throwIfAborted(signal, fallback = 'Operation aborted.') {
  if (signal?.aborted) throw createAbortError(signal, fallback);
}

function createLinkedAbortController(signals = []) {
  const controller = new AbortController();
  const listeners = new Map();
  for (const signal of new Set(signals.filter(Boolean))) {
    if (typeof signal.addEventListener !== 'function') continue;
    const forwardAbort = () => {
      if (!controller.signal.aborted) controller.abort(signal.reason);
    };
    listeners.set(signal, forwardAbort);
    if (signal.aborted) {
      forwardAbort();
      break;
    }
    signal.addEventListener('abort', forwardAbort, { once: true });
  }
  return {
    controller,
    signal: controller.signal,
    cleanup() {
      for (const [signal, forwardAbort] of listeners) {
        signal.removeEventListener('abort', forwardAbort);
      }
      listeners.clear();
    },
  };
}

async function runWithAbortTimeout(factory, options = {}) {
  const timeoutMs = Number(options.timeoutMs);
  const timeoutController = new AbortController();
  const linked = createLinkedAbortController([
    options.signal,
    timeoutController.signal,
  ]);
  throwIfAborted(linked.signal, `${options.label || 'Operation'} aborted.`);
  let timer = null;
  let abortListener = null;
  if (Number.isFinite(timeoutMs) && timeoutMs > 0) {
    timer = setTimeout(() => {
      const error = new Error(
        `${options.label || 'Operation'} timed out after ${Math.floor(timeoutMs)}ms.`,
      );
      error.code = options.timeoutCode || 'OPERATION_TIMEOUT';
      timeoutController.abort(error);
    }, timeoutMs);
  }
  const aborted = new Promise((_, reject) => {
    abortListener = () => reject(createAbortError(linked.signal));
    linked.signal.addEventListener('abort', abortListener, { once: true });
  });

  try {
    return await Promise.race([
      Promise.resolve().then(() => factory(linked.signal)),
      aborted,
    ]);
  } finally {
    if (timer) clearTimeout(timer);
    if (abortListener) linked.signal.removeEventListener('abort', abortListener);
    linked.cleanup();
  }
}

module.exports = {
  createAbortError,
  createLinkedAbortController,
  isAbortError,
  runWithAbortTimeout,
  throwIfAborted,
};
