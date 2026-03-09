function normalizeWhatsAppId(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (!raw) return '';

  const base = raw.includes('@') ? raw.split('@')[0] : raw;
  const primary = base.includes(':') ? base.split(':')[0] : base;
  const digits = primary.replace(/\D/g, '');
  if (digits) return digits;

  return primary;
}

function normalizeWhatsAppWhitelist(values) {
  if (!Array.isArray(values)) return [];

  const seen = new Set();
  const normalized = [];
  for (const value of values) {
    const entry = normalizeWhatsAppId(value);
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
  normalizeWhatsAppWhitelist,
  toWhatsAppJid,
};
