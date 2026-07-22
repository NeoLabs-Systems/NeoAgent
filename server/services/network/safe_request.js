'use strict';

const dns = require('node:dns');
const http = require('node:http');
const https = require('node:https');
const net = require('node:net');
const {
  createAbortError,
  createLinkedAbortController,
  throwIfAborted,
} = require('../../utils/abort');
const { isPrivateHost } = require('../../utils/cloud-security');

const ALLOWED_METHODS = new Set(['GET', 'POST', 'PUT', 'DELETE', 'PATCH']);
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);
const SENSITIVE_REDIRECT_HEADERS = new Set([
  'authorization',
  'cookie',
  'proxy-authorization',
]);
const HIDDEN_RESPONSE_HEADERS = new Set([
  'proxy-authenticate',
  'set-cookie',
  'www-authenticate',
]);
const DEFAULT_TIMEOUT_MS = 30000;
const MAX_TIMEOUT_MS = 120000;
const MAX_RESPONSE_BYTES = 512 * 1024;
const MAX_REDIRECTS = 5;

function timeoutError(timeoutMs) {
  const error = new Error(`Request timed out after ${timeoutMs}ms.`);
  error.code = 'HTTP_REQUEST_TIMEOUT';
  return error;
}

function normalizeHeaders(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const headers = {};
  for (const [rawName, rawValue] of Object.entries(value)) {
    const name = String(rawName || '').trim().toLowerCase();
    if (!name || rawValue == null) continue;
    if (name === 'host' || name === 'connection' || name === 'transfer-encoding') continue;
    headers[name] = Array.isArray(rawValue)
      ? rawValue.map((item) => String(item))
      : String(rawValue);
  }
  return headers;
}

function parseHttpUrl(value) {
  let parsed;
  try {
    parsed = new URL(String(value || '').trim());
  } catch {
    throw new Error('Invalid URL.');
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('URL scheme not allowed. Only http and https are permitted.');
  }
  if (parsed.username || parsed.password) {
    throw new Error('Credentials in request URLs are not permitted. Use headers instead.');
  }
  return parsed;
}

async function waitForLookup(lookupPromise, signal) {
  throwIfAborted(signal, 'HTTP request aborted.');
  if (!signal) return lookupPromise;
  return new Promise((resolve, reject) => {
    const onAbort = () => reject(createAbortError(signal));
    signal.addEventListener('abort', onAbort, { once: true });
    Promise.resolve(lookupPromise).then(resolve, reject).finally(() => {
      signal.removeEventListener('abort', onAbort);
    });
  });
}

async function resolveHttpTarget(url, options = {}) {
  const parsed = url instanceof URL ? url : parseHttpUrl(url);
  const hostname = parsed.hostname.replace(/^\[|\]$/g, '');
  const allowPrivate = options.allowPrivate === true;
  if (!allowPrivate && isPrivateHost(hostname)) {
    throw new Error('Private, loopback, and reserved network addresses are not permitted.');
  }
  if (net.isIP(hostname)) {
    return { address: hostname, family: net.isIP(hostname), parsed };
  }

  const lookup = options.lookup || dns.promises.lookup;
  let records;
  try {
    records = await waitForLookup(
      lookup(hostname, { all: true, verbatim: true }),
      options.signal,
    );
  } catch (error) {
    throwIfAborted(options.signal, 'HTTP request aborted.');
    throw new Error(`Could not resolve request host: ${error?.message || 'DNS lookup failed'}`);
  }
  const addresses = (Array.isArray(records) ? records : [records])
    .map((record) => ({
      address: String(record?.address || record || ''),
      family: Number(record?.family) || net.isIP(record?.address || record),
    }))
    .filter((record) => record.address && record.family);
  if (addresses.length === 0) throw new Error('Could not resolve request host.');
  if (!allowPrivate && addresses.some((record) => isPrivateHost(record.address))) {
    throw new Error('Request host resolves to a private, loopback, or reserved address.');
  }
  return { ...addresses[0], parsed };
}

function sanitizeResponseHeaders(headers = {}) {
  const safe = {};
  for (const [name, value] of Object.entries(headers)) {
    const normalized = String(name || '').toLowerCase();
    if (!normalized || HIDDEN_RESPONSE_HEADERS.has(normalized)) continue;
    safe[normalized] = Array.isArray(value) ? value.join(', ') : String(value ?? '');
  }
  return safe;
}

function collectResponseBody(chunks, totalBytes, responseType) {
  const buffer = Buffer.concat(chunks, totalBytes);
  return responseType === 'buffer' ? buffer : buffer.toString('utf8');
}

