'use strict';

// Every turn resends every earlier tool result, which is where a long run's tokens
// go: the model has acted on a result from twenty turns ago and rarely needs all of
// it again. Older results shrink in batches, so the prefix a provider caches stays
// the same between batches. The model can always make the call again.
const KEEP_RECENT = 8;
const BATCH = 6;
const KEPT_CHARS = 400;

function ageToolResults(session) {
  session.agedToolResults ||= new WeakSet();
  const results = session.messages.filter((message) => (
    message.role === 'tool' && !session.agedToolResults.has(message) && String(message.content || '').length > KEPT_CHARS
  ));
  if (results.length < KEEP_RECENT + BATCH) return false;
  for (const message of results.slice(0, BATCH)) {
    message.content = `${String(message.content).slice(0, KEPT_CHARS)}\n[older result shortened to save context; make the call again if you need the rest]`;
    session.agedToolResults.add(message);
  }
  // The answers these calls gave are no longer in view, so asking again is not a repeat.
  session.engine.getRunMeta(session.runId)?.repetitionGuard?.noteCompaction();
  return true;
}

module.exports = { ageToolResults };
