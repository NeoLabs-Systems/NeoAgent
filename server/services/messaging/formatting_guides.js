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
  telnyx: {
    spokenOnly: true,
    inlineCode: false,
  }
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
    'Write in a compact, natural chat style.',
    'Prefer short paragraphs and only use simple single-level lists when they improve clarity.',
    'Avoid tables, raw HTML, and document-style formatting.',
    'The runtime will adapt the final text to the destination platform.'
  ].map((line) => `- ${line}`).join('\n');
  return [intro, body].filter(Boolean).join('\n');
}

function buildSendMessageFormattingReference() {
  return [
    'Use one plain chat-style reply.',
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

function normalizeVisualMarkdown(text, { inlineCode = true } = {}) {
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

  if (!inlineCode) {
    value = value.replace(/`([^`]+)`/g, '$1');
    value = value.replace(/\*\*(.*?)\*\*/g, '$1');
    value = value.replace(/__(.*?)__/g, '$1');
    value = value.replace(/\*(.*?)\*/g, '$1');
    value = value.replace(/_(.*?)_/g, '$1');
    value = value.replace(/~~(.*?)~~/g, '$1');
  }

  return value;
}

function adaptWhatsAppFormatting(text) {
  return normalizeVisualMarkdown(text, { inlineCode: true })
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function adaptSpokenFormatting(text) {
  return normalizeVisualMarkdown(text, { inlineCode: false })
    .replace(/(?:^|\n)-\s+/g, ' ')
    .replace(/\n+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeOutgoingMessageForPlatform(platform, content, options = {}) {
  const profile = getPlatformFormattingProfile(platform);
  let text = String(content || '');

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

  if (profile.spokenOnly) {
    return adaptSpokenFormatting(text);
  }

  return text;
}

function splitOutgoingMessageForPlatform(platform, content) {
  const profile = getPlatformFormattingProfile(platform);
  const normalized = normalizeOutgoingMessageForPlatform(platform, content, {
    stripNoResponseMarker: false
  });

  if (!normalized) return [];
  if (profile.spokenOnly) return [normalized];

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
