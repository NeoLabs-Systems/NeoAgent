'use strict';

const fs = require('fs');
const path = require('path');

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

function base64UrlToString(value) {
  if (!value) return '';
  const normalized = String(value)
    .replace(/-/g, '+')
    .replace(/_/g, '/')
    .padEnd(Math.ceil(String(value).length / 4) * 4, '=');
  return Buffer.from(normalized, 'base64').toString('utf8');
}

function getHeader(headers, name) {
  const normalized = String(name || '').toLowerCase();
  const match = Array.isArray(headers)
    ? headers.find(
        (header) => String(header?.name || '').toLowerCase() === normalized,
      )
    : null;
  return match?.value || null;
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
  if (payload.body?.data && payload.mimeType === 'text/plain') {
    return base64UrlToString(payload.body.data);
  }
  if (payload.body?.data && payload.mimeType === 'text/html') {
    return stripHtml(base64UrlToString(payload.body.data));
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
  coerceStringList,
  ensureParentDir,
  executeGoogleApiRequest,
  extractMessageBody,
  getHeader,
  stringToBase64Url,
  summarizeFile,
};
