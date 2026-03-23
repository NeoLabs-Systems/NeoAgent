const { sanitizeStreamingToolCallText } = require('./toolCallSalvage');

const HAN_CHAR_REGEX = /\p{Script=Han}/gu;
const LATIN_CHAR_REGEX = /\p{Script=Latin}/gu;
const LETTER_CHAR_REGEX = /\p{L}/gu;
const HAN_RUN_REGEX = /[\p{Script=Han}\u3000-\u303F]+/gu;
const MARKDOWN_CODE_SPAN_REGEX = /(```[\s\S]*?```|`[^`\n]+`)/g;

function countMatches(text, regex) {
  const matches = text.match(regex);
  return matches ? matches.length : 0;
}

function shouldStripIncidentalHan(text, model) {
  if (model !== 'MiniMax-M2.7') return false;

  const hanCount = countMatches(text, HAN_CHAR_REGEX);
  if (hanCount === 0) return false;
  if (hanCount > 24) return false;

  const latinCount = countMatches(text, LATIN_CHAR_REGEX);
  if (latinCount < 20) return false;

  const letterCount = countMatches(text, LETTER_CHAR_REGEX);
  if (letterCount > 0 && (hanCount / letterCount) > 0.18) return false;

  return true;
}

function sanitizePlainText(text) {
  return text
    .replace(/([\p{L}\p{N}])[\p{Script=Han}\u3000-\u303F]+([\p{L}\p{N}])/gu, '$1 $2')
    .replace(HAN_RUN_REGEX, '')
    .replace(/[ \t]{2,}/g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n[ \t]+/g, '\n')
    .replace(/[ \t]+([,.;:!?)\]}])/g, '$1')
    .replace(/([([{])\s+/g, '$1');
}

function sanitizeMarkdownAware(text) {
  return text
    .split(MARKDOWN_CODE_SPAN_REGEX)
    .map((part) => {
      if (!part) return part;
      if (part.startsWith('```') || part.startsWith('`')) return part;
      return sanitizePlainText(part);
    })
    .join('');
}

function sanitizeModelOutput(text, options = {}) {
  if (typeof text !== 'string' || text.length === 0) return text;

  let sanitized = text;

  if (options.model === 'MiniMax-M2.7' && (sanitized.includes('<invoke') || sanitized.includes(':tool_call'))) {
    sanitized = sanitizeStreamingToolCallText(sanitized);
  }

  if (!shouldStripIncidentalHan(sanitized, options.model)) return sanitized;
  return sanitizeMarkdownAware(sanitized);
}

module.exports = {
  sanitizeModelOutput
};
