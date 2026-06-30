'use strict';

const cheerio = require('cheerio');

// ─── Noise removal ───────────────────────────────────────────────────────────

const NOISE_TAGS = new Set([
  'script', 'style', 'noscript', 'nav', 'header', 'footer',
  'aside', 'iframe', 'dialog', 'template',
]);

const NOISE_ARIA_ROLES = new Set([
  'navigation', 'banner', 'contentinfo', 'complementary',
]);

// Matched against individual whitespace-separated class/id tokens (exact token match).
// This avoids false positives: "modal" matches class="modal" but not class="free-modal-container".
const NOISE_TOKENS = new Set([
  'sidebar', 'nav', 'navbar', 'navigation', 'modal', 'popup', 'cookie',
  'newsletter', 'menu', 'breadcrumb', 'breadcrumbs', 'social', 'share',
  'widget', 'promo', 'banner', 'ad', 'ads', 'advertisement', 'overlay',
  'toast', 'tooltip', 'flyout', 'drawer', 'offcanvas', 'skip-link',
  'toolbar', 'ribbon', 'announcement', 'notice',
]);

function hasNoiseToken(attr) {
  if (!attr) return false;
  for (const token of attr.split(/\s+/)) {
    if (NOISE_TOKENS.has(token.toLowerCase())) return true;
  }
  return false;
}

function removeNoise($) {
  // Remove by tag (keep <form role="search">)
  NOISE_TAGS.forEach((tag) => {
    if (tag === 'form') {
      $('form').filter((_, el) => $(el).attr('role') !== 'search').remove();
    } else {
      $(tag).remove();
    }
  });

  // Remove by ARIA role
  $('[role]').each((_, el) => {
    const role = ($(el).attr('role') || '').toLowerCase();
    if (NOISE_ARIA_ROLES.has(role)) $(el).remove();
  });

  // Remove by class/id token
  $('*').each((_, el) => {
    const $el = $(el);
    if (hasNoiseToken($el.attr('class')) || hasNoiseToken($el.attr('id'))) {
      $el.remove();
    }
  });
}

// ─── Metadata extraction ─────────────────────────────────────────────────────

function extractMetadata($, baseUrl) {
  const meta = (name) => $(`meta[name="${name}"]`).attr('content')
    || $(`meta[property="${name}"]`).attr('content') || '';

  const title = meta('og:title') || meta('twitter:title') || $('title').text().trim() || '';
  const description = meta('og:description') || meta('twitter:description') || meta('description') || '';
  const author = meta('author') || '';
  const url = meta('og:url') || baseUrl || '';

  return { title, description, author, url };
}

// ─── Readability-style content scoring ───────────────────────────────────────

const SCORE_BOOST_TAGS = new Set(['article', 'main']);
const SCORE_PENALTY_TAGS = new Set(['nav', 'aside', 'footer', 'header']);
const CANDIDATE_TAGS = ['article', 'main', '[role="main"]', 'div', 'section', 'td'];

function textLength($el) {
  return $el.text().replace(/\s+/g, ' ').trim().length;
}

function wordCount(text) {
  return text.replace(/\s+/g, ' ').trim().split(' ').filter(Boolean).length;
}

function linkDensity($, $el) {
  const total = textLength($el);
  if (!total) return 0;
  let linkText = 0;
  $el.find('a').each((_, a) => { linkText += $(a).text().trim().length; });
  return linkText / total;
}

function scoreElement($, el) {
  const $el = $(el);
  const tag = (el.tagName || '').toLowerCase();
  const text = textLength($el);
  if (text < 20) return 0;

  const outerLength = $.html($el).length;
  let score = outerLength > 0 ? text / outerLength : 0;

  // Penalise link-heavy elements (navigation-like)
  const ld = linkDensity($, $el);
  if (ld > 0.3) score *= (1 - ld);

  if (SCORE_BOOST_TAGS.has(tag)) score *= 1.25;
  if (SCORE_PENALTY_TAGS.has(tag)) score *= 0.75;

  return score;
}

