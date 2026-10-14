'use strict';

// Characters a model reads but a person cannot see. Unicode Tags (U+E0000–
// U+E007F) spell out ASCII invisibly and are the known carrier for hidden
// prompt injections and for smuggling data out; the variation selector
// supplement carries the same trick. Bidi controls reorder what a person sees
// (an approval prompt, a message preview) without changing what runs.
// Zero-width joiners stay: emoji sequences and several scripts need them.
const INVISIBLE_RE = /[\u{E0000}-\u{E007F}\u{E0100}-\u{E01EF}‪-‮⁦-⁩]/gu;

// Every untrusted span the harness puts into a prompt is fenced with a tag
// from this family. Content may not contain the tag itself, so it can neither
// close its fence early nor forge a sender block of its own.
const FENCE_TAG_RE = /<(\/?)(external_[a-z_]+|sender_identity)\b/gi;
const FENCED_SPAN_RE = /<(external_[a-z_]+)>[\s\S]*?<\/\1>/g;

function scrubInvisible(text) {
  return typeof text === 'string' ? text.replace(INVISIBLE_RE, '') : text;
}

// Strings anywhere inside a tool-call argument object, scrubbed. Returns the
// same reference when nothing changed.
function scrubInvisibleDeep(value) {
  if (typeof value === 'string') return scrubInvisible(value);
  if (Array.isArray(value)) {
    const next = value.map(scrubInvisibleDeep);
    return next.every((item, index) => item === value[index]) ? value : next;
  }
  if (value && typeof value === 'object') {
    let changed = false;
    const next = {};
    for (const [key, child] of Object.entries(value)) {
      next[key] = scrubInvisibleDeep(child);
      if (next[key] !== child) changed = true;
    }
    return changed ? next : value;
  }
  return value;
}

function neutralizeFenceTags(text) {
  return scrubInvisible(String(text ?? '')).replace(FENCE_TAG_RE, '&lt;$1$2');
}

function fenceUntrusted(tag, text) {
  return `<${tag}>\n${neutralizeFenceTags(text)}\n</${tag}>`;
}

function stripFencedSpans(text) {
  return String(text ?? '').replace(FENCED_SPAN_RE, '');
}

module.exports = {
  fenceUntrusted,
  neutralizeFenceTags,
  scrubInvisible,
  scrubInvisibleDeep,
  stripFencedSpans,
};
