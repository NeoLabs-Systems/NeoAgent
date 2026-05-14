'use strict';

const path = require('path');

function pickDeterministicFrameSecond(durationSeconds) {
  const duration = Number(durationSeconds);
  if (!Number.isFinite(duration) || duration <= 0) {
    return 2;
  }
  const target = Math.round(duration * 0.33);
  return Math.max(1, Math.min(target, 120));
}

function inferImageContentType(filePath) {
  const ext = path.extname(String(filePath || '')).toLowerCase();
  if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg';
  if (ext === '.webp') return 'image/webp';
  if (ext === '.png') return 'image/png';
  return 'application/octet-stream';
}

function normalizeFrameReference(input = {}) {
  if (!input || typeof input !== 'object') {
    return null;
  }
  if (!input.url) {
    return null;
  }
  return {
    url: input.url,
    artifactId: input.artifactId || null,
    mimeType: input.mimeType || null,
    byteSize: Number.isFinite(Number(input.byteSize)) ? Number(input.byteSize) : null,
    source: input.source || 'frame',
  };
}

module.exports = {
  inferImageContentType,
  normalizeFrameReference,
  pickDeterministicFrameSecond,
};
