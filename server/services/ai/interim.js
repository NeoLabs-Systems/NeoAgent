const INTERIM_KINDS = new Set(['ack', 'progress', 'question', 'blocker']);

function normalizeInterimKind(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return INTERIM_KINDS.has(normalized) ? normalized : 'progress';
}

function buildInterimMetadata({ kind, expectsReply = false } = {}) {
  const normalizedKind = normalizeInterimKind(kind);
  return {
    interim: true,
    interim_kind: normalizedKind,
    expects_reply: expectsReply === true,
  };
}

function parseInterimMetadata(value) {
  if (!value) {
    return { interim: false, kind: '', expectsReply: false };
  }

  let parsed = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch {
      parsed = null;
    }
  }

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return { interim: false, kind: '', expectsReply: false };
  }

  return {
    interim: parsed.interim === true,
    kind: normalizeInterimKind(parsed.interim_kind || parsed.kind),
    expectsReply: parsed.expects_reply === true || parsed.expectsReply === true,
  };
}

function isInterimAssistantMetadata(value) {
  return parseInterimMetadata(value).interim === true;
}

function buildInterimSignature({ content, kind, expectsReply = false, platform = null } = {}) {
  return JSON.stringify({
    content: String(content || '').replace(/\s+/g, ' ').trim(),
    kind: normalizeInterimKind(kind),
    expectsReply: expectsReply === true,
    platform: String(platform || '').trim().toLowerCase(),
  });
}

module.exports = {
  INTERIM_KINDS,
  buildInterimMetadata,
  buildInterimSignature,
  isInterimAssistantMetadata,
  normalizeInterimKind,
  parseInterimMetadata,
};
