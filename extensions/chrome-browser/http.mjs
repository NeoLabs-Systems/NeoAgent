export const DEFAULT_EXTENSION_HTTP_TIMEOUT_MS = 10000;
export const DEFAULT_MAX_SERVER_RESPONSE_BYTES = 1024 * 1024;

function abortError(signal, fallback = 'NeoAgent server request was aborted.') {
  if (signal?.reason instanceof Error) return signal.reason;
  const error = new Error(String(signal?.reason || fallback));
  error.name = 'AbortError';
  error.code = 'ABORT_ERR';
  return error;
}

function throwIfAborted(signal) {
  if (signal?.aborted) throw abortError(signal);
}

function responseTooLargeError(maxResponseBytes) {
  const error = new Error(
    `NeoAgent server response exceeded the ${maxResponseBytes}-byte safety limit.`,
  );
  error.code = 'EXTENSION_RESPONSE_TOO_LARGE';
  return error;
}

function waitForAbortable(promise, signal) {
  throwIfAborted(signal);
  if (!signal) return Promise.resolve(promise);
  return new Promise((resolve, reject) => {
    const onAbort = () => reject(abortError(signal));
    signal.addEventListener('abort', onAbort, { once: true });
    Promise.resolve(promise).then(resolve, reject).finally(() => {
      signal.removeEventListener('abort', onAbort);
    });
  });
}

export async function readJsonResponse(response, options = {}) {
  const signal = options.signal || null;
  const maxResponseBytes = Math.max(
    1,
    Number(options.maxResponseBytes) || DEFAULT_MAX_SERVER_RESPONSE_BYTES,
  );
  throwIfAborted(signal);
  const contentLength = Number(response?.headers?.get?.('content-length'));
  if (Number.isFinite(contentLength) && contentLength > maxResponseBytes) {
    await Promise.resolve(response?.body?.cancel?.()).catch(() => {});
    throw responseTooLargeError(maxResponseBytes);
  }

  const reader = response?.body?.getReader?.();
  let text = '';
  if (!reader) {
    text = await waitForAbortable(response.text(), signal);
    if (new TextEncoder().encode(text).byteLength > maxResponseBytes) {
      throw responseTooLargeError(maxResponseBytes);
    }
  } else {
    const decoder = new TextDecoder();
    let totalBytes = 0;
    const cancelReader = () => {
      try {
        Promise.resolve(reader.cancel(signal?.reason)).catch(() => {});
      } catch {}
    };
    signal?.addEventListener('abort', cancelReader, { once: true });
    try {
      while (true) {
        const { done, value } = await waitForAbortable(reader.read(), signal);
        if (done) break;
        const chunk = value instanceof Uint8Array ? value : new Uint8Array(value || []);
        totalBytes += chunk.byteLength;
        if (totalBytes > maxResponseBytes) {
          await Promise.resolve(reader.cancel()).catch(() => {});
          throw responseTooLargeError(maxResponseBytes);
        }
        text += decoder.decode(chunk, { stream: true });
      }
      text += decoder.decode();
    } finally {
      signal?.removeEventListener('abort', cancelReader);
      reader.releaseLock?.();
    }
  }

  if (!text.trim()) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw new Error('NeoAgent server returned invalid JSON.');
  }
}

export async function fetchJsonWithTimeout(url, options = {}, config = {}) {
  const timeoutMs = Math.max(
    1,
    Number(config.timeoutMs) || DEFAULT_EXTENSION_HTTP_TIMEOUT_MS,
  );
  const maxResponseBytes = Math.max(
    1,
    Number(config.maxResponseBytes) || DEFAULT_MAX_SERVER_RESPONSE_BYTES,
  );
  const fetchImpl = typeof config.fetchImpl === 'function' ? config.fetchImpl : fetch;
  const callerSignal = options.signal || null;
  throwIfAborted(callerSignal);

  const controller = new AbortController();
  const onCallerAbort = () => controller.abort(callerSignal.reason);
  callerSignal?.addEventListener('abort', onCallerAbort, { once: true });
  const timer = setTimeout(() => {
    const error = new Error(`NeoAgent server request timed out after ${timeoutMs}ms.`);
    error.code = 'EXTENSION_HTTP_TIMEOUT';
    controller.abort(error);
  }, timeoutMs);
  timer.unref?.();

  const { signal: _signal, ...fetchOptions } = options;
  try {
    const response = await waitForAbortable(
      fetchImpl(url, {
        ...fetchOptions,
        signal: controller.signal,
      }),
      controller.signal,
    );
    const payload = await readJsonResponse(response, {
      signal: controller.signal,
      maxResponseBytes,
    });
    return { response, payload };
  } catch (error) {
    if (callerSignal?.aborted) throw abortError(callerSignal);
    if (controller.signal.aborted) throw abortError(controller.signal);
    throw error;
  } finally {
    clearTimeout(timer);
    callerSignal?.removeEventListener('abort', onCallerAbort);
  }
}
