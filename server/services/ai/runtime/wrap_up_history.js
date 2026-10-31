'use strict';

// The last messages a wrap-up turn sees next to the system prompt.
const WRAP_UP_HISTORY_MESSAGES = 24;

function sameContent(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

/**
 * The conversation a wrap-up turn is written from: the leading system
 * messages, the run's own request, and the most recent messages. A long tool
 * run pushes the request out of the recent window, and without it the model
 * reads its own instructions as what the user asked.
 */
function selectWrapUpHistory(messages, requestTurn = null) {
  const leadingSystem = [];
  for (const message of messages) {
    if (message.role !== 'system') break;
    leadingSystem.push(message);
  }
  const recent = messages.slice(leadingSystem.length).slice(-WRAP_UP_HISTORY_MESSAGES);
  const requestShown = !requestTurn || recent.some((message) => (
    message.role === requestTurn.role && sameContent(message.content, requestTurn.content)
  ));
  return [
    ...leadingSystem,
    ...(requestShown ? [] : [requestTurn]),
    ...recent,
  ];
}

module.exports = {
  selectWrapUpHistory,
};
