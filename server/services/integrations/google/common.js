'use strict';

const fs = require('fs');
const path = require('path');
const { TextDecoder } = require('util');

function bufferToBase64Url(buffer) {
  return Buffer.from(buffer)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function stringToBase64Url(text) {
  return bufferToBase64Url(Buffer.from(String(text || ''), 'utf8'));
}

function base64UrlToBuffer(value) {
  if (!value) return Buffer.alloc(0);
  const raw = String(value);
  const normalized = raw
    .replace(/-/g, '+')
    .replace(/_/g, '/')
    .padEnd(Math.ceil(raw.length / 4) * 4, '=');
  return Buffer.from(normalized, 'base64');
}

function normalizeCharset(charset) {
  const normalized = String(charset || 'utf-8').trim().toLowerCase();
  if (!normalized) return 'utf-8';
  if (normalized === 'utf8') return 'utf-8';
  if (normalized === 'us-ascii') return 'ascii';
  if (
    normalized === 'latin1'
    || normalized === 'latin-1'
    || normalized === 'iso-8859-1'
    || normalized === 'iso8859-1'
  ) {
    return 'windows-1252';
  }
  return normalized;
}

function decodeBytes(buffer, charset = 'utf-8') {
  const bytes = Buffer.isBuffer(buffer) ? buffer : Buffer.from(buffer || '');
  const candidates = [
    normalizeCharset(charset),
    'utf-8',
    'windows-1252',
  ];
  for (const candidate of candidates) {
    try {
      return new TextDecoder(candidate, { fatal: false }).decode(bytes);
    } catch {}
  }
  return bytes.toString('utf8');
}

function mojibakeScore(value) {
  const text = String(value || '');
  let score = 0;
  for (const char of text) {
    if (char === '\uFFFD') score += 4;
    else if (char === 'Ã' || char === 'Â') score += 3;
    else if (char === 'â' || char === 'ð' || char === 'ï') score += 2;
  }
  return score;
}

function repairMojibake(value) {
  let current = String(value || '');
  for (let i = 0; i < 2; i += 1) {
    if (mojibakeScore(current) === 0) break;
    const repaired = Buffer.from(current, 'latin1').toString('utf8');
    if (!repaired || mojibakeScore(repaired) >= mojibakeScore(current)) break;
    current = repaired;
  }
  return current;
}

function base64UrlToString(value) {
  return repairMojibake(decodeBytes(base64UrlToBuffer(value), 'utf-8'));
}

function parseCharset(value) {
  const match = /charset\s*=\s*("?)([^";\s]+)\1/i.exec(String(value || ''));
  return match?.[2] || 'utf-8';
}

function decodeQuotedPrintableToBuffer(value) {
  const cleaned = String(value || '').replace(/=\r?\n/g, '');
  const bytes = [];
  for (let i = 0; i < cleaned.length; i += 1) {
    const char = cleaned[i];
    if (
      char === '='
      && i + 2 < cleaned.length
      && /^[0-9A-Fa-f]{2}$/.test(cleaned.slice(i + 1, i + 3))
    ) {
      bytes.push(Number.parseInt(cleaned.slice(i + 1, i + 3), 16));
      i += 2;
      continue;
    }
    bytes.push(char.charCodeAt(0));
  }
  return Buffer.from(bytes);
}

function decodeMimeWord(charset, encoding, value) {
  const normalizedEncoding = String(encoding || '').trim().toUpperCase();
  if (normalizedEncoding === 'B') {
    return repairMojibake(
      decodeBytes(Buffer.from(String(value || ''), 'base64'), charset),
    );
  }
  if (normalizedEncoding === 'Q') {
    return repairMojibake(
      decodeBytes(
        decodeQuotedPrintableToBuffer(String(value || '').replace(/_/g, ' ')),
        charset,
      ),
    );
  }
  return String(value || '');
}

function decodeMimeWords(value) {
  return String(value || '').replace(
    /=\?([^?]+)\?([bqBQ])\?([^?]*)\?=/g,
    (_, charset, encoding, encodedText) =>
      decodeMimeWord(charset, encoding, encodedText),
  );
}

