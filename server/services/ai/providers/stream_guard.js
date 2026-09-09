'use strict';

// maxBytes is a safety ceiling on one streamed argument, far above anything a
// model can emit in a turn; the repetition check is what catches runaways.
const DEFAULTS = Object.freeze({
  maxBytes: 2 * 1024 * 1024,
  windowBytes: 1024,
  checkEveryBytes: 256,
  maxPeriod: 64,
});

// A window is degenerate when it is one short unit repeated end to end and
// that unit carries no letters or digits. Real data can be periodic too — a
// zero-filled array, a rule of dashes — so anything alphanumeric is left alone;
// the loops small models fall into are whitespace and punctuation.
function repeatingPeriod(text, maxPeriod) {
  for (let period = 1; period <= maxPeriod; period += 1) {
    if (text.slice(period) !== text.slice(0, text.length - period)) continue;
    return /[A-Za-z0-9]/.test(text.slice(0, period)) ? 0 : period;
  }
  return 0;
}

// Watches one growing model output (a tool-call argument string or the reply
// text) and reports when it has stopped being a real answer: either the byte
// ceiling is gone, or the latest window is a repeating whitespace/punctuation
// pattern — the way small models fail when they lock into a loop and keep
// streaming until max_tokens.
function createStreamGuard(options = {}) {
  const { maxBytes, windowBytes, checkEveryBytes, maxPeriod } = { ...DEFAULTS, ...options };
  let buffer = '';
  let checkedLength = 0;

  return {
    feed(delta) {
      if (!delta) return null;
      buffer += delta;
      if (buffer.length > maxBytes) {
        return { reason: 'output_limit', bytes: buffer.length };
      }
      if (buffer.length < windowBytes || buffer.length - checkedLength < checkEveryBytes) return null;
      checkedLength = buffer.length;
      const period = repeatingPeriod(buffer.slice(-windowBytes), maxPeriod);
      if (period) {
        return { reason: 'degenerate_repetition', bytes: buffer.length, period };
      }
      return null;
    },
  };
}

const NUMBER_PREFIX = /^-?(0|[1-9]\d*)?(\.\d*)?([eE][+-]?\d*)?$/;
const NUMBER_FULL = /^-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?$/;
const LITERALS = ['true', 'false', 'null'];

// Incremental check on a streamed tool-call argument string: it must remain
// a prefix of valid JSON, and every top-level key must be one the tool
// declares. Runaway argument streams go wrong within the first few bytes
// (`{"content=` ...) and are usually still well-formed JSON, so the key check
// is what ends them immediately instead of after a kilobyte of repetition.
function createJsonPrefixTracker({ isKnownKey = () => true } = {}) {
  const stack = [];
  let expect = 'value';
  let inString = false;
  let stringIsKey = false;
  let keyText = '';
  let escape = false;
  let unicodeLeft = 0;
  let literal = '';
  let valid = true;
  let reason = null;

  const afterValue = () => {
    expect = stack.length ? 'sep' : 'done';
  };
  const closeString = () => {
    inString = false;
    if (!stringIsKey) { afterValue(); return true; }
    expect = 'colon';
    if (stack.length === 1 && !isKnownKey(keyText)) {
      reason = 'unknown_argument_key';
      return false;
    }
    return true;
  };
  const finishLiteral = () => {
    const ok = /^[-\d]/.test(literal) ? NUMBER_FULL.test(literal) : LITERALS.includes(literal);
    literal = '';
    if (ok) afterValue();
    return ok;
  };
  const feedChar = (ch) => {
    if (inString) {
      if (stringIsKey && ch !== '"') keyText += ch;
      if (unicodeLeft > 0) {
        if (!/[0-9a-fA-F]/.test(ch)) return false;
        unicodeLeft -= 1;
        return true;
      }
      if (escape) {
        escape = false;
        if (ch === 'u') { unicodeLeft = 4; return true; }
        return '"\\/bfnrt'.includes(ch);
      }
      if (ch === '\\') { escape = true; return true; }
      if (ch === '"') return closeString();
      return true;
    }
    if (literal) {
      const next = literal + ch;
      const stillPrefix = /^[-\d]/.test(next)
        ? NUMBER_PREFIX.test(next)
        : LITERALS.some((word) => word.startsWith(next));
      if (stillPrefix) { literal = next; return true; }
      if (!finishLiteral()) return false;
      // fall through: ch terminates the literal and must be handled itself
    }
    if (/\s/.test(ch)) return true;
    if (expect === 'done') return false;
    const top = stack[stack.length - 1];
    // 'firstKey' / 'firstValue' right after an opener also allow the closer,
    // so `{}` and `[]` pass while `{"a":1,}` and `[1,]` do not.
    const wantsValue = expect === 'value' || expect === 'firstValue';
    const wantsKey = expect === 'key' || expect === 'firstKey';
    switch (ch) {
      case '{':
        if (!wantsValue) return false;
        stack.push('object'); expect = 'firstKey'; return true;
      case '[':
        if (!wantsValue) return false;
        stack.push('array'); expect = 'firstValue'; return true;
      case '"':
        if (!wantsValue && !wantsKey) return false;
        inString = true; stringIsKey = wantsKey; keyText = ''; return true;
      case ':':
        if (expect !== 'colon') return false;
        expect = 'value'; return true;
      case ',':
        if (expect !== 'sep') return false;
        expect = top === 'object' ? 'key' : 'value'; return true;
      case '}':
        if (top !== 'object' || (expect !== 'sep' && expect !== 'firstKey')) return false;
        stack.pop(); afterValue(); return true;
      case ']':
        if (top !== 'array' || (expect !== 'sep' && expect !== 'firstValue')) return false;
        stack.pop(); afterValue(); return true;
      default:
        if (!wantsValue || !/[-\dtfn]/.test(ch)) return false;
        literal = ch; return true;
    }
  };

  return {
    feed(delta) {
      if (!valid) return false;
      for (const ch of String(delta || '')) {
        if (!feedChar(ch)) {
          valid = false;
          reason = reason || 'invalid_json_arguments';
          return false;
        }
      }
      return true;
    },
    get reason() {
      return reason;
    },
  };
}

function degenerateOutputError(providerName, verdict, toolName = '') {
  const error = new Error(
    `${providerName} stream aborted: ${verdict.reason} after ${verdict.bytes} bytes of output.`,
  );
  error.code = 'MODEL_DEGENERATE_OUTPUT';
  error.reason = verdict.reason;
  error.outputBytes = verdict.bytes;
  error.toolName = toolName;
  return error;
}

function isDegenerateOutputError(error) {
  return error?.code === 'MODEL_DEGENERATE_OUTPUT';
}

// Provider wrappers re-throw with the original as `cause`; the verdict fields
// live on whichever of the two carries them.
function degenerateOutputDetails(error) {
  const source = error?.reason ? error : error?.cause;
  return {
    reason: String(source?.reason || 'degenerate_output'),
    outputBytes: Number(source?.outputBytes) || 0,
    toolName: String(source?.toolName || ''),
  };
}

module.exports = {
  createJsonPrefixTracker,
  createStreamGuard,
  degenerateOutputDetails,
  degenerateOutputError,
  isDegenerateOutputError,
};
