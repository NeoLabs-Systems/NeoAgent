'use strict';

const cheerio = require('cheerio');

const DEFAULT_UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
  + '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

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
  const response = await fetch(url, {
    redirect: 'follow',
    ...options,
    headers: {
      'user-agent': DEFAULT_UA,
      accept: 'text/plain,text/html,application/xml,application/rss+xml,application/atom+xml,*/*',
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  if (!response.ok) {
    const error = new Error(`Request failed with HTTP ${response.status}`);
    error.status = response.status;
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
  return JSON.parse(text);
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
