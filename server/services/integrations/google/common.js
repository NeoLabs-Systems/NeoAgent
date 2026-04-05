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

module.exports = {
  coerceStringList,
  ensureParentDir,
  extractMessageBody,
  getHeader,
  stringToBase64Url,
  summarizeFile,
};
