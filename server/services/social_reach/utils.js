'use strict';

const cheerio = require('cheerio');
const { fetchResponseText } = require('../network/http');
const { executeSafeHttpRequest } = require('../network/safe_request');

const DEFAULT_UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
  + '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
const DEFAULT_TIMEOUT_MS = 20000;
const MAX_RESPONSE_BYTES = 2 * 1024 * 1024;

function normalizeLimit(value, fallback = 10, max = 50) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return Math.max(1, Math.min(Math.floor(n), max));
}

function assertHttpUrl(value) {
  const raw = String(value || '').trim();
  const withScheme = /^https?:\/\//i.test(raw) ? raw : `https://${raw}`;
  let parsed;
  try {
    parsed = new URL(withScheme);
  } catch {
    const error = new Error('A valid http or https URL is required.');
    error.status = 400;
    throw error;
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    const error = new Error('Only http and https URLs are supported.');
    error.status = 400;
    throw error;
  }
  return parsed;
}

async function fetchText(url, options = {}) {
  const {
    lookup,
    maxResponseBytes = MAX_RESPONSE_BYTES,
    publicOnly = false,
    requestImpl,
    signal,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    ...requestOptions
  } = options;
  const headers = {
    'user-agent': DEFAULT_UA,
    accept: 'text/plain,text/html,application/xml,application/rss+xml,application/atom+xml,*/*',
    ...(options.headers || {}),
  };
  let status;
  let text;
  if (publicOnly) {
    const result = await executeSafeHttpRequest({
      url,
      method: requestOptions.method || 'GET',
      headers,
      body: requestOptions.body,
      timeout_ms: timeoutMs,
    }, {
      signal,
      lookup,
      requestImpl,
      maxResponseBytes,
    });
    if (result.truncated) {
      const error = new Error('Response exceeded the Social Reach safety limit.');
      error.code = 'SOCIAL_REACH_RESPONSE_TOO_LARGE';
      error.status = 502;
      throw error;
    }
    status = result.status;
    text = result.body;
  } else {
    const result = await fetchResponseText(url, {
      ...requestOptions,
      headers,
      signal,
      timeoutMs,
      maxResponseBytes,
      serviceName: 'Social Reach',
      timeoutCode: 'SOCIAL_REACH_TIMEOUT',
      tooLargeCode: 'SOCIAL_REACH_RESPONSE_TOO_LARGE',
    });
    status = result.response.status;
    text = result.text;
  }
  if (status < 200 || status >= 300) {
    const error = new Error(`Request failed with HTTP ${status}`);
    error.status = status;
    error.body = text.slice(0, 500);
    throw error;
  }
  return text;
}

async function fetchJson(url, options = {}) {
  const text = await fetchText(url, {
    ...options,
    headers: {
      accept: 'application/json,*/*',
      ...(options.headers || {}),
    },
  });
  try {
    return JSON.parse(text);
  } catch (cause) {
    const error = new Error('Social Reach returned malformed JSON.', { cause });
    error.status = 502;
    throw error;
  }
}

function htmlToText(html, maxChars = 20000) {
  const $ = cheerio.load(String(html || ''));
  $('script, style, noscript, svg').remove();
  return $('body').text().replace(/\s+/g, ' ').trim().slice(0, maxChars);
}

function parseMaybeJson(value, fallback = null) {
  if (value == null) return fallback;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(String(value));
  } catch {
    return fallback;
  }
}

function compactText(value, maxChars = 4000) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars).trim()}...`;
}

module.exports = {
  DEFAULT_UA,
  assertHttpUrl,
  compactText,
  fetchJson,
  fetchText,
  htmlToText,
  normalizeLimit,
  parseMaybeJson,
};