function normalizeDecodedText(value) {
  return repairMojibake(decodeMimeWords(value));
}

function getHeader(headers, name) {
  const normalized = String(name || '').toLowerCase();
  const match = Array.isArray(headers)
    ? headers.find(
        (header) => String(header?.name || '').toLowerCase() === normalized,
      )
    : null;
  return match ? normalizeDecodedText(match.value) : null;
}

function stripHtml(html) {
  return String(html || '')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function extractMessageBody(payload) {
  if (!payload) return '';
  const headers = Array.isArray(payload.headers) ? payload.headers : [];
  const contentType = getHeader(headers, 'Content-Type') || '';
  const transferEncoding = (getHeader(headers, 'Content-Transfer-Encoding') || '').toLowerCase();
  const charset = parseCharset(contentType);
  if (payload.body?.data && payload.mimeType === 'text/plain') {
    const raw = base64UrlToBuffer(payload.body.data);
    const decoded = transferEncoding.includes('quoted-printable')
      ? decodeBytes(decodeQuotedPrintableToBuffer(raw.toString('latin1')), charset)
      : decodeBytes(raw, charset);
    return normalizeDecodedText(decoded);
  }
  if (payload.body?.data && payload.mimeType === 'text/html') {
    const raw = base64UrlToBuffer(payload.body.data);
    const decoded = transferEncoding.includes('quoted-printable')
      ? decodeBytes(decodeQuotedPrintableToBuffer(raw.toString('latin1')), charset)
      : decodeBytes(raw, charset);
    return stripHtml(normalizeDecodedText(decoded));
  }
  if (!Array.isArray(payload.parts)) return '';

  for (const part of payload.parts) {
    const text = extractMessageBody(part);
    if (text) return text;
  }

  return '';
}

function ensureParentDir(filePath) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function coerceStringList(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item || '').trim())
      .filter(Boolean);
  }
  if (typeof value === 'string') {
    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
}

function summarizeFile(file) {
  return {
    id: file.id || null,
    name: file.name || '',
    mimeType: file.mimeType || null,
    modifiedTime: file.modifiedTime || null,
    size: file.size != null ? Number(file.size) : null,
    webViewLink: file.webViewLink || null,
    webContentLink: file.webContentLink || null,
    parents: Array.isArray(file.parents) ? file.parents : [],
  };
}

function requireGoogleApiUrl(pathOrUrl, defaultBaseUrl) {
  const raw = String(pathOrUrl || '').trim();
  if (!raw) throw new Error('path is required.');
  const base = String(defaultBaseUrl || 'https://www.googleapis.com').replace(/\/$/, '');
  const url = raw.startsWith('http://') || raw.startsWith('https://')
    ? new URL(raw)
    : new URL(raw.startsWith('/') ? raw : `/${raw}`, base);
  if (!url.hostname.endsWith('googleapis.com')) {
    throw new Error('Google API request URL must target a googleapis.com host.');
  }
  return url.toString();
}

async function executeGoogleApiRequest(auth, args, options = {}) {
  const method = String(args.method || 'GET').trim().toUpperCase();
  const allowedMethods = new Set(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);
  if (!allowedMethods.has(method)) {
    throw new Error('method must be one of GET, POST, PUT, PATCH, DELETE.');
  }

  const response = await auth.request({
    url: requireGoogleApiUrl(args.path || args.url, options.baseUrl),
    method,
    params: args.query && typeof args.query === 'object' ? args.query : undefined,
    data: args.body === undefined ? undefined : args.body,
    headers: args.headers && typeof args.headers === 'object' ? args.headers : undefined,
    responseType: args.response_type === 'arraybuffer' ? 'arraybuffer' : undefined,
  });

  return {
    status: response.status,
    statusText: response.statusText,
    data: Buffer.isBuffer(response.data)
      ? response.data.toString('base64')
      : response.data,
  };
}

module.exports = {
  base64UrlToBuffer,
  coerceStringList,
  ensureParentDir,
  executeGoogleApiRequest,
  extractMessageBody,
  getHeader,
  normalizeDecodedText,
  stringToBase64Url,
  summarizeFile,
};
