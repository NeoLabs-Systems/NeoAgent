'use strict';

const { requestDecision } = require('../model_client');
const { normalizeDecision, URGENCY_LEVELS } = require('./decisions');

// SystemOne answers the same gate as the model judge: one request, a few
// hundred milliseconds, with probabilities instead of self-reported scores.
const GATE_QUESTIONS = Object.freeze({
  speak: {
    type: 'noul',
    instructions: 'The agent named in `agent.names` should post a reply to `latest_message` now.',
    criteria: {
      true: 'Someone asks the agent something, asks the group a question the agent can answer with what `agent.can` do, follows up on the agent\'s last message, or says something harmful that should be corrected.',
      false: 'Side chatter, greetings, feelings, or talk meant for another person in the chat, where nobody needs the agent.',
    },
  },
  for_someone_else: {
    type: 'noul',
    instructions: '`latest_message` is meant for a specific other person in the chat, not for the agent or the whole group.',
  },
  urgency: {
    type: 'score',
    instructions: 'How time-sensitive is a reply to `latest_message`?',
    criteria: ['Not time-sensitive', 'Should be answered soon', 'Needed right now'],
  },
});
// Without a description of what the agent can do, SystemOne treats open
// questions to the room as not the agent's business.
const AGENT_CAPABILITIES = 'answer questions, look things up on the web, and do tasks with its tools and connected apps';
// SystemOne scores are calibrated probabilities, so the room threshold that
// was tuned on self-reported model scores can sit a little lower for them.
const SYSTEM_ONE_THRESHOLD_OFFSET = 0.08;

function gateState(packet) {
  return {
    agent: {
      names: packet.room.agentNames.length ? packet.room.agentNames : ['the assistant'],
      can: AGENT_CAPABILITIES,
    },
    chat: { platform: packet.chat.platform, name: packet.chat.groupName },
    latest_message: {
      sender: packet.sender.name || packet.sender.username || 'participant',
      content: packet.event.content,
      has_media: packet.event.hasMedia,
      // A reply to another person is the clearest sign the message is theirs.
      ...(packet.event.replyTo ? { reply_to: packet.event.replyTo } : {}),
    },
    recent_messages: packet.room.recentMessages,
    seconds_since_agent_spoke: packet.room.secondsSinceAgentSpoke,
  };
}

// The need score is the chance a reply is wanted now and is meant for the
// agent, so messages aimed at someone else stay quiet even when useful.
function decisionFromAnswers(answers) {
  const speak = answers.speak.noul;
  const forSomeoneElse = answers.for_someone_else.noul;
  const reasonCodes = ['system_one_gate', speak >= 0.5 ? 'agent_can_help' : 'hold_back'];
  if (forSomeoneElse >= 0.5) reasonCodes.push('meant_for_someone_else');
  const decision = normalizeDecision({
    decision: speak >= 0.5 ? 'speak' : 'stay_silent',
    needScore: speak * (1 - forSomeoneElse),
    confidence: Math.max(speak, 1 - speak),
    reasonCodes,
    urgency: URGENCY_LEVELS[Math.round(Math.max(0, Math.min(2, answers.urgency.score)))],
  }, { tokenPath: 'system_one_gate', model: 'system_one' });
  // SystemOne gives probabilities, not prose; these are its whole explanation.
  return { ...decision, systemOneScores: { speak, forSomeoneElse } };
}

async function askSystemOne(ctx, packet) {
  const answers = await requestDecision({
    agentEngine: ctx.agentEngine,
    userId: ctx.userId,
    agentId: ctx.agentId,
    phase: 'system_one_turn_taking',
    signal: ctx.signal,
    state: gateState(packet),
    questions: GATE_QUESTIONS,
  });
  return answers ? decisionFromAnswers(answers) : null;
}

module.exports = {
  SYSTEM_ONE_THRESHOLD_OFFSET,
  askSystemOne,
};
