'use strict';

const { normalizeSkillName } = require('../ai/toolRunner');

function normalizeText(value, maximum = 1000) {
  return String(value || '').trim().slice(0, maximum);
}

function normalizeList(value, { maximumItems = 20, maximumLength = 1000 } = {}) {
  return Array.isArray(value)
    ? value
      .map((item) => normalizeText(
        typeof item === 'string'
          ? item
          : item?.instruction || item?.description || item?.text,
        maximumLength,
      ))
      .filter(Boolean)
      .slice(0, maximumItems)
    : [];
}

function normalizeWorkflowKey(value) {
  return normalizeSkillName(value).slice(0, 80);
}

function normalizeReview(value) {
  const source = value && typeof value === 'object' ? value : {};
  const allowed = new Set(['ignore', 'observe', 'create', 'update']);
  const decision = allowed.has(source.decision) ? source.decision : 'ignore';
  return {
    decision,
    workflowKey: normalizeWorkflowKey(source.workflowKey || source.workflow_key),
    title: normalizeText(source.title, 160),
    summary: normalizeText(source.summary, 1000),
    existingSkillName: normalizeSkillName(
      source.existingSkillName || source.existing_skill_name,
    ),
    confidence: Math.max(0, Math.min(Number(source.confidence) || 0, 1)),
    reason: normalizeText(source.reason, 500),
  };
}

function normalizeProposal(value) {
  const source = value?.skill && typeof value.skill === 'object' ? value.skill : value;
  const skill = source && typeof source === 'object' ? source : {};
  return {
    approved: value?.approved === true,
    name: normalizeSkillName(skill.name).slice(0, 64),
    description: normalizeText(skill.description, 300),
    trigger: normalizeText(skill.trigger, 500),
    category: normalizeSkillName(skill.category || 'learned').slice(0, 64) || 'learned',
    workflowKey: normalizeWorkflowKey(skill.workflowKey || skill.workflow_key || skill.name),
    existingSkillName: normalizeSkillName(
      skill.existingSkillName || skill.existing_skill_name,
    ),
    requiredInputs: normalizeList(skill.requiredInputs || skill.required_inputs, {
      maximumItems: 20,
      maximumLength: 400,
    }),
    steps: normalizeList(skill.steps, { maximumItems: 30, maximumLength: 1000 }),
    pitfalls: normalizeList(skill.pitfalls, { maximumItems: 20, maximumLength: 700 }),
    verification: normalizeList(
      skill.verification || skill.successCriteria || skill.success_criteria,
      { maximumItems: 20, maximumLength: 700 },
    ),
  };
}

function isUsableProposal(proposal) {
  return proposal.approved
    && Boolean(proposal.name)
    && Boolean(proposal.description)
    && Boolean(proposal.trigger)
    && proposal.steps.length > 0
    && proposal.verification.length > 0;
}

function buildSkillInstructions(proposal, { computerAdaptive = false } = {}) {
  const lines = [
    `# ${proposal.name}`,
    '',
    '## Purpose',
    proposal.description,
    '',
    '## When To Use',
    proposal.trigger,
  ];
  if (proposal.requiredInputs.length > 0) {
    lines.push('', '## Required Inputs', ...proposal.requiredInputs.map((item) => `- ${item}`));
  }
  lines.push('', '## Procedure');
  if (computerAdaptive) {
    lines.push(
      'Inspect the current computer state before acting. Use semantic UI labels, accessibility or DOM state, visible content, and tool results; never replay recorded coordinates or timing.',
    );
  }
  lines.push(...proposal.steps.map((step, index) => `${index + 1}. ${step}`));
  if (proposal.pitfalls.length > 0) {
    lines.push('', '## Pitfalls And Recovery', ...proposal.pitfalls.map((item) => `- ${item}`));
  }
  lines.push('', '## Verification', ...proposal.verification.map((item) => `- ${item}`));
  if (computerAdaptive) {
    lines.push(
      '',
      '## Execution Contract',
      '- Execute through the normal NeoAgent loop and preserve approval and security rules.',
      '- Re-plan when the current application state differs from the demonstration.',
      '- Verify observed state before reporting success.',
    );
  }
  return lines.join('\n');
}

function compactDialogue(messages = [], maximumMessages = 10) {
  return messages
    .filter((message) => ['user', 'assistant'].includes(message?.role))
    .map((message) => ({
      role: message.role,
      content: normalizeText(message.content, 1800),
    }))
    .filter((message) => message.content)
    .slice(-maximumMessages);
}

function markLearningUserEdited(currentMetadata = {}, submittedMetadata = {}) {
  if (currentMetadata?.learning?.managed !== true) return submittedMetadata;
  return {
    ...submittedMetadata,
    learning: {
      ...currentMetadata.learning,
      managed: false,
      userEditedAt: new Date().toISOString(),
    },
  };
}

module.exports = {
  buildSkillInstructions,
  compactDialogue,
  isUsableProposal,
  markLearningUserEdited,
  normalizeProposal,
  normalizeReview,
  normalizeText,
  normalizeWorkflowKey,
};
