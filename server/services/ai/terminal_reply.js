'use strict';

// Terminality of assistant text is decided by the model completion judge using
// structured analysis + tool evidence. This module intentionally does not
// phrase-match natural language replies.

function isTerminalQuestionOrBlockerReply(_content) {
  return false;
}

function isDeferredWorkReply(_content) {
  return false;
}

module.exports = {
  isDeferredWorkReply,
  isTerminalQuestionOrBlockerReply,
};
