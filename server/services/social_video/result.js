'use strict';

const { normalizeFrameReference } = require('./frame');

function isPlainObject(obj) {
  return !!obj
    && typeof obj === 'object'
    && !Array.isArray(obj)
    && obj.constructor === Object;
}

function normalizeWarningList(items) {
  return (Array.isArray(items) ? items : [])
    .map((item) => String(item || '').trim())
    .filter(Boolean);
}

function normalizeErrorList(items) {
  return (Array.isArray(items) ? items : [])
    .map((item) => {
      if (typeof item === 'string') return { message: item };
      if (!item || typeof item !== 'object') return null;
      const message = String(item.message || '').trim();
      if (!message) return null;
      return {
        code: item.code ? String(item.code) : undefined,
        message,
      };
    })
    .filter(Boolean);
}

function shapeSocialVideoResult(input = {}) {
  const errors = normalizeErrorList(input.errors);
  const warnings = normalizeWarningList(input.warnings);
  return {
    sourceUrl: String(input.sourceUrl || '').trim(),
    resolvedUrl: String(input.resolvedUrl || '').trim(),
    canonicalUrl: String(input.canonicalUrl || '').trim() || null,
    platform: String(input.platform || 'unknown').trim(),
    title: String(input.title || '').trim(),
    description: String(input.description || '').trim(),
    transcript: String(input.transcript || '').trim(),
    transcriptSource: String(input.transcriptSource || '').trim() || 'unavailable',
    frameImage: normalizeFrameReference(input.frameImage),
    metadata: isPlainObject(input.metadata)
      ? input.metadata
      : {},
    setup: isPlainObject(input.setup)
      ? input.setup
      : null,
    warnings,
    errors,
    partial: warnings.length > 0 || errors.length > 0,
  };
}

module.exports = {
  normalizeErrorList,
  isPlainObject,
  normalizeWarningList,
  shapeSocialVideoResult,
};
