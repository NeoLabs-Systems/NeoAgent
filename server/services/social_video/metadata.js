'use strict';

function decodeHtmlEntities(text) {
  return String(text || '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/gi, "'")
    .trim();
}

function collapseWhitespace(text) {
  return String(text || '').replace(/\s+/g, ' ').trim();
}

function readHtmlTitle(html) {
  const match = String(html || '').match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  return match ? collapseWhitespace(decodeHtmlEntities(match[1])) : '';
}

function readCanonicalUrl(html) {
  const match = String(html || '').match(
    /<link\b(?=[^>]*\brel=["'][^"']*canonical[^"']*["'])(?=[^>]*\bhref=["']([^"']+)["'])[^>]*>/i,
  );
  return match ? match[1].trim() : '';
}

function readMetaTagContent(html, key, attr = 'name') {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(
    `<meta[^>]+${attr}=["']${escaped}["'][^>]*content=["']([\\s\\S]*?)["'][^>]*>|<meta[^>]+content=["']([\\s\\S]*?)["'][^>]*${attr}=["']${escaped}["'][^>]*>`,
    'i',
  );
  const match = String(html || '').match(pattern);
  const content = match ? match[1] || match[2] || '' : '';
  return collapseWhitespace(decodeHtmlEntities(content));
}

function extractPublicMetadataFromHtml(html, fallbackUrl = '') {
  const title = readMetaTagContent(html, 'og:title', 'property')
    || readMetaTagContent(html, 'twitter:title', 'name')
    || readHtmlTitle(html);
  const description = readMetaTagContent(html, 'description', 'name')
    || readMetaTagContent(html, 'og:description', 'property')
    || readMetaTagContent(html, 'twitter:description', 'name');
  const canonicalUrl = readCanonicalUrl(html) || fallbackUrl;
  return {
    title,
    description,
    canonicalUrl,
  };
}

module.exports = {
  collapseWhitespace,
  decodeHtmlEntities,
  extractPublicMetadataFromHtml,
  readCanonicalUrl,
  readHtmlTitle,
  readMetaTagContent,
};
