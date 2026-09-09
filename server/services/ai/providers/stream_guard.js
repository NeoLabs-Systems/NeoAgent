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
  createStreamGuard,
  degenerateOutputDetails,
  degenerateOutputError,
  isDegenerateOutputError,
};