function selectMainContent($) {
  // Fast path: semantic landmark elements
  for (const sel of ['article', 'main', '[role="main"]']) {
    const $el = $(sel).first();
    if ($el.length && wordCount($el.text()) > 100) return $el;
  }

  // Scoring path across likely containers
  let best = null;
  let bestScore = 0;

  $(CANDIDATE_TAGS.join(',')).each((_, el) => {
    const s = scoreElement($, el);
    if (s > bestScore) { bestScore = s; best = el; }
  });

  if (best) return $(best);

  // Body fallback
  return $('body');
}

// ─── Structured data / data islands ──────────────────────────────────────────

const SCHEMA_CONTENT_TYPES = new Set([
  'Article', 'NewsArticle', 'BlogPosting', 'Product', 'Recipe',
  'FAQPage', 'HowTo', 'Event', 'Review', 'Course',
]);

const SCHEMA_SKIP_TYPES = new Set([
  'WebSite', 'WebPage', 'SiteNavigationElement', 'BreadcrumbList',
  'SearchAction',
]);

const SCHEMA_LONG_FIELDS = new Set(['articleBody', 'body', 'text', 'description']);

function cleanSchemaItem(item) {
  if (!item || typeof item !== 'object') return item;
  const out = {};
  for (const [k, v] of Object.entries(item)) {
    if (SCHEMA_LONG_FIELDS.has(k) && typeof v === 'string' && v.length > 500) continue;
    out[k] = v;
  }
  return out;
}

function extractStructuredData($) {
  const items = [];
  let totalSize = 0;
  const SIZE_CAP = 16 * 1024;

  $('script[type="application/ld+json"]').each((_, el) => {
    if (totalSize >= SIZE_CAP) return;
    try {
      const raw = $(el).html() || '';
      const parsed = JSON.parse(raw);
      const arr = Array.isArray(parsed) ? parsed : [parsed];
      for (const item of arr) {
        const type = item['@type'];
        if (!type) continue;
        if (SCHEMA_SKIP_TYPES.has(type)) continue;
        if (!SCHEMA_CONTENT_TYPES.has(type)) continue;
        const cleaned = cleanSchemaItem(item);
        const chunk = JSON.stringify(cleaned);
        if (totalSize + chunk.length > SIZE_CAP) continue;
        items.push(cleaned);
        totalSize += chunk.length;
      }
    } catch { /* malformed JSON-LD — skip */ }
  });

  return items;
}

function extractNextData($) {
  try {
    const raw = $('#__NEXT_DATA__').html() || $('script[id="__NEXT_DATA__"]').html();
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    const pageProps = parsed?.props?.pageProps;
    if (!pageProps) return null;
    // Drop framework internals
    const { buildId, isFallback, ...rest } = pageProps; // eslint-disable-line no-unused-vars
    return Object.keys(rest).length ? rest : null;
  } catch { return null; }
}

// ─── HTML → Markdown conversion ───────────────────────────────────────────────

const BLOCK_TAGS = new Set([
  'p', 'div', 'section', 'article', 'blockquote', 'pre',
  'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'table', 'tr', 'td', 'th', 'thead', 'tbody', 'tfoot',
  'figure', 'figcaption', 'details', 'summary',
]);

function resolveUrl(href, base) {
  if (!href || href.startsWith('javascript:') || href.startsWith('#')) return null;
  try {
    return new URL(href, base).toString();
  } catch { return href; }
}

function langFromClass(cls) {
  if (!cls) return '';
  const m = cls.match(/language-(\S+)/);
  return m ? m[1] : '';
}

function bestImgSrc(el) {
  const candidates = ['data-src', 'data-lazy-src', 'data-original', 'src'];
  for (const attr of candidates) {
    const v = el.attribs?.[attr] || '';
    if (v && !v.startsWith('data:') && !v.startsWith('blob:')) return v;
  }
  return '';
}

const GENERIC_ALT = new Set(['logo', 'icon', 'image', 'img', 'photo', 'picture', 'banner', 'thumbnail']);

function isMeaningfulAlt(alt) {
  if (!alt || alt.length <= 10) return false;
  const lower = alt.toLowerCase().trim();
  return !GENERIC_ALT.has(lower);
}

