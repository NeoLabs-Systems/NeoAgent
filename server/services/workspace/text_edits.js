'use strict';

// Applies exact-text replacements to a file body. Each oldText must match one
// location unless the edit opts into replaceAll; an ambiguous match is
// reported instead of silently rewriting every occurrence.
function coerceWritableText(value) {
  if (value == null) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value) && value.every((item) => typeof item === 'string')) {
    return value.join('\n');
  }
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return '';
  }
}

function applyTextEdits(content, edits = []) {
  let next = coerceWritableText(content);
  let modified = false;
  const report = [];
  for (const edit of Array.isArray(edits) ? edits : []) {
    if (typeof edit?.oldText !== 'string' || !edit.oldText) {
      report.push({ success: false, error: 'oldText is required.' });
      continue;
    }
    const preview = `${edit.oldText.slice(0, 50)}...`;
    const parts = next.split(edit.oldText);
    const matches = parts.length - 1;
    if (matches === 0) {
      report.push({ success: false, error: 'Target text not found.', edit: preview });
      continue;
    }
    if (matches > 1 && edit.replaceAll !== true) {
      report.push({
        success: false,
        error: `Target text matches ${matches} locations. Include more surrounding context or set replace_all: true.`,
        edit: preview,
      });
      continue;
    }
    next = parts.join(coerceWritableText(edit.newText));
    modified = true;
    report.push({ success: true, replaced: matches, edit: preview });
  }
  return { content: next, modified, report };
}

module.exports = { applyTextEdits, coerceWritableText };
