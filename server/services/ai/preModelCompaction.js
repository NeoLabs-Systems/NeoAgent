'use strict';

function clampText(value, maxLength = 2000) {
  const text = String(value || '').trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 1)).trimEnd()}...`;
}

function stripHtmlTags(input) {
  return String(input || '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

function shortenUrlText(input) {
  return String(input || '').replace(/https?:\/\/[^\s)]+/gi, (match) => {
    try {
      const url = new URL(match);
      const path = url.pathname && url.pathname !== '/' ? clampText(url.pathname, 40) : '';
      return `${url.hostname}${path}`;
    } catch {
      return match;
    }
  });
}

function dedupeLines(input, maxLines = 30) {
  const seen = new Set();
  const result = [];
  for (const rawLine of String(input || '').split('\n')) {
    const normalized = rawLine.replace(/\s+/g, ' ').trim();
    if (!normalized) continue;
    if (seen.has(normalized)) continue;
    seen.add(normalized);
    result.push(rawLine.trim());
    if (result.length >= maxLines) break;
  }
  return result.join('\n');
}

function compactTextPayload(input, options = {}) {
  const original = String(input || '');
  let normalized = original;
  const strategies = [];

  if (/<[a-z!/][^>]*>/i.test(normalized)) {
    normalized = stripHtmlTags(normalized);
    strategies.push('html_to_text');
  }

  const shortenedUrls = shortenUrlText(normalized);
  if (shortenedUrls !== normalized) {
    normalized = shortenedUrls;
    strategies.push('url_shortening');
  }

  const deduped = dedupeLines(normalized, options.maxLines || 30);
  if (deduped && deduped !== normalized) {
    normalized = deduped;
    strategies.push('line_deduplication');
  }

  normalized = normalized.replace(/\s+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
  const finalText = clampText(normalized, options.maxChars || 1800);
  if (finalText.length < normalized.length) {
    strategies.push('length_clamp');
  }

  return {
    text: finalText,
    metrics: {
      inputChars: original.length,
      outputChars: finalText.length,
      reducedChars: Math.max(0, original.length - finalText.length),
      applied: finalText !== original,
      strategies,
    },
  };
}

module.exports = {
  compactTextPayload,
  stripHtmlTags,
};