// Collected links during conversion (per-call state passed via context)
function nodeToMd(node, ctx, depth = 0) {
  if (depth > 100) return node.type === 'text' ? (node.data || '') : '';

  if (node.type === 'text') {
    return node.data || '';
  }

  if (node.type !== 'tag') return '';

  const tag = (node.tagName || '').toLowerCase();
  const $el = ctx.$(node);
  const children = () => node.children
    .map((c) => nodeToMd(c, ctx, depth + 1))
    .join('');

  // Headings
  const headingMatch = tag.match(/^h([1-6])$/);
  if (headingMatch) {
    const hashes = '#'.repeat(parseInt(headingMatch[1], 10));
    const text = $el.text().trim();
    if (!text) return '';
    return `\n\n${hashes} ${text}\n\n`;
  }

  // Paragraphs and generic blocks
  if (tag === 'p') {
    const inner = children().trim();
    return inner ? `\n\n${inner}\n\n` : '';
  }

  if (tag === 'br') return '\n';

  if (tag === 'hr') return '\n\n---\n\n';

  // Blockquote
  if (tag === 'blockquote') {
    const inner = children().trim();
    if (!inner) return '';
    return '\n\n' + inner.split('\n').map((l) => `> ${l}`).join('\n') + '\n\n';
  }

  // Code blocks
  if (tag === 'pre') {
    const codeEl = $el.find('code').first();
    const lang = langFromClass(codeEl.attr('class') || $el.attr('class') || '');
    const code = (codeEl.length ? codeEl.text() : $el.text()).trim();
    ctx.inCode = true;
    const result = `\n\n\`\`\`${lang}\n${code}\n\`\`\`\n\n`;
    ctx.inCode = false;
    return result;
  }

  if (tag === 'code' && !ctx.inCode) {
    const text = $el.text();
    return `\`${text}\``;
  }

  // Inline emphasis
  if (tag === 'strong' || tag === 'b') {
    const inner = children().trim();
    return inner ? `**${inner}**` : '';
  }
  if (tag === 'em' || tag === 'i') {
    const inner = children().trim();
    return inner ? `*${inner}*` : '';
  }

  // Links
  if (tag === 'a') {
    const href = resolveUrl(node.attribs?.href || '', ctx.baseUrl);
    const text = children().trim() || $el.text().trim();
    if (!text) return '';
    if (href) ctx.links.push({ text, href });
    return text;
  }

  // Images
  if (tag === 'img') {
    const alt = (node.attribs?.alt || '').trim();
    if (isMeaningfulAlt(alt)) return alt;
    // Track decorative logos for collapsing
    if (alt && GENERIC_ALT.has(alt.toLowerCase())) {
      ctx.consecutiveLogos.push(alt);
    }
    return '';
  }

  // Lists
  if (tag === 'ul' || tag === 'ol') {
    ctx.listStack.push(tag);
    const inner = children().trim();
    ctx.listStack.pop();
    return inner ? `\n\n${inner}\n\n` : '';
  }

  if (tag === 'li') {
    const isOrdered = ctx.listStack[ctx.listStack.length - 1] === 'ol';
    const inner = children().trim();
    if (!inner) return '';
    if (isOrdered) {
      ctx.listIndex = (ctx.listIndex || 0) + 1;
      return `${ctx.listIndex}. ${inner}\n`;
    }
    return `- ${inner}\n`;
  }

  // Tables — render as pipe tables or just extract text
  if (tag === 'table') {
    return `\n\n${$el.text().replace(/\s+/g, ' ').trim()}\n\n`;
  }

  // Details/summary
  if (tag === 'summary') {
    return `**${children().trim()}**\n`;
  }

  // Figcaption
  if (tag === 'figcaption') {
    const inner = children().trim();
    return inner ? `\n*${inner}*\n` : '';
  }

  // Generic block-level elements: add newlines around children
  if (BLOCK_TAGS.has(tag)) {
    const inner = children();
    return inner ? `\n${inner}\n` : '';
  }

  return children();
}

