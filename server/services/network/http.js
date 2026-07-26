'use strict';

const { createAbortError } = require('../../utils/abort');

const DEFAULT_HTTP_TIMEOUT_MS = 15000;
const DEFAULT_MAX_RESPONSE_BYTES = 10 * 1024 * 1024;

function timeoutError(serviceName, timeoutMs, code = 'HTTP_TIMEOUT') {
  const error = new Error(`${serviceName} request timed out after ${timeoutMs}ms.`);
  error.code = code;
  return error;
}

function responseTooLargeError(serviceName, maxBytes, code = 'HTTP_RESPONSE_TOO_LARGE') {
  const error = new Error(
    `${serviceName} response exceeded the ${maxBytes}-byte safety limit.`,
  );
  error.code = code;
  return error;
}

function waitForAbortableResult(promise, signal, fallback = 'Request aborted.') {
  if (!signal) return Promise.resolve(promise);
  if (signal.aborted) return Promise.reject(createAbortError(signal, fallback));

  return new Promise((resolve, reject) => {
    const onAbort = () => reject(createAbortError(signal, fallback));
    signal.addEventListener('abort', onAbort, { once: true });
    Promise.resolve(promise).then(resolve, reject).finally(() => {
      signal.removeEventListener('abort', onAbort);
    });
  });
}

async function waitForBoundedResult(promise, options = {}) {
  const timeoutMs = Number(options.timeoutMs) > 0
    ? Number(options.timeoutMs)
    : DEFAULT_HTTP_TIMEOUT_MS;
  const serviceName = String(options.serviceName || 'Remote service').trim()
    || 'Remote service';
  let timer = null;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => reject(timeoutError(
      serviceName,
      timeoutMs,
      options.timeoutCode,
    )), timeoutMs);
  });
  try {
    return await waitForAbortableResult(
      Promise.race([Promise.resolve(promise), deadline]),
      options.signal,
    );
  } finally {
    clearTimeout(timer);
  }
}

async function readResponseBuffer(response, options = {}) {
  const maxBytes = Number(options.maxResponseBytes) > 0
    ? Number(options.maxResponseBytes)
    : DEFAULT_MAX_RESPONSE_BYTES;
  const serviceName = String(options.serviceName || 'Remote service').trim()
    || 'Remote service';
  const tooLarge = () => responseTooLargeError(
    serviceName,
    maxBytes,
    options.tooLargeCode,
  );
  const signal = options.signal || null;
  if (signal?.aborted) {
    await response?.body?.cancel?.().catch(() => {});
    throw createAbortError(signal);
  }
  const contentLength = Number(response?.headers?.get?.('content-length'));
  if (Number.isFinite(contentLength) && contentLength > maxBytes) {
    await response?.body?.cancel?.().catch(() => {});
    throw tooLarge();
  }

  const reader = response?.body?.getReader?.();
  if (!reader) {
    let buffer;
    if (typeof response?.arrayBuffer === 'function') {
      buffer = Buffer.from(await waitForAbortableResult(response.arrayBuffer(), signal));
    } else {
      buffer = Buffer.from(await waitForAbortableResult(response.text(), signal), 'utf8');
    }
    if (buffer.byteLength > maxBytes) throw tooLarge();
    return buffer;
  }

  const chunks = [];
  let totalBytes = 0;
  const cancelReader = () => {
    Promise.resolve(reader.cancel(signal?.reason)).catch(() => {});
  };
  signal?.addEventListener('abort', cancelReader, { once: true });
  try {
    while (true) {
      const { done, value } = await waitForAbortableResult(reader.read(), signal);
      if (done) break;
      const chunk = Buffer.from(value);
      totalBytes += chunk.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel().catch(() => {});
        throw tooLarge();
      }
      chunks.push(chunk);
    }
  } finally {
    signal?.removeEventListener('abort', cancelReader);
    reader.releaseLock?.();
  }
  return Buffer.concat(chunks, totalBytes);
}

async function readResponseText(response, options = {}) {
  return (await readResponseBuffer(response, options)).toString('utf8');
}

async function fetchResponse(url, options = {}, reader = readResponseBuffer) {
  const serviceName = String(options.serviceName || 'Remote service').trim()
    || 'Remote service';
  const timeoutMs = Number(options.timeoutMs) > 0
    ? Number(options.timeoutMs)
    : DEFAULT_HTTP_TIMEOUT_MS;
  const maxResponseBytes = Number(options.maxResponseBytes) > 0
    ? Number(options.maxResponseBytes)
    : DEFAULT_MAX_RESPONSE_BYTES;
  const callerSignal = options.signal || null;
  const fetchImpl = typeof options.fetchImpl === 'function' ? options.fetchImpl : fetch;
  if (callerSignal?.aborted) throw createAbortError(callerSignal);

  const controller = new AbortController();
  let rejectDeadline;
  let timeoutFailure = null;
  const deadline = new Promise((_, reject) => {
    rejectDeadline = reject;
  });
  const abortFromCaller = () => {
    const error = createAbortError(callerSignal);
    controller.abort(error);
    rejectDeadline(error);
  };
  callerSignal?.addEventListener('abort', abortFromCaller, { once: true });

  const timer = setTimeout(() => {
    timeoutFailure = timeoutError(serviceName, timeoutMs, options.timeoutCode);
    controller.abort(timeoutFailure);
    rejectDeadline(timeoutFailure);
  }, timeoutMs);

  const {
    fetchImpl: _fetchImpl,
    maxResponseBytes: _maxResponseBytes,
    serviceName: _serviceName,
    signal: _signal,
    timeoutCode: _timeoutCode,
    timeoutMs: _timeoutMs,
    tooLargeCode: _tooLargeCode,
    ...fetchOptions
  } = options;
  const operation = Promise.resolve().then(async () => {
    const response = await fetchImpl(url, {
      ...fetchOptions,
      signal: controller.signal,
    });
    const body = await reader(response, {
      maxResponseBytes,
      serviceName,
      signal: controller.signal,
      tooLargeCode: options.tooLargeCode,
    });
    return { response, body };
  });

  try {
    return await Promise.race([operation, deadline]);
  } catch (error) {
    if (callerSignal?.aborted) throw createAbortError(callerSignal);
    if (timeoutFailure) throw timeoutFailure;
    throw error;
  } finally {
    clearTimeout(timer);
    callerSignal?.removeEventListener('abort', abortFromCaller);
  }
}

async function fetchResponseBuffer(url, options = {}) {
  return fetchResponse(url, options, readResponseBuffer);
}

async function fetchResponseText(url, options = {}) {
  const { response, body } = await fetchResponse(url, options, readResponseBuffer);
  return { response, text: body.toString('utf8') };
}

module.exports = {
  DEFAULT_HTTP_TIMEOUT_MS,
  DEFAULT_MAX_RESPONSE_BYTES,
  fetchResponseBuffer,
  fetchResponseText,
  readResponseBuffer,
  readResponseText,
  responseTooLargeError,
  timeoutError,
  waitForAbortableResult,
  waitForBoundedResult,
};
