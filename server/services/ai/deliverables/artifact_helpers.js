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
  'artifact',
  'artifacts',
  'artifactPath',
  'artifactPaths',
  'artifactUrl',
  'artifactUrls',
  'artifactUri',
  'artifactUris',
  'downloadUrl',
  'downloadUrls',
  'downloadUri',
  'downloadUris',
];

const GENERIC_CANDIDATE_KEYS = new Set([
  'path',
  'paths',
  'file',
  'files',
  'filePath',
  'filePaths',
  'fullPath',
  'fullPaths',
  'downloadUrl',
  'downloadUrls',
  'downloadUri',
  'downloadUris',
]);

const EXPLICIT_CANDIDATE_KEYS = new Set(
  CANDIDATE_KEYS.filter((key) => !GENERIC_CANDIDATE_KEYS.has(key))
);

const ARTIFACT_CONTAINER_KEYS = new Set([
  'artifact',
  'artifacts',
  'attachment',
  'attachments',
  'deliverable',
  'deliverables',
  'download',
  'downloads',
  'file',
  'files',
  'media',
  'preview',
  'screenshot',
  'screenshots',
]);

const CONTAINER_URL_KEYS = new Set(['url', 'urls', 'uri', 'uris', 'href', 'hrefs']);

const EVIDENCE_RESULT_TOOLS = /^(execute_command|github_|list_|search_|read_|get_|find_|http_request|web_search|browser_get|browser_read|code_navigate|query_structured_data|memory_|session_search|read_health_data)/;

function allowsGenericCandidateKeys(toolName = '') {
  return !EVIDENCE_RESULT_TOOLS.test(String(toolName || ''));
}

function isExplicitCandidateKey(keyHint = '', parentKeyHint = '', options = {}) {
  if (EXPLICIT_CANDIDATE_KEYS.has(keyHint)) return true;
  if (
    ARTIFACT_CONTAINER_KEYS.has(parentKeyHint)
    && CANDIDATE_KEYS.includes(keyHint)
    && (!GENERIC_CANDIDATE_KEYS.has(parentKeyHint) || options.allowGenericKeys === true)
  ) {
    return true;
  }
  if (GENERIC_CANDIDATE_KEYS.has(keyHint)) return options.allowGenericKeys === true;
  if (!CONTAINER_URL_KEYS.has(keyHint)) return false;
  return ARTIFACT_CONTAINER_KEYS.has(parentKeyHint);
}

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
  if (text.startsWith('//')) return null;
  if (/^[A-Za-z]:\\/.test(text)) {
    const ext = path.extname(text.split('?')[0]).toLowerCase();
    if (!FILE_EXTENSION_TO_KIND[ext]) return null;
    return { path: text, uri: null };
  }
  if (path.isAbsolute(text)) {
    const ext = path.extname(text.split('?')[0]).toLowerCase();
    if (!FILE_EXTENSION_TO_KIND[ext]) return null;
    return { path: text, uri: null };
  }
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
      return null;
    }
  }
  return artifact.path || artifact.uri ? artifact : null;
}

function scanStringForCandidates(text, { explicit = false } = {}) {
  const input = String(text || '');
  const matches = [];
  const regexes = explicit
    ? [
      /\/api\/artifacts\/[A-Za-z0-9%_-]+\/content/g,
      /\/[^\s"'`]+?\.(?:pptx?|pdf|docx?|md|txt|html?|csv|tsv|xlsx?|json|png|jpe?g|gif|webp|svg|mp4|mov|m4v|webm)\b/g,
      /[A-Za-z]:\\[^\s"'`]+?\.(?:pptx?|pdf|docx?|md|txt|html?|csv|tsv|xlsx?|json|png|jpe?g|gif|webp|svg|mp4|mov|m4v|webm)\b/g,
      /https?:\/\/[^\s"'`]+?\.(?:pptx?|pdf|docx?|md|txt|html?|csv|tsv|xlsx?|json|png|jpe?g|gif|webp|svg|mp4|mov|m4v|webm)\b/g,
    ]
    : [
      /\/api\/artifacts\/[A-Za-z0-9%_-]+\/content/g,
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
  const seenCandidates = new Set();
  const fallbackKind = inferArtifactKind(toolName, 'artifact');
  const allowGenericKeys = allowsGenericCandidateKeys(toolName);

  async function pushCandidate(candidate) {
    const candidateKey = String(candidate || '').trim();
    if (!candidateKey || seenCandidates.has(candidateKey)) return;
    seenCandidates.add(candidateKey);
    const artifact = await buildArtifactFromCandidate(candidate, fallbackKind);
    if (!artifact) return;
    const key = `${artifact.kind}:${artifact.path || artifact.uri}`;
    if (seen.has(key)) return;
    seen.add(key);
    artifacts.push(artifact);
  }

  async function visit(value, keyHint = '', parentKeyHint = '') {
    if (value == null) return;
    if (typeof value === 'string') {
      const explicit = isExplicitCandidateKey(keyHint, parentKeyHint, { allowGenericKeys });
      if (explicit) {
        if (normalizePathOrUri(value)) await pushCandidate(value);
        return;
      }
      for (const candidate of scanStringForCandidates(value, { explicit })) {
        await pushCandidate(candidate);
      }
      return;
    }
    if (Array.isArray(value)) {
      for (const item of value) await visit(item, keyHint, parentKeyHint);
      return;
    }
    if (typeof value === 'object') {
      for (const [key, nested] of Object.entries(value)) {
        await visit(nested, key, keyHint);
      }
    }
  }

  await visit(result);
  return artifacts;
}

module.exports = {
  allowsGenericCandidateKeys,
  extractArtifactsFromResult,
  inferArtifactKind,
  inferMimeType,
  isExplicitCandidateKey,
  normalizePathOrUri,
};
