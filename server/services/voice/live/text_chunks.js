'use strict';

// Live providers cap each injected context message (GPT-Live: 500 tokens), so a
// long task result is sent as consecutive sentence-aligned parts.
function splitForAppend(text, maxChars) {
  const value = String(text || '').trim();
  if (!value) return [];
  if (value.length <= maxChars) return [value];
  const parts = [];
  let current = '';
  for (const sentence of value.split(/(?<=[.!?])\s+/)) {
    if (current && current.length + sentence.length + 1 > maxChars) {
      parts.push(current);
      current = '';
    }
    if (sentence.length > maxChars) {
      for (let index = 0; index < sentence.length; index += maxChars) {
        parts.push(sentence.slice(index, index + maxChars));
      }
      continue;
    }
    current = current ? `${current} ${sentence}` : sentence;
  }
  if (current) parts.push(current);
  return parts;
}

module.exports = {
  splitForAppend,
};
