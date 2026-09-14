'use strict';

const { normalizeSkillName } = require('../ai/toolRunner');

function normalizeText(value, maximum = 1000) {
  return String(value || '').trim().slice(0, maximum);
}

function splitInstructionText(value) {
  const trimmed = String(value || '').trim();
  if (!trimmed) return [];
  const lines = trimmed.split(/\r?\n+/).map((line) => line.trim()).filter(Boolean);
  const source = lines.length > 1
    ? lines
    : trimmed.split(/(?:^|\s)\d+[\.)]\s+/).map((part) => part.trim()).filter(Boolean);
  return source
    .map((item) => item.replace(/^(?:\d+[\.)]|[-*])\s+/, '').trim())
    .filter(Boolean);
}

function normalizeList(value, { maximumItems = 20, maximumLength = 1000 } = {}) {
  const source = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? splitInstructionText(value)
      : value && typeof value === 'object'
        ? Object.values(value)
        : [];
  return source
    .map((item) => normalizeText(
      typeof item === 'string'
        ? item
        : item?.instruction || item?.description || item?.text,
      maximumLength,
    ))
    .filter(Boolean)
    .slice(0, maximumItems);
}

function normalizeApproval(value) {
  const raw = value?.approved;
  if (typeof raw === 'string') {
    const normalized = raw.trim().toLowerCase();
    if (normalized === 'true' || normalized === 'yes') return true;
    if (normalized === 'false' || normalized === 'no') return false;
    return null;
  }
  if (raw === true || raw === 1) return true;
  if (raw === false || raw === 0) return false;
  return null;
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
  const proposal = {
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
    rejectionReason: '',
  };
  const approval = normalizeApproval(value) ?? normalizeApproval(skill);
  proposal.approved = approval === true || (approval === null && hasRequiredSkillFields(proposal));
  if (approval === false) {
    proposal.rejectionReason = normalizeText(value?.reason || skill.reason || value?.message, 500);
  }
  return proposal;
}

function hasRequiredSkillFields(proposal) {
  return Boolean(proposal?.name)
    && Boolean(proposal?.description)
    && Boolean(proposal?.trigger)
    && Array.isArray(proposal?.steps)
    && proposal.steps.length > 0
    && Array.isArray(proposal?.verification)
    && proposal.verification.length > 0;
}

function isUsableProposal(proposal) {
  return proposal?.approved === true && hasRequiredSkillFields(proposal);
}

function proposalFailureMessage(proposal) {
  if (proposal?.rejectionReason) return proposal.rejectionReason;
  if (!hasRequiredSkillFields(proposal)) {
    const missing = [
      !proposal?.name && 'name',
      !proposal?.description && 'description',
      !proposal?.trigger && 'trigger',
      !proposal?.steps?.length && 'steps',
      !proposal?.verification?.length && 'verification',
    ].filter(Boolean);
    if (missing.length) return `Skill synthesis was incomplete (missing ${missing.join(', ')}).`;
  }
  if (proposal?.approved === false) {
    return 'The demonstration did not prove a reusable procedure.';
  }
  return 'The demonstration did not produce a reusable skill.';
}

function isSafetyRejection(proposal) {
  if (proposal?.approved !== false) return false;
  return /password|credential|secret|private data|clipboard contents/.test(
    String(proposal.rejectionReason || '').toLowerCase(),
  );
}

function applyComputerDemonstrationDefaults(proposal, goal) {
  const title = normalizeText(goal, 160) || 'taught computer workflow';
  const next = {
    requiredInputs: [],
    pitfalls: [],
    steps: [],
    verification: [],
    ...(proposal && typeof proposal === 'object' ? proposal : {}),
  };
  if (!next.name) next.name = normalizeSkillName(title).slice(0, 64) || 'taught-computer-workflow';
  if (!next.description) next.description = normalizeText(`Taught computer workflow: ${title}`, 300);
  if (!next.trigger) {
    next.trigger = normalizeText(`Use when repeating the taught computer workflow: ${title}`, 500);
  }
  if (!next.category) next.category = 'computer';
  if (!next.workflowKey) next.workflowKey = next.name;
  if (!next.steps.length) {
    next.steps = [
      'Inspect the current computer, window, and UI state before acting.',
      `Repeat the taught workflow: ${title}.`,
      'Adapt to the current semantic UI state instead of replaying coordinates or timing.',
    ];
  }
  if (!next.verification.length) {
    next.verification = ['Confirm the taught outcome is visible in the current computer state.'];
  }
  next.approved = true;
  next.rejectionReason = '';
  return next;
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
  applyComputerDemonstrationDefaults,
  buildSkillInstructions,
  compactDialogue,
  isSafetyRejection,
  isUsableProposal,
  markLearningUserEdited,
  normalizeProposal,
  normalizeReview,
  normalizeText,
  normalizeWorkflowKey,
  proposalFailureMessage,
};
