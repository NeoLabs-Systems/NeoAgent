'use strict';

// Applies exact-text replacements to a file body. Each oldText must match one
// location unless the edit opts into replaceAll; an ambiguous match is
// reported instead of silently rewriting every occurrence.
function applyTextEdits(content, edits = []) {
  let next = String(content);
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
    next = parts.join(String(edit.newText || ''));
    modified = true;
    report.push({ success: true, replaced: matches, edit: preview });
  }
  return { content: next, modified, report };
}

module.exports = { applyTextEdits };