function htmlToMarkdown($, $root, baseUrl) {
  const ctx = {
    $,
    baseUrl,
    links: [],
    listStack: [],
    listIndex: 0,
    inCode: false,
    consecutiveLogos: [],
  };

  let md = '';
  $root.contents().each((_, node) => {
    md += nodeToMd(node, ctx, 0);
  });

  return { md, links: ctx.links, logoAlts: ctx.consecutiveLogos };
}

// ─── LLM optimization pipeline ───────────────────────────────────────────────

const CSS_TOKEN_RE = /^[a-z-]+(-[a-z0-9]+)*$/;
const PROSE_SIGNAL_RE = /[A-Z]|[.!?,;:]|[0-9]{4}|\s[a-z]{4,}\s/;

function isCssClassLine(line) {
  const tokens = line.trim().split(/\s+/);
  if (tokens.length < 3) return false;
  const allCss = tokens.every((t) => CSS_TOKEN_RE.test(t));
  if (!allCss) return false;
  // Keep if it looks like prose mixed with class-style words
  return !PROSE_SIGNAL_RE.test(line);
}

const STAT_ONLY_RE = /^[\d,.+%$€£¥km bBMKGT/×x-]+$/i;

function mergeStats(lines) {
  const out = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const next = lines[i + 1];
    if (STAT_ONLY_RE.test(line.trim()) && next && next.trim().length > 0 && next.trim().split(' ').length <= 4) {
      out.push(`${line.trim()} ${next.trim()}`);
      i++; // skip next
    } else {
      out.push(line);
    }
  }
  return out;
}

function stripEmphasis(text) {
  let inCode = false;
  return text.replace(/(`{1,3})([\s\S]*?)\1/g, (m) => { inCode = !inCode; return m; })
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/\*([^*]+)\*/g, '$1');
}

// Actually do it line-aware to protect code blocks
function stripEmphasisSafe(text) {
  const lines = text.split('\n');
  const out = [];
  let inFence = false;
  for (const line of lines) {
    if (/^```/.test(line.trim())) { inFence = !inFence; out.push(line); continue; }
    if (inFence) { out.push(line); continue; }
    out.push(line.replace(/\*\*([^*\n]+)\*\*/g, '$1').replace(/\*([^*\n]+)\*/g, '$1'));
  }
  return out.join('\n');
}

function deduplicateParagraphs(text) {
  const paragraphs = text.split(/\n{2,}/);
  const seen = new Set();
  const out = [];
  for (const para of paragraphs) {
    const normalized = para.replace(/\s+/g, ' ').trim();
    if (!normalized) { out.push(para); continue; }
    // Near-duplicate: first 60 chars prefix
    const prefix = normalized.slice(0, 60);
    if (seen.has(prefix)) continue;
    seen.add(prefix);
    out.push(para);
  }
  return out.join('\n\n');
}

