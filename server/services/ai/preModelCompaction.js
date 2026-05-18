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

function compactHttpResult(result) {
  const source = result && typeof result === 'object' ? result : {};
  const compactedBody = compactTextPayload(source.body || '', {
    maxChars: 2200,
    maxLines: 40,
  });
  return {
    result: {
      ...source,
      body: compactedBody.text,
    },
    metrics: compactedBody.metrics,
  };
}

function compactExtractResult(result) {
  const source = result && typeof result === 'object' ? result : {};
  const content = source.result ?? source.content ?? '';
  const compacted = compactTextPayload(content, {
    maxChars: 1800,
    maxLines: 35,
  });
  const next = { ...source };
  if (Object.prototype.hasOwnProperty.call(next, 'result')) next.result = compacted.text;
  if (Object.prototype.hasOwnProperty.call(next, 'content')) next.content = compacted.text;
  if (!Object.prototype.hasOwnProperty.call(next, 'result') && !Object.prototype.hasOwnProperty.call(next, 'content')) {
    next.result = compacted.text;
  }
  return {
    result: next,
    metrics: compacted.metrics,
  };
}

function compactSearchResult(result) {
  const source = result && typeof result === 'object' ? result : {};
  const results = Array.isArray(source.results)
    ? source.results.slice(0, 8).map((item) => ({
        ...item,
        description: clampText(shortenUrlText(item?.description || ''), 220),
      }))
    : [];
  const rawLength = JSON.stringify(source).length;
  const compactedLength = JSON.stringify({ ...source, results }).length;
  return {
    result: {
      ...source,
      results,
    },
    metrics: {
      inputChars: rawLength,
      outputChars: compactedLength,
      reducedChars: Math.max(0, rawLength - compactedLength),
      applied: compactedLength !== rawLength,
      strategies: compactedLength !== rawLength ? ['result_truncation'] : [],
    },
  };
}

function compactReadFileResult(result) {
  const source = result && typeof result === 'object' ? result : {};
  const compacted = compactTextPayload(source.content || '', {
    maxChars: 2200,
    maxLines: 40,
  });
  return {
    result: {
      ...source,
      content: compacted.text,
    },
    metrics: compacted.metrics,
  };
}

function compactPayloadForModel(toolName, result) {
  switch (String(toolName || '').trim()) {
    case 'http_request':
      return compactHttpResult(result);
    case 'browser_extract':
    case 'session_search':
      return compactExtractResult(result);
    case 'web_search':
      return compactSearchResult(result);
    case 'read_file':
      return compactReadFileResult(result);
    default:
      return {
        result,
        metrics: {
          inputChars: 0,
          outputChars: 0,
          reducedChars: 0,
          applied: false,
          strategies: [],
        },
      };
  }
}

module.exports = {
  compactPayloadForModel,
  compactTextPayload,
  stripHtmlTags,
};
