'use strict';

// A model's private reasoning, kept on its assistant turns so it can continue its
// own train of thought across tool calls. It stays in memory for the run: it is
// never stored, summarized, or shown, and it is dropped when another model takes
// over, because the signatures on it are only valid for the model that wrote it.
function dropReasoningState(messages = []) {
  let dropped = false;
  for (const message of messages) {
    if (message?.reasoningState) {
      delete message.reasoningState;
      dropped = true;
    }
    if (message?.providerContentBlocks) {
      delete message.providerContentBlocks;
      dropped = true;
    }
  }
  return dropped;
}

function isReasoningReplayError(error) {
  const status = Number(error?.status || error?.statusCode || error?.response?.status);
  if (status && status !== 400 && status !== 422) return false;
  return /reasoning|thinking|thought|signature/i.test(String(error?.message || ''));
}

module.exports = {
  dropReasoningState,
  isReasoningReplayError,
};
