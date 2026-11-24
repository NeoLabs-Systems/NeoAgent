'use strict';

const { sanitizeConversationMessages } = require('../history');
const { isRawToolCall, sanitizeModelOutput } = require('../outputSanitizer');
const { serializeForSummary } = require('../compaction');
const {
  buildProgressUpdatePrompt,
  buildWrapUpPrompt,
  normalizeOutgoingMessage,
} = require('../messagingFallback');
const { isAbortError } = require('../../../utils/abort');
const { NARRATION_MAX_TOKENS } = require('./constants');
const { selectWrapUpHistory } = require('./wrap_up_history');
const { setSteeringIntake } = require('./agent_loop');

const WRAP_UP_ATTEMPTS = 2;
const FLATTENED_WORK_CHARS = 24_000;

function flattenToolTurns(history, requestTurn) {
  const leading = [];
  for (const message of history) {
    if (message.role !== 'system') break;
    leading.push(message);
  }
  const work = serializeForSummary(history.slice(leading.length));
  return [
    ...leading,
    ...(requestTurn ? [requestTurn] : []),
    {
      role: 'system',
      content: `What this run did so far, oldest first:\n${work.slice(-FLATTENED_WORK_CHARS)}`,
    },
  ];
}

/**
 * The last turn of a run a runaway guard ended. The model writes it from the
 * conversation, in its own voice: what it got done, what is missing, and why.
 * When it returns nothing the run fails visibly rather than sending the user
 * text nobody wrote.
 */
async function writeWrapUp(engine, session, reason) {
  const { runId, userId, agentId, options } = session;
  // The wrap-up is the run's last model turn, so it must see any follow-up
  // still waiting; nothing sent after this point can reach this run.
  setSteeringIntake(engine, runId, false);
  engine.applyQueuedSteering?.(runId, session.messages, {
    userId,
    conversationId: session.conversationId,
  });
  const history = selectWrapUpHistory(session.messages, session.requestTurn);
  // A model can answer this turn with another tool call, even with no tools on
  // offer, because the transcript it sees is full of them. The second attempt
  // tells the same story as plain text, so there is nothing to continue.
  for (let attempt = 0; attempt < WRAP_UP_ATTEMPTS; attempt += 1) {
    const transcript = attempt === 0 ? history : flattenToolTurns(history, session.requestTurn);
    try {
      const wrapUp = await engine.requestModelResponse({
        provider: session.model.provider,
        providerName: session.model.providerName,
        model: session.model.model,
        messages: sanitizeConversationMessages([
          ...transcript,
          { role: 'system', content: buildWrapUpPrompt(reason, options.source || null) },
        ]),
        tools: [],
        options: {
          ...options,
          stream: false,
          phase: 'wrap_up',
          signal: session.getActiveSignal(),
          runId,
          userId,
          agentId,
        },
        runId,
        iteration: session.iterations,
      });
      const text = sanitizeModelOutput(
        String(wrapUp?.response?.content || wrapUp?.streamContent || '').trim(),
        { model: session.model.model },
      );
      if (!isRawToolCall(text) && normalizeOutgoingMessage(text, options.source || null)) return text;
    } catch (error) {
      if (isAbortError(error, session.getActiveSignal())) throw error;
      console.warn('[Runtime] Wrap-up generation failed:', error?.message || error);
    }
  }
  throw new Error(`Run stopped (${reason}) and the model could not write a reply`);
}

/**
 * Phrases an observed progress delta. The run's own system prompt supplies the
 * voice and formatting rules, so an update reads like every other message; the
 * delta is the only permitted source of facts, and an empty answer means "no
 * useful update", not "send something generic".
 */
async function narrateProgress(engine, session, { delta, liveness, previous = '', signal }) {
  const { runId, userId, agentId, options } = session;
  if (!session.model) return '';
  const systemPrompt = [session.systemPrompt?.stable, session.systemPrompt?.dynamic]
    .filter(Boolean)
    .join('\n\n');
  const response = await engine.requestModelResponse({
    provider: session.model.provider,
    providerName: session.model.providerName,
    model: session.model.model,
    messages: [
      ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
      {
        role: 'system',
        content: [
          buildProgressUpdatePrompt(),
          liveness?.status === 'stalled'
            ? 'No verified activity has been recorded for the stall threshold. State that plainly if it matters; do not reassure or imply activity beyond the evidence.'
            : '',
        ].filter(Boolean).join(' '),
      },
      {
        role: 'user',
        content: [
          `Original request: ${String(session.userMessage || '').slice(0, 320)}`,
          previous ? `Your previous update, which the user already has:\n${String(previous).slice(0, 400)}` : '',
          delta?.evidence
            ? `Tool activity since then (newest last) — describe ONLY this:\n${delta.evidence}`
            : '',
        ].filter(Boolean).join('\n\n'),
      },
    ],
    tools: [],
    options: {
      ...options,
      maxTokens: NARRATION_MAX_TOKENS,
      stream: false,
      phase: 'progress_narration',
      signal,
      runId,
      userId,
      agentId,
    },
    runId,
    iteration: 0,
  });
  const text = sanitizeModelOutput(
    String(response?.response?.content || response?.streamContent || '').trim(),
    { model: session.model.model },
  );
  if (!normalizeOutgoingMessage(text, options.source || null)) return '';
  return text.split(/\n+/).map((line) => line.trim()).filter(Boolean).join(' ').slice(0, 400);
}

module.exports = {
  narrateProgress,
  writeWrapUp,
};
