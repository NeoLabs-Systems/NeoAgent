'use strict';

const { ALWAYS_INCLUDE_BUILT_INS } = require('./toolSelector');

// Jev reads the request and the last few turns, which is what routing needs;
// the full system prompt and tool schemas stay with the chat model.
const REQUEST_CHARS = 4000;
const RECENT_MESSAGE_LIMIT = 6;
const RECENT_MESSAGE_CHARS = 400;
// A choice takes at most 255 options; tool questions are capped for latency.
const TOOL_QUESTION_LIMIT = 150;
const SKILL_OPTION_LIMIT = 200;
const DESCRIPTION_CHARS = 140;
const TOOL_THRESHOLD = 0.6;
const SUGGESTED_TOOL_LIMIT = 8;
const SKILL_THRESHOLD = 0.5;
const SKILL_INSTRUCTION_CHARS = 6000;
// Long or broad work still gets the chat model's own triage: the goal,
// success criteria, research targets, plan, and the opening line it writes
// for the user are text Jev cannot produce.
const LONG_RUNNING_THRESHOLD = 0.6;

const TRIAGE_QUESTIONS = Object.freeze({
  mode: {
    type: 'choice',
    instructions: 'How should the assistant handle `request`?',
    criteria: {
      direct_answer: 'A complete reply can be written right now from general knowledge and `recent_conversation`. No tools, files, commands, lookups, messages, or current data are needed.',
      execute: 'A focused task that needs tools: lookups, files, commands, browsing, messages, reminders, or integrations.',
      plan_execute: 'A broad multi-step task: several targets, research across sources, coordinated changes across files, or long autonomous work.',
    },
  },
  research_depth: {
    type: 'choice',
    instructions: 'How much external research does `request` need?',
    criteria: {
      none: 'No external research.',
      light: 'One focused lookup.',
      deep: 'Comparisons, several sources, or disputed claims.',
    },
  },
  long_running: {
    type: 'noul',
    instructions: 'Completing `request` takes many steps or several minutes of work.',
  },
  external_side_effect: {
    type: 'noul',
    instructions: 'Completing `request` contacts other people or changes something outside the assistant\'s own workspace, such as sending a message or email, posting, buying, booking, deleting data, deploying, or pushing code.',
  },
  high_stakes: {
    type: 'noul',
    instructions: 'A wrong or incomplete result for `request` would be costly, visible to other people, or hard to undo.',
  },
  parallel_parts: {
    type: 'noul',
    instructions: '`request` has independent parts that can be worked on at the same time, such as several separate lookups or files.',
  },
  check_facts: {
    type: 'noul',
    instructions: 'The reply to `request` will state facts that must be checked against tool results before it is sent, such as research findings, command output, file contents, or a claim that an action was done.',
  },
});

function compact(value, maxChars) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  return text.length <= maxChars ? text : `${text.slice(0, maxChars - 3).trimEnd()}...`;
}

function messageText(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content
    .map((part) => (typeof part === 'string' ? part : part?.text || ''))
    .filter(Boolean)
    .join(' ');
}

// The turns before the current request, so references such as "rename it"
// resolve against what was just discussed.
function recentConversation(messages = []) {
  const turns = messages.filter((message) => message?.role === 'user' || message?.role === 'assistant');
  return turns
    .slice(0, -1)
    .slice(-RECENT_MESSAGE_LIMIT)
    .map((message) => ({
      role: message.role,
      content: compact(messageText(message.content), RECENT_MESSAGE_CHARS),
    }))
    .filter((message) => message.content);
}

function toolCandidates(tools = []) {
  const alwaysActive = new Set(ALWAYS_INCLUDE_BUILT_INS);
  return tools
    .filter((tool) => tool?.name && !alwaysActive.has(tool.name))
    .slice(0, TOOL_QUESTION_LIMIT);
}

