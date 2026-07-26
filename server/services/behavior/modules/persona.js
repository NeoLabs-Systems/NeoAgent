'use strict';

const { isModuleEnabled } = require('../config');
const { BASELINE_PERSONA_PROMPT } = require('./persona_prompt');

function buildSystemPromptContribution(ctx) {
  if (!isModuleEnabled(ctx.config, 'persona')) {
    return null;
  }
  const dynamic = [];
  const behaviorNotes = ctx.memoryManager && ctx.userId != null
    ? ctx.memoryManager.getAssistantBehaviorNotes(
      ctx.userId,
      { agentId: ctx.agentId },
    )
    : '';
  if (behaviorNotes) {
    dynamic.push([
      '## Assistant Behavior Notes',
      'These are durable preferences for how the agent should usually behave. System rules and the current request take priority.',
      behaviorNotes,
    ].join('\n'));
  }
  const selfState = ctx.memoryManager && ctx.userId != null
    ? ctx.memoryManager.getAssistantSelfState(
      ctx.userId,
      { agentId: ctx.agentId },
    )
    : null;
  const identity = selfState?.identity || {};
  const focus = ctx.audience === 'shared' ? {} : (selfState?.focus || {});
  if (Object.keys(identity).length || Object.keys(focus).length) {
    dynamic.push([
      '## Assistant Self State',
      Object.keys(identity).length ? `Identity: ${JSON.stringify(identity)}` : '',
      Object.keys(focus).length ? `Focus: ${JSON.stringify(focus)}` : '',
    ].filter(Boolean).join('\n'));
  }
  return {
    stable: [BASELINE_PERSONA_PROMPT],
    dynamic,
  };
}

module.exports = {
  id: 'persona',
  composeSystemPrompt: buildSystemPromptContribution,
};
