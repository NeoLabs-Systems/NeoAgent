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

const MAX_NEARBY_LINES = 5;
const MAX_LISTED_LOCATIONS = 5;
const MAX_NEARBY_CHARS = 160;

function numberedLine(lines, index) {
  return `${index + 1}: ${lines[index].slice(0, MAX_NEARBY_CHARS)}`;
}

function sharedWords(line, wanted) {
  return line.split(/\W+/).filter((word) => word.length > 2 && wanted.has(word)).length;
}

// Where the model most likely meant, so it can correct the text without another
// read: the line holding the first line of oldText, or failing that the line
// sharing the most words with it.
function closestLineIndex(lines, oldText) {
  const first = oldText.split('\n').map((line) => line.trim()).find(Boolean);
  if (!first) return -1;
  const exact = lines.findIndex((line) => line.trim() === first);
  if (exact >= 0) return exact;
  const partial = lines.findIndex((line) => line.includes(first));
  if (partial >= 0) return partial;
  const wanted = new Set(first.split(/\W+/).filter((word) => word.length > 2));
  let best = -1;
  let bestScore = 0;
  lines.forEach((line, index) => {
    const score = sharedWords(line, wanted);
    if (score > bestScore) {
      best = index;
      bestScore = score;
    }
  });
  return best;
}

function nearbyLines(content, oldText) {
  const lines = content.split('\n');
  const center = closestLineIndex(lines, oldText);
  if (center < 0) return [];
  const start = Math.max(0, center - Math.floor(MAX_NEARBY_LINES / 2));
  const end = Math.min(lines.length, start + MAX_NEARBY_LINES);
  const shown = [];
  for (let index = start; index < end; index += 1) shown.push(numberedLine(lines, index));
  return shown;
}

function matchLocations(content, parts, separatorLength) {
  const lines = content.split('\n');
  const locations = [];
  let offset = 0;
  for (const part of parts.slice(0, Math.min(parts.length - 1, MAX_LISTED_LOCATIONS))) {
    offset += part.length;
    locations.push(numberedLine(lines, content.slice(0, offset).split('\n').length - 1));
    offset += separatorLength;
  }
  return locations;
}

// A file with CRLF line endings still matches text written with plain newlines,
// and keeps its line endings.
function matchingTexts(content, edit) {
  const newText = coerceWritableText(edit.newText);
  if (content.includes(edit.oldText) || !content.includes('\r\n') || !edit.oldText.includes('\n')) {
    return { oldText: edit.oldText, newText };
  }
  const crlf = (text) => text.replace(/\r?\n/g, '\r\n');
  return { oldText: crlf(edit.oldText), newText: crlf(newText) };
}

function editProblem(edit) {
  if (typeof edit?.oldText !== 'string' || !edit.oldText) return 'oldText is required.';
  if (edit.newText == null) return 'newText is required; use an empty string to delete the text.';
  if (coerceWritableText(edit.newText) === edit.oldText) return 'oldText and newText are the same, so this changes nothing.';
  return '';
}

/**
 * Applies edits in order, each to the result of the one before. All or nothing:
 * if any edit cannot apply, the content comes back unchanged and modified is
 * false, so a partly applied change never reaches the file. Every edit is still
 * checked, so one report names everything that needs correcting.
 */
function applyTextEdits(content, edits = []) {
  const original = coerceWritableText(content);
  const list = Array.isArray(edits) ? edits : [];
  if (!list.length) {
    return { content: original, modified: false, report: [{ success: false, error: 'edits must list at least one change.' }] };
  }
  let next = original;
  const report = [];
  let failed = false;
  for (const edit of list) {
    const problem = editProblem(edit);
    if (problem) {
      failed = true;
      report.push({ success: false, error: problem });
      continue;
    }
    const preview = `${edit.oldText.slice(0, 50)}...`;
    const { oldText, newText } = matchingTexts(next, edit);
    const parts = next.split(oldText);
    const matches = parts.length - 1;
    if (matches === 0) {
      failed = true;
      const nearby = nearbyLines(next, edit.oldText);
      report.push({
        success: false,
        error: 'Target text not found.',
        edit: preview,
        ...(nearby.length ? { nearby_lines: nearby } : {}),
      });
      continue;
    }
    if (matches > 1 && edit.replaceAll !== true) {
      failed = true;
      report.push({
        success: false,
        error: `Target text matches ${matches} locations. Include more surrounding context or set replace_all: true.`,
        edit: preview,
        locations: matchLocations(next, parts, oldText.length),
      });
      continue;
    }
    const line = next.slice(0, parts[0].length).split('\n').length;
    next = parts.join(newText);
    report.push({ success: true, replaced: matches, line, edit: preview });
  }
  if (!failed) return { content: next, modified: true, report };
  return {
    content: original,
    modified: false,
    // An edit that could apply was still not written; the report must not imply it was.
    report: report.map((entry) => (entry.success
      ? { success: false, applied: false, edit: entry.edit, note: 'Valid, but not written: another edit in this call failed, and edits apply all or nothing.' }
      : entry)),
  };
}

module.exports = { applyTextEdits, coerceWritableText };
