function normalizeWhatsAppId(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (!raw) return '';

  const base = raw.includes('@') ? raw.split('@')[0] : raw;
  const primary = base.includes(':') ? base.split(':')[0] : base;
  const digits = primary.replace(/\D/g, '');
  if (digits) return digits;

  return primary;
}

function normalizeWhatsAppGroupId(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (!raw) return '';
  const jid = raw.includes('@') ? raw.split(':')[0] : raw;
  return jid.endsWith('@g.us') ? jid : '';
}

function normalizeWhatsAppWhitelistEntry(value) {
  const raw = String(value || '').trim();
  if (!raw) return '';

  const prefixed = raw.match(/^([a-z_]+):(.*)$/i);
  if (prefixed) {
    const scope = prefixed[1].trim().toLowerCase();
    const scopedValue = prefixed[2].trim();
    if (scope === 'group' || scope === 'chat') {
      const groupId = normalizeWhatsAppGroupId(scopedValue);
      if (groupId) return `${scope}:${groupId}`;
    }
    if (scope === 'user' || scope === 'phone' || scope === 'phone_number') {
      const normalized = normalizeWhatsAppId(scopedValue);
      return normalized ? `${scope === 'phone' ? 'phone_number' : scope}:${normalized}` : '';
    }
  }

  const groupId = normalizeWhatsAppGroupId(raw);
  if (groupId) return `group:${groupId}`;

  return normalizeWhatsAppId(raw);
}

function normalizeWhatsAppWhitelist(values) {
  if (!Array.isArray(values)) return [];

  const seen = new Set();
  const normalized = [];
  for (const value of values) {
    const entry = normalizeWhatsAppWhitelistEntry(value);
    if (!entry || seen.has(entry)) continue;
    seen.add(entry);
    normalized.push(entry);
  }
  return normalized;
}

function toWhatsAppJid(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (!raw) return '';
  if (raw.includes('@')) {
    const jid = raw.split(':')[0];
    if (jid.endsWith('@s.whatsapp.net') || jid.endsWith('@g.us') || jid.endsWith('@lid')) {
      return jid;
    }
  }

  const normalized = normalizeWhatsAppId(raw);
  if (!normalized) return '';
  return `${normalized}@s.whatsapp.net`;
}

module.exports = {
  normalizeWhatsAppId,
  normalizeWhatsAppGroupId,
  normalizeWhatsAppWhitelist,
  toWhatsAppJid,
};
