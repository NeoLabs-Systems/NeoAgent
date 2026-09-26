'use strict';

// Jev reads the run's tool results and the draft reply. Only a reply that is
// clearly backed skips the verifier model; anything less still goes to the
// model, which can rewrite the reply before the user sees it.
const REQUEST_CHARS = 2000;
const REPLY_CHARS = 6000;
const EVIDENCE_ITEMS = 12;
const EVIDENCE_CHARS = 1500;
const GROUNDED_THRESHOLD = 0.9;
const ANSWERS_THRESHOLD = 0.9;
const UNBACKED_ACTION_THRESHOLD = 0.1;

const VERIFICATION_QUESTIONS = Object.freeze({
  grounded: {
    type: 'noul',
    instructions: 'Every specific fact, number, name, and result stated in `draft_reply` appears in `evidence` or in `request`.',
  },
  unbacked_action: {
    type: 'noul',
    instructions: '`draft_reply` says an action was completed, such as a message or email sent, a file written, or a reminder scheduled, and no successful entry in `evidence` shows that action.',
  },
  answers_request: {
    type: 'noul',
    instructions: '`draft_reply` responds to what `request` asks for, or clearly says what could not be done.',
  },
});

function buildVerificationDecision({ request, messages = [], draftReply }) {
  return {
    state: {
      request: String(request || '').slice(0, REQUEST_CHARS),
      evidence: messages
        .filter((message) => message?.role === 'tool')
        .slice(-EVIDENCE_ITEMS)
        .map((message) => ({
          tool: message.name || 'tool',
          output: String(message.content || '').slice(0, EVIDENCE_CHARS),
        })),
      draft_reply: String(draftReply || '').slice(0, REPLY_CHARS),
    },
    questions: VERIFICATION_QUESTIONS,
  };
}

function isClearlySupported(answers) {
  return answers.grounded.noul >= GROUNDED_THRESHOLD
    && answers.answers_request.noul >= ANSWERS_THRESHOLD
    && answers.unbacked_action.noul <= UNBACKED_ACTION_THRESHOLD;
}

module.exports = {
  buildVerificationDecision,
  isClearlySupported,
};
