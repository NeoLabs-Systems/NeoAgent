'use strict';

const DELIVERABLE_TYPES = [
  'slides',
  'document',
  'research_report',
  'data_analysis',
  'image',
  'video',
];

const DELIVERABLE_SELECTION_STATUSES = ['selected', 'standard'];
const DELIVERABLE_VALIDATION_STATUSES = ['passed', 'failed'];

function clampText(value, maxLength = 240) {
  return String(value || '').trim().slice(0, maxLength);
}

function normalizeDeliverableType(value) {
  const normalized = clampText(value, 48).toLowerCase();
  return DELIVERABLE_TYPES.includes(normalized) ? normalized : null;
}

function normalizeStringList(value, limit = 8, maxLength = 120) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => clampText(item, maxLength))
    .filter(Boolean)
    .slice(0, limit);
}

function normalizeArtifactContract(raw = {}) {
  const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  return {
    kind: clampText(source.kind, 48) || 'artifact',
    path: clampText(source.path || source.fullPath, 500) || null,
    uri: clampText(source.uri || source.url, 500) || null,
    label: clampText(source.label, 120) || null,
    mimeType: clampText(source.mimeType || source.contentType, 120) || null,
    size: Number.isFinite(Number(source.size ?? source.byteSize))
      ? Number(source.size ?? source.byteSize)
      : null,
    preview: source.preview && typeof source.preview === 'object' && !Array.isArray(source.preview)
      ? { ...source.preview }
      : {},
  };
}

function normalizeDeliverableSelection(raw = {}) {
  const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  const type = normalizeDeliverableType(source.type);
  const confidence = Math.max(0, Math.min(1, Number(source.confidence) || 0));
  const status = DELIVERABLE_SELECTION_STATUSES.includes(String(source.status || '').trim().toLowerCase())
    ? String(source.status).trim().toLowerCase()
    : (type ? 'selected' : 'standard');

  return {
    status,
    type,
    confidence,
    goal: clampText(source.goal, 240),
    requestedOutputs: normalizeStringList(source.requested_outputs || source.requestedOutputs, 8, 120),
    supportingCapabilities: normalizeStringList(source.supporting_capabilities || source.supportingCapabilities, 8, 64),
  };
}

function normalizeDeliverableValidationResult(raw = {}) {
  const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  const status = DELIVERABLE_VALIDATION_STATUSES.includes(String(source.status || '').trim().toLowerCase())
    ? String(source.status).trim().toLowerCase()
    : 'failed';
  const artifacts = Array.isArray(source.artifacts)
    ? source.artifacts.map(normalizeArtifactContract).filter((artifact) => artifact.path || artifact.uri)
    : [];

  return {
    status,
    summary: clampText(source.summary, 320),
    errors: normalizeStringList(source.errors, 8, 220),
    warnings: normalizeStringList(source.warnings, 8, 220),
    artifacts,
    metrics: source.metrics && typeof source.metrics === 'object' && !Array.isArray(source.metrics)
      ? { ...source.metrics }
      : {},
  };
}

function normalizeDeliverableResult(raw = {}) {
  const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  return {
    type: normalizeDeliverableType(source.type),
    status: clampText(source.status, 32) || 'unknown',
    summary: clampText(source.summary, 320),
    artifacts: Array.isArray(source.artifacts)
      ? source.artifacts.map(normalizeArtifactContract).filter((artifact) => artifact.path || artifact.uri)
      : [],
    validation: normalizeDeliverableValidationResult(source.validation),
    metadata: source.metadata && typeof source.metadata === 'object' && !Array.isArray(source.metadata)
      ? { ...source.metadata }
      : {},
  };
}

module.exports = {
  DELIVERABLE_TYPES,
  clampText,
  normalizeArtifactContract,
  normalizeDeliverableResult,
  normalizeDeliverableSelection,
  normalizeDeliverableType,
  normalizeDeliverableValidationResult,
  normalizeStringList,
};