function buildTriageDecision({ userMessage, messages = [], tools = [], skills = [] }) {
  const questions = { ...TRIAGE_QUESTIONS };
  for (const tool of toolCandidates(tools)) {
    questions[`tool:${tool.name}`] = {
      type: 'noul',
      instructions: `Completing \`request\` needs the tool \`${tool.name}\`: ${compact(tool.description, DESCRIPTION_CHARS)}`,
    };
  }
  const skillOptions = skills.slice(0, SKILL_OPTION_LIMIT);
  if (skillOptions.length > 0) {
    questions.skill = {
      type: 'choice',
      instructions: 'Which installed skill gives the instructions for completing `request`?',
      criteria: {
        none: 'No installed skill fits `request`.',
        ...Object.fromEntries(skillOptions.map((skill) => [
          skill.name,
          compact(skill.description || skill.name, DESCRIPTION_CHARS),
        ])),
      },
    };
  }
  return {
    state: {
      request: compact(userMessage, REQUEST_CHARS),
      recent_conversation: recentConversation(messages),
    },
    questions,
  };
}

function pickedTools(answers) {
  return Object.entries(answers)
    .filter(([key, answer]) => key.startsWith('tool:') && answer.noul >= TOOL_THRESHOLD)
    .sort(([, left], [, right]) => right.noul - left.noul)
    .slice(0, SUGGESTED_TOOL_LIMIT)
    .map(([key]) => key.slice('tool:'.length));
}

// Turns Jev's answers into the same analysis fields the model triage returns.
// Separate answers are combined in code: a request that needs a tool, has an
// outside effect, or needs research is never answered directly.
function interpretTriageDecision(answers) {
  const suggestedTools = pickedTools(answers);
  const researchDepth = answers.research_depth.choice;
  const longRunning = answers.long_running.noul >= LONG_RUNNING_THRESHOLD;
  const sideEffect = answers.external_side_effect.noul;
  const direct = answers.mode.choice === 'direct_answer'
    && suggestedTools.length === 0
    && sideEffect < 0.5
    && researchDepth === 'none';
  const broad = answers.mode.choice === 'plan_execute' || researchDepth === 'deep' || longRunning;
  let mode = 'execute';
  if (direct) mode = 'direct_answer';
  else if (broad) mode = 'plan_execute';

  let verificationNeed = 'none';
  if (researchDepth === 'deep') verificationNeed = 'required';
  else if (answers.check_facts.noul >= 0.5) verificationNeed = 'light';

  let complexity = 'standard';
  let autonomy = 'normal';
  let progressPolicy = 'optional';
  if (direct) {
    complexity = 'simple';
    autonomy = 'minimal';
    progressPolicy = 'none';
  } else if (broad) {
    complexity = 'complex';
    autonomy = 'high';
    progressPolicy = 'required';
  }

  const skill = answers.skill?.choice && answers.skill.choice !== 'none'
    && answers.skill.probabilities?.[answers.skill.choice] >= SKILL_THRESHOLD
    ? answers.skill.choice
    : null;

  return {
    escalate: broad,
    skill,
    analysis: {
      mode,
      verification_need: verificationNeed,
      research_depth: direct ? 'none' : researchDepth,
      suggested_tools: suggestedTools,
      complexity,
      autonomy_level: autonomy,
      progress_update_policy: progressPolicy,
      parallel_work: answers.parallel_parts.noul >= 0.5,
      completion_confidence_required: answers.high_stakes.noul >= 0.6 || sideEffect >= 0.6
        ? 'high'
        : 'medium',
      confidence: answers.mode.confidence,
    },
  };
}

// The installed-skills list in the system prompt is short and may be cut off,
// so the one skill Jev picked is handed over with its instructions. The list
// itself stays unchanged, which keeps the cached prompt prefix intact.
function buildSkillHint(skill) {
  const instructions = String(skill.instructions || '').trim();
  return [
    '[Relevant skill]',
    `The installed skill \`${skill.name}\` looks relevant to this request. Follow its instructions when they fit what the user asked; ignore them when they do not.`,
    instructions.length > SKILL_INSTRUCTION_CHARS
      ? `${instructions.slice(0, SKILL_INSTRUCTION_CHARS)}\n[Instructions truncated; list_skills returns the full text.]`
      : instructions,
  ].filter(Boolean).join('\n\n');
}

module.exports = {
  buildSkillHint,
  buildTriageDecision,
  interpretTriageDecision,
};