function filterCssLines(text) {
  const lines = text.split('\n');
  const out = [];
  let inFence = false;
  for (const line of lines) {
    if (/^```/.test(line.trim())) { inFence = !inFence; out.push(line); continue; }
    if (inFence) { out.push(line); continue; }
    if (isCssClassLine(line)) continue;
    out.push(line);
  }
  return out.join('\n');
}

function buildLinksSection(links) {
  const seen = new Set();
  const unique = [];
  for (const { text, href } of links) {
    if (!href || seen.has(href)) continue;
    if (href.startsWith('#') || href.startsWith('javascript:')) continue;
    seen.add(href);
    unique.push(`- ${text}: ${href}`);
  }
  if (!unique.length) return '';
  return `\n\n## Links\n${unique.join('\n')}`;
}

function buildStructuredDataSection(items) {
  if (!items.length) return '';
  return `\n\n## Structured Data\n\`\`\`json\n${JSON.stringify(items, null, 2)}\n\`\`\``;
}

function optimizeForLLM(rawMd, { metadata, links, structuredData, logoAlts }) {
  // Step 1: metadata header
  const headerLines = [];
  if (metadata.url) headerLines.push(`> URL: ${metadata.url}`);
  if (metadata.title) headerLines.push(`> Title: ${metadata.title}`);
  if (metadata.description) headerLines.push(`> Description: ${metadata.description}`);
  if (metadata.author) headerLines.push(`> Author: ${metadata.author}`);
  const wc = wordCount(rawMd);
  headerLines.push(`> Word count: ${wc}`);
  const header = headerLines.join('\n');

  let body = rawMd;

  // Step 2: image stripping — inline ![alt](src) already resolved during conversion
  // (we output alt text directly from nodeToMd — nothing left to strip)
  // Collapse consecutive decorative logo alts if any leaked in
  if (logoAlts.length > 1) {
    body = `${logoAlts.join(', ')}\n\n${body}`;
  }

  // Step 3: emphasis stripping
  body = stripEmphasisSafe(body);

  // Step 4: link normalization — links already extracted, body has plain text from nodeToMd

  // Step 5: deduplication
  body = deduplicateParagraphs(body);

  // Step 6: stat merging
  const statLines = mergeStats(body.split('\n'));
  body = statLines.join('\n');

  // Step 7: whitespace collapse
  body = body
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/\t/g, '  ')
    .trim();

  // Step 8: CSS class line filtering
  body = filterCssLines(body);

  // Step 9: structured data section
  const linksSection = buildLinksSection(links);
  const structuredSection = buildStructuredDataSection(structuredData);

  return `${header}\n\n${body}${linksSection}${structuredSection}`;
}

// ─── H1 recovery ─────────────────────────────────────────────────────────────

function recoverH1(allH1Text, extractedMd) {
  if (!allH1Text) return extractedMd;
  if (extractedMd.includes(allH1Text.trim())) return extractedMd;
  return `# ${allH1Text.trim()}\n\n${extractedMd}`;
}

// ─── Public API ──────────────────────────────────────────────────────────────

function extractForLLM(html, options = {}) {
  const { url = '' } = options;
  const strategies = [];

  let $;
  try {
    $ = cheerio.load(html || '', { decodeEntities: true });
  } catch {
    return { markdown: String(html || '').slice(0, 4000), metadata: {}, wordCount: 0, strategies: ['fallback_raw'] };
  }

  // Capture H1 before noise removal (it might be in a hero <header>)
  const originalH1 = $('h1').first().text().trim();

  // Capture structured data and Next.js data islands before noise removal
  const structuredData = extractStructuredData($);
  const nextData = extractNextData($);

  // Metadata
  const metadata = extractMetadata($, url);

  // Phase 1: noise removal
  removeNoise($);

  // Phase 2: main content selection
  let $content = selectMainContent($);
  let extractedMd;
  let conversionResult;

  conversionResult = htmlToMarkdown($, $content, url);
  extractedMd = conversionResult.md;
  const wc = wordCount(extractedMd);

  if (wc < 100) {
    // Sparse recovery: retry against full body
    $content = $('body');
    conversionResult = htmlToMarkdown($, $content, url);
    extractedMd = conversionResult.md;
    strategies.push('sparse_recovery');
  } else {
    strategies.push('readability_score');
  }

  // H1 recovery
  extractedMd = recoverH1(originalH1, extractedMd);

  // Data island fallback when content is still sparse
  const finalWc = wordCount(extractedMd);
  let islandData = [];
  if (finalWc < 200) {
    if (structuredData.length) {
      islandData = structuredData;
      strategies.push('data_island_schema');
    }
    if (nextData) {
      try {
        const nextStr = JSON.stringify(nextData, null, 2);
        if (nextStr.length < 8000) {
          extractedMd += `\n\n${nextStr}`;
          strategies.push('data_island_next');
        }
      } catch { /* skip */ }
    }
  }

  // Phase 6: LLM optimization pipeline
  const optimized = optimizeForLLM(extractedMd, {
    metadata,
    links: conversionResult.links,
    structuredData: islandData.length ? islandData : structuredData,
    logoAlts: conversionResult.logoAlts,
  });

  return {
    markdown: optimized,
    metadata,
    wordCount: finalWc,
    strategies,
  };
}

module.exports = { extractForLLM };
