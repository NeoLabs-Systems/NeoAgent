'use strict';

const MAX_VTT_BYTES = 2 * 1024 * 1024;
const MAX_INPUT_BYTES = MAX_VTT_BYTES;

function normalizeLanguageCode(value) {
  return String(value || '').trim().toLowerCase();
}

function pickCaptionTrack(captionGroups = {}, preferredLanguages = []) {
  const tracks = [];
  for (const [language, items] of Object.entries(captionGroups || {})) {
    if (!Array.isArray(items)) continue;
    for (const item of items) {
      if (!item || typeof item !== 'object') continue;
      const url = String(item.url || '').trim();
      if (!url) continue;
      tracks.push({
        language: normalizeLanguageCode(language),
        url,
        ext: normalizeLanguageCode(item.ext || ''),
        name: String(item.name || '').trim(),
      });
    }
  }
  if (tracks.length === 0) return null;

  const preferred = preferredLanguages.map(normalizeLanguageCode).filter(Boolean);
  const preferredOrder = preferred.length > 0 ? preferred : ['en', 'en-us', 'en-gb'];
  const preferredExt = ['vtt', 'webvtt', 'srt', 'json3'];

  const scoreTrack = (track) => {
    const langIdx = preferredOrder.findIndex((code) => track.language === code || track.language.startsWith(`${code}-`));
    const langScore = langIdx === -1 ? 999 : langIdx;
    const extIdx = preferredExt.findIndex((ext) => track.ext === ext);
    const extScore = extIdx === -1 ? 999 : extIdx;
    return (langScore * 100) + extScore;
  };

  return tracks
    .map((track) => ({ track, score: scoreTrack(track) }))
    .sort((left, right) => left.score - right.score)[0]?.track || null;
}

function stripTags(text) {
  return String(text || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\{\\an\d+\}/g, ' ')
    .replace(/\[[^\]]+\]/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

function inputByteLength(value) {
  if (Buffer.isBuffer(value)) return value.byteLength;
  return Buffer.byteLength(String(value || ''), 'utf8');
}

function stripXml(value) {
  return String(value || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

function parseWebVttToText(vtt) {
  if (inputByteLength(vtt) > MAX_VTT_BYTES) {
    throw new Error(`parseWebVttToText input exceeds MAX_VTT_BYTES (${MAX_VTT_BYTES}).`);
  }
  const lines = String(vtt || '').split(/\r?\n/);
  const chunks = [];
  for (const line of lines) {
    const clean = line.trim();
    if (!clean) continue;
    if (/^WEBVTT/i.test(clean)) continue;
    if (/^NOTE\b/i.test(clean)) continue;
    if (/^\d+$/.test(clean)) continue;
    if (/^\d{2}:\d{2}:\d{2}[.,]\d{3}\s+-->/.test(clean) || /^\d{2}:\d{2}[.,]\d{3}\s+-->/.test(clean)) continue;
    const normalized = stripTags(clean);
    if (!normalized) continue;
    if (chunks[chunks.length - 1] === normalized) continue;
    chunks.push(normalized);
  }
  return chunks.join(' ').trim();
}

function parseSrtToText(srt) {
  return parseWebVttToText(String(srt || '').replace(/,/g, '.'));
}

function parseJson3ToText(raw) {
  if (inputByteLength(raw) > MAX_INPUT_BYTES) {
    return '';
  }
  let payload;
  try {
    payload = JSON.parse(String(raw || ''));
  } catch {
    return '';
  }
  const events = Array.isArray(payload?.events) ? payload.events : [];
  const parts = [];
  for (const event of events) {
    const segs = Array.isArray(event?.segs) ? event.segs : [];
    const text = segs
      .map((segment) => String(segment?.utf8 || '').trim())
      .filter(Boolean)
      .join(' ');
    const normalized = stripTags(text);
    if (!normalized) continue;
    if (parts[parts.length - 1] === normalized) continue;
    parts.push(normalized);
  }
  return parts.join(' ').trim();
}

function parseTtmlToText(raw) {
  if (inputByteLength(raw) > MAX_INPUT_BYTES) {
    return '';
  }
  const text = String(raw || '');
  const parts = [];
  const paragraphRe = /<p\b[^>]*>([\s\S]*?)<\/p>/gi;
  let match = paragraphRe.exec(text);
  while (match) {
    const parsed = stripXml(match[1]);
    if (parsed && parts[parts.length - 1] !== parsed) {
      parts.push(parsed);
    }
    match = paragraphRe.exec(text);
  }
  if (parts.length > 0) {
    return parts.join(' ').trim();
  }
  return stripXml(text);
}

function parseCaptionText(raw, extension = '') {
  const ext = normalizeLanguageCode(extension);
  if (ext === 'vtt' || ext === 'webvtt') {
    return parseWebVttToText(raw);
  }
  if (ext === 'ttml') {
    return parseTtmlToText(raw);
  }
  if (ext === 'srt') {
    return parseSrtToText(raw);
  }
  if (ext === 'json3' || ext === 'json') {
    return parseJson3ToText(raw);
  }
  if (/^\s*<tt\b/i.test(String(raw || '')) || /xmlns\s*=\s*["'][^"']*ttml/i.test(String(raw || ''))) {
    return parseTtmlToText(raw);
  }
  return parseWebVttToText(raw);
}

function decideTranscriptPath(options = {}) {
  if (options.forceStt) {
    return { mode: 'stt', reason: 'forced' };
  }
  if (options.captionTrack) {
    return { mode: 'captions', reason: 'captions_present' };
  }
  return { mode: 'stt', reason: 'captions_missing' };
}

module.exports = {
  decideTranscriptPath,
  normalizeLanguageCode,
  parseCaptionText,
  parseJson3ToText,
  parseSrtToText,
  parseTtmlToText,
  parseWebVttToText,
  pickCaptionTrack,
  MAX_INPUT_BYTES,
  MAX_VTT_BYTES,
};
