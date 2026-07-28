const PLATFORM_FORMATTING = {
  default: {
    spokenOnly: false,
    inlineCode: true,
  },
  whatsapp: {
    spokenOnly: false,
    inlineCode: true,
  },
  telegram: {
    spokenOnly: false,
    inlineCode: true,
  },
  discord: {
    spokenOnly: false,
    inlineCode: true,
  },
};

function getPlatformFormattingProfile(platform) {
  const key = String(platform || '').trim().toLowerCase();
  return PLATFORM_FORMATTING[key] || PLATFORM_FORMATTING.default;
}

function buildPlatformFormattingGuide(_platform, options = {}) {
  const intro = options.intro === false
    ? ''
    : 'Reply formatting guide:';
  const body = [
    'Prefer short paragraphs or multi-line chat bursts over document structure.',
    'Use simple single-level lists only when they genuinely improve clarity.',
    'Avoid tables, raw HTML, and formal report formatting in chat replies.',
    'A blank line may be delivered as a separate message bubble, so use one only for an intentional conversational beat.',
    'The runtime will adapt the final text to the destination platform.'
  ].map((line) => `- ${line}`).join('\n');
  return [intro, body].filter(Boolean).join('\n');
}

function buildSendMessageFormattingReference() {
  return [
    'Use one plain chat-style reply unless intentional bubble breaks improve it.',
    'The runtime adapts final formatting for the destination platform.',
    'For WhatsApp, media attachments still use media_path.'
  ].join(' ');
}

function stripRawHtml(text) {
  return text.replace(/<\/?[^>]+>/g, '');
}

function collapseTableRow(line) {
  const cells = line
    .split('|')
    .map((cell) => cell.trim())
    .filter(Boolean);
  return cells.join(' - ');
}

function normalizeVisualMarkdown(text) {
  let value = String(text || '');

  value = value.replace(/```([^\n`]*)\n?([\s\S]*?)```/g, (_, _lang, code) => `\n${String(code || '').trim()}\n`);
  value = value.replace(/^#{1,6}\s+/gm, '');
  value = value.replace(/^>\s?/gm, '');
  value = value.replace(/^\s*[-*+]\s+/gm, '- ');
  value = value.replace(/^\s*\d+\.\s+/gm, '- ');
  value = value.replace(/^\s*\|?(?:\s*:?-+:?\s*\|)+\s*$/gm, '');
  value = value.replace(/^(.*\|.*)$/gm, (line) => collapseTableRow(line));
  value = value.replace(/\*\*(.*?)\*\*/g, '*$1*');
  value = value.replace(/__(.*?)__/g, '_$1_');

  return value;
}

function adaptWhatsAppFormatting(text) {
  return normalizeVisualMarkdown(text)
    .replace(/[ \t]*(?:\\n|\/n(?![a-zA-Z0-9_]))[ \t]*/g, '\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function coerceMessageContent(content) {
  if (typeof content === 'string') return content;
  if (content == null) return '';
  if (typeof content === 'number' || typeof content === 'boolean' || typeof content === 'bigint') {
    return String(content);
  }
  if (typeof content !== 'object') return String(content || '');

  for (const key of ['text', 'content', 'message', 'summary']) {
    if (typeof content[key] === 'string' && content[key].trim()) {
      return content[key];
    }
  }

  if (content.result != null && content.result !== content) {
    return coerceMessageContent(content.result);
  }

  try {
    return JSON.stringify(content, null, 2);
  } catch {
    return String(content || '');
  }
}

function normalizeOutgoingMessageForPlatform(platform, content, options = {}) {
  let text = coerceMessageContent(content);

  if (options.stripNoResponseMarker !== false) {
    text = text.replace(/\[NO RESPONSE\]/gi, '');
  }

  text = text
    .replace(/\r\n/g, '\n');
  text = stripRawHtml(text)
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  if (String(platform || '').trim().toLowerCase() === 'whatsapp') {
    text = adaptWhatsAppFormatting(text);
  }

  return text;
}

function splitOutgoingMessageForPlatform(platform, content) {
  const normalized = normalizeOutgoingMessageForPlatform(platform, content, {
    stripNoResponseMarker: false
  });

  if (!normalized) return [];

  const chunks = normalized
    .split(/\n{2,}/)
    .map((chunk) => chunk.trim())
    .filter(Boolean);

  return chunks.length ? chunks : [normalized];
}

module.exports = {
  buildPlatformFormattingGuide,
  buildSendMessageFormattingReference,
  getPlatformFormattingProfile,
  normalizeOutgoingMessageForPlatform,
  splitOutgoingMessageForPlatform,
};