function requestOnce(target, options = {}) {
  const { parsed, address, family } = target;
  const requestImpl = options.requestImpl
    || (parsed.protocol === 'https:' ? https.request : http.request);
  const headers = { ...normalizeHeaders(options.headers), host: parsed.host };
  if (options.body != null) {
    headers['content-length'] = String(Buffer.byteLength(options.body));
  } else {
    delete headers['content-length'];
  }

  return new Promise((resolve, reject) => {
    let settled = false;
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      callback(value);
    };
    const request = requestImpl({
      protocol: parsed.protocol,
      hostname: address,
      family,
      port: parsed.port || undefined,
      method: options.method,
      path: `${parsed.pathname}${parsed.search}`,
      headers,
      maxHeaderSize: 32 * 1024,
      servername: net.isIP(parsed.hostname.replace(/^\[|\]$/g, ''))
        ? undefined
        : parsed.hostname,
      signal: options.signal,
    }, (response) => {
      const status = Number(response.statusCode) || 0;
      if (REDIRECT_STATUSES.has(status) && response.headers?.location) {
        response.destroy();
        finish(resolve, { status, headers: response.headers, body: '', truncated: false });
        return;
      }
      const chunks = [];
      let totalBytes = 0;
      let truncated = false;
      response.on('data', (chunkValue) => {
        if (settled) return;
        const chunk = Buffer.from(chunkValue);
        const remaining = options.maxResponseBytes - totalBytes;
        if (remaining > 0) {
          chunks.push(chunk.subarray(0, remaining));
          totalBytes += Math.min(chunk.byteLength, remaining);
        }
        if (chunk.byteLength > remaining) {
          truncated = true;
          response.destroy();
          finish(resolve, {
            status,
            headers: response.headers,
            body: collectResponseBody(chunks, totalBytes, options.responseType),
            truncated,
          });
        }
      });
      response.on('end', () => finish(resolve, {
        status,
        headers: response.headers,
        body: collectResponseBody(chunks, totalBytes, options.responseType),
        truncated,
      }));
      response.on('error', (error) => finish(reject, error));
    });
    request.on('error', (error) => finish(reject, error));
    if (options.body != null) request.write(options.body);
    request.end();
  });
}

function redirectedRequest(previousUrl, nextUrl, method, headers, body, status) {
  let nextMethod = method;
  let nextBody = body;
  const nextHeaders = { ...headers };
  if (status === 303 || ((status === 301 || status === 302) && method === 'POST')) {
    nextMethod = 'GET';
    nextBody = null;
    delete nextHeaders['content-length'];
    delete nextHeaders['content-type'];
  }
  if (previousUrl.origin !== nextUrl.origin) {
    for (const name of SENSITIVE_REDIRECT_HEADERS) delete nextHeaders[name];
  }
  return { method: nextMethod, headers: nextHeaders, body: nextBody };
}

async function executeSafeHttpRequest(args = {}, context = {}) {
  const method = String(args.method || 'GET').trim().toUpperCase();
  if (!ALLOWED_METHODS.has(method)) throw new Error(`Unsupported HTTP method: ${method}`);
  const timeoutMs = Math.max(
    100,
    Math.min(Number(args.timeout_ms) || DEFAULT_TIMEOUT_MS, MAX_TIMEOUT_MS),
  );
  const timeoutController = new AbortController();
  const linked = createLinkedAbortController([context.signal, timeoutController.signal]);
  const timer = setTimeout(() => timeoutController.abort(timeoutError(timeoutMs)), timeoutMs);
  timer.unref?.();
  let currentUrl = parseHttpUrl(args.url);
  let requestState = {
    method,
    headers: normalizeHeaders(args.headers),
    body: args.body != null && !['GET', 'DELETE'].includes(method)
      ? String(args.body)
      : null,
  };
  if (requestState.body != null && !requestState.headers['content-type']) {
    requestState.headers['content-type'] = 'application/json';
  }
  const redirects = [];

  try {
    for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount += 1) {
      throwIfAborted(linked.signal, 'HTTP request aborted.');
      const target = await resolveHttpTarget(currentUrl, {
        allowPrivate: context.allowPrivate === true,
        lookup: context.lookup,
        signal: linked.signal,
      });
      const response = await requestOnce(target, {
        ...requestState,
        maxResponseBytes: Number(context.maxResponseBytes) > 0
          ? Number(context.maxResponseBytes)
          : MAX_RESPONSE_BYTES,
        requestImpl: context.requestImpl,
        responseType: context.responseType,
        signal: linked.signal,
      });
      const location = response.headers?.location;
      if (!REDIRECT_STATUSES.has(response.status) || !location) {
        return {
          status: response.status,
          headers: sanitizeResponseHeaders(response.headers),
          body: response.truncated && typeof response.body === 'string'
            ? `${response.body}\n...[truncated at response safety limit]`
            : response.body,
          finalUrl: currentUrl.toString(),
          redirects,
          truncated: response.truncated,
        };
      }
      if (redirectCount >= MAX_REDIRECTS) {
        throw new Error(`Request exceeded the ${MAX_REDIRECTS}-redirect limit.`);
      }
      const nextUrl = parseHttpUrl(new URL(String(location), currentUrl).toString());
      redirects.push(nextUrl.toString());
      requestState = redirectedRequest(
        currentUrl,
        nextUrl,
        requestState.method,
        requestState.headers,
        requestState.body,
        response.status,
      );
      currentUrl = nextUrl;
    }
    throw new Error(`Request exceeded the ${MAX_REDIRECTS}-redirect limit.`);
  } catch (error) {
    if (context.signal?.aborted) throw createAbortError(context.signal);
    if (timeoutController.signal.aborted) throw createAbortError(timeoutController.signal);
    throw error;
  } finally {
    clearTimeout(timer);
    linked.cleanup();
  }
}

module.exports = {
  MAX_REDIRECTS,
  MAX_RESPONSE_BYTES,
  executeSafeHttpRequest,
  normalizeHeaders,
  parseHttpUrl,
  redirectedRequest,
  resolveHttpTarget,
  sanitizeResponseHeaders,
};
