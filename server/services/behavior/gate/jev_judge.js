'use strict';

const { requestDecision } = require('../model_client');
const { normalizeDecision, URGENCY_LEVELS } = require('./decisions');

// Jev answers the same gate as the model judge: one request, a few hundred
// milliseconds, with probabilities instead of self-reported scores.
const JEV_GATE_QUESTIONS = Object.freeze({
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
// Without a description of what the agent can do, Jev treats open questions
// to the room as not the agent's business.
const AGENT_CAPABILITIES = 'answer questions, look things up on the web, and do tasks with its tools and connected apps';
// Jev's scores are calibrated probabilities, so the room threshold that was
// tuned on self-reported model scores can sit a little lower for them.
const JEV_THRESHOLD_OFFSET = 0.08;

function jevGateState(packet) {
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
    },
    recent_messages: packet.room.recentMessages,
    seconds_since_agent_spoke: packet.room.secondsSinceAgentSpoke,
    room_hints: packet.roomHints,
  };
}

// The need score is the chance a reply is wanted now and is meant for the
// agent, so messages aimed at someone else stay quiet even when useful.
function decisionFromJev(answers) {
  const speak = answers.speak.noul;
  const forSomeoneElse = answers.for_someone_else.noul;
  const reasonCodes = ['jev_gate', speak >= 0.5 ? 'agent_can_help' : 'hold_back'];
  if (forSomeoneElse >= 0.5) reasonCodes.push('meant_for_someone_else');
  const decision = normalizeDecision({
    decision: speak >= 0.5 ? 'speak' : 'stay_silent',
    needScore: speak * (1 - forSomeoneElse),
    confidence: Math.max(speak, 1 - speak),
    reasonCodes,
    urgency: URGENCY_LEVELS[Math.round(Math.max(0, Math.min(2, answers.urgency.score)))],
  }, { tokenPath: 'jev_gate', model: 'jev' });
  // Jev gives probabilities, not prose; these are its whole explanation.
  return { ...decision, jevScores: { speak, forSomeoneElse } };
}

async function askJev(ctx, packet) {
  const answers = await requestDecision({
    agentEngine: ctx.agentEngine,
    userId: ctx.userId,
    agentId: ctx.agentId,
    phase: 'jev_turn_taking',
    signal: ctx.signal,
    state: jevGateState(packet),
    questions: JEV_GATE_QUESTIONS,
  });
  return answers ? decisionFromJev(answers) : null;
}

module.exports = {
  JEV_THRESHOLD_OFFSET,
  askJev,
};
