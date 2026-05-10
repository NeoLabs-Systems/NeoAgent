'use strict';

const fs = require('fs');
const path = require('path');
const { normalizeArtifactContract } = require('./contracts');

const FILE_EXTENSION_TO_KIND = {
  '.ppt': 'slides',
  '.pptx': 'slides',
  '.key': 'slides',
  '.pdf': 'document',
  '.doc': 'document',
  '.docx': 'document',
  '.md': 'document',
  '.txt': 'document',
  '.html': 'document',
  '.htm': 'document',
  '.csv': 'data',
  '.tsv': 'data',
  '.xlsx': 'data',
  '.xls': 'data',
  '.json': 'data',
  '.png': 'image',
  '.jpg': 'image',
  '.jpeg': 'image',
  '.gif': 'image',
  '.webp': 'image',
  '.svg': 'image',
  '.mp4': 'video',
  '.mov': 'video',
  '.m4v': 'video',
  '.webm': 'video',
};

const FILE_EXTENSION_TO_MIME = {
  '.ppt': 'application/vnd.ms-powerpoint',
  '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  '.pdf': 'application/pdf',
  '.doc': 'application/msword',
  '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.md': 'text/markdown',
  '.txt': 'text/plain',
  '.html': 'text/html',
  '.htm': 'text/html',
  '.csv': 'text/csv',
  '.tsv': 'text/tab-separated-values',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '.xls': 'application/vnd.ms-excel',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.m4v': 'video/x-m4v',
  '.webm': 'video/webm',
};

const CANDIDATE_KEYS = [
  'path',
  'paths',
  'file',
  'files',
  'filePath',
  'filePaths',
  'fullPath',
  'fullPaths',
  'mediaPath',
  'mediaPaths',
  'screenshotPath',
  'uiDumpPath',
  'url',
  'urls',
];

function inferExtension(candidate = '') {
  return path.extname(String(candidate || '').split('?')[0]).toLowerCase();
}

function inferArtifactKind(candidate = '', fallback = 'artifact') {
  const extension = inferExtension(candidate);
  if (FILE_EXTENSION_TO_KIND[extension]) return FILE_EXTENSION_TO_KIND[extension];
  const normalized = String(candidate || '').toLowerCase();
  if (normalized.includes('image')) return 'image';
  if (normalized.includes('video')) return 'video';
  if (normalized.includes('slide') || normalized.includes('ppt')) return 'slides';
  if (normalized.includes('doc') || normalized.includes('pdf')) return 'document';
  if (normalized.includes('data') || normalized.includes('chart') || normalized.includes('csv')) return 'data';
  return fallback;
}

function inferMimeType(candidate = '') {
  const extension = inferExtension(candidate);
  return FILE_EXTENSION_TO_MIME[extension] || null;
}

function normalizePathOrUri(value) {
  const text = String(value || '').trim();
  if (!text) return null;
  if (text.startsWith('/api/artifacts/')) return { uri: text, path: null };
  if (/^https?:\/\//i.test(text)) return { uri: text, path: null };
  if (/^[A-Za-z]:\\/.test(text)) return { path: text, uri: null };
  if (path.isAbsolute(text)) return { path: text, uri: null };
  return null;
}

async function buildArtifactFromCandidate(candidate, fallbackKind = 'artifact') {
  const normalized = normalizePathOrUri(candidate);
  if (!normalized) return null;
  const source = normalized.path || normalized.uri || '';
  const artifact = normalizeArtifactContract({
    kind: inferArtifactKind(source, fallbackKind),
    path: normalized.path,
    uri: normalized.uri,
    label: path.basename(String(source).split('?')[0]) || null,
    mimeType: inferMimeType(source),
  });
  if (artifact.path) {
    try {
      artifact.size = (await fs.promises.stat(artifact.path)).size;
    } catch (error) {
      console.warn('[deliverables] Failed to stat artifact candidate:', artifact.path, error?.message || error);
    }
  }
  return artifact.path || artifact.uri ? artifact : null;
}

function scanStringForCandidates(text) {
  const input = String(text || '');
  const matches = [];
  const regexes = [
    /\/api\/artifacts\/[A-Za-z0-9%_-]+\/content/g,
    /\/[^\s"'`]+?\.(?:pptx?|pdf|docx?|md|txt|html?|csv|tsv|xlsx?|json|png|jpe?g|gif|webp|svg|mp4|mov|m4v|webm)\b/g,
    /[A-Za-z]:\\[^\s"'`]+?\.(?:pptx?|pdf|docx?|md|txt|html?|csv|tsv|xlsx?|json|png|jpe?g|gif|webp|svg|mp4|mov|m4v|webm)\b/g,
    /https?:\/\/[^\s"'`]+?\.(?:pptx?|pdf|docx?|md|txt|html?|csv|tsv|xlsx?|json|png|jpe?g|gif|webp|svg|mp4|mov|m4v|webm)\b/g,
  ];
  for (const regex of regexes) {
    const found = input.match(regex);
    if (found) matches.push(...found);
  }
  return matches;
}

async function extractArtifactsFromResult(toolName, result) {
  const artifacts = [];
  const seen = new Set();
  const fallbackKind = inferArtifactKind(toolName, 'artifact');

  async function pushCandidate(candidate) {
    const artifact = await buildArtifactFromCandidate(candidate, fallbackKind);
    if (!artifact) return;
    const key = `${artifact.kind}:${artifact.path || artifact.uri}`;
    if (seen.has(key)) return;
    seen.add(key);
    artifacts.push(artifact);
  }

  async function visit(value, keyHint = '') {
    if (value == null) return;
    if (typeof value === 'string') {
      if (CANDIDATE_KEYS.includes(keyHint)) await pushCandidate(value);
      for (const candidate of scanStringForCandidates(value)) {
        await pushCandidate(candidate);
      }
      return;
    }
    if (Array.isArray(value)) {
      for (const item of value) await visit(item, keyHint);
      return;
    }
    if (typeof value === 'object') {
      for (const [key, nested] of Object.entries(value)) {
        await visit(nested, key);
      }
    }
  }

  await visit(result);
  return artifacts;
}

module.exports = {
  extractArtifactsFromResult,
  inferArtifactKind,
  inferMimeType,
  normalizePathOrUri,
};
