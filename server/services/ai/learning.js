function sanitizeSkillName(input) {
  const base = String(input || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  return base || `workflow-${Date.now().toString(36)}`;
}

function summarizeToolStep(step) {
  const name = step.tool_name || 'tool';
  let inputText = '';
  try {
    const parsed = JSON.parse(step.tool_input || '{}');
    if (name === 'execute_command' && parsed.command) {
      inputText = `Run \`${String(parsed.command).slice(0, 120)}\``;
    } else if (name.startsWith('browser_') && parsed.url) {
      inputText = `Use ${name} on ${String(parsed.url).slice(0, 100)}`;
    } else if (name.startsWith('browser_') && parsed.selector) {
      inputText = `Use ${name} with selector \`${String(parsed.selector).slice(0, 80)}\``;
    } else if (parsed.query) {
      inputText = `Use ${name} for "${String(parsed.query).slice(0, 100)}"`;
    } else if (parsed.path || parsed.file_path || parsed.cwd) {
      inputText = `Use ${name} in ${String(parsed.path || parsed.file_path || parsed.cwd).slice(0, 100)}`;
    }
  } catch {
    inputText = '';
  }

  return inputText || `Use \`${name}\` as part of the workflow.`;
}

function buildSkillInstructions({ name, task, finalContent, steps, runId }) {
  const lines = [
    `# ${name}`,
    '',
    '## When To Use',
    `Use this workflow when the task is similar to: "${String(task || '').trim().slice(0, 220)}".`,
    '',
    '## Procedure',
    '1. Restate the goal in one sentence so the user can confirm the intent quickly.'
  ];

  steps.forEach((step, index) => {
    lines.push(`${index + 2}. ${summarizeToolStep(step)}`);
  });

  lines.push(`${steps.length + 2}. Verify the outcome, call out anything incomplete, and report the result concisely.`);

  if (finalContent) {
    lines.push('');
    lines.push('## Expected Outcome');
    lines.push(String(finalContent).trim().slice(0, 900));
  }

  lines.push('');
  lines.push('## Notes');
  lines.push(`Learned automatically from successful run \`${runId}\`.`);

  return lines.join('\n');
}

function buildSkillDraftFromRun({ runId, task, title, finalContent, steps }) {
  const normalizedSteps = Array.isArray(steps) ? steps.filter((step) => step && step.tool_name) : [];
  const baseName = sanitizeSkillName(title || task);
  const description = `Reusable workflow learned from: ${String(title || task || 'completed run').slice(0, 140)}`;
  const metadata = {
    category: 'learned',
    enabled: false,
    draft: true,
    auto_created: true,
    source: 'auto-learned',
    created_from_run: runId
  };

  return {
    name: baseName,
    description,
    instructions: buildSkillInstructions({
      name: baseName,
      task,
      finalContent,
      steps: normalizedSteps,
      runId
    }),
    metadata
  };
}

class LearningManager {
  constructor(skillRunner, io) {
    this.skillRunner = skillRunner;
    this.io = io;
  }

  maybeCaptureDraft({ userId, runId, triggerSource, triggerType, task, title, finalContent, steps }) {
    if (!this.skillRunner) return null;
    if (!userId || !runId || !task || !finalContent) return null;
    if (triggerType && triggerType !== 'user') return null;
    if (triggerSource && triggerSource !== 'web') return null;

    const successfulSteps = Array.isArray(steps)
      ? steps.filter((step) => step.status === 'completed' && step.tool_name)
      : [];

    if (successfulSteps.length < 3) return null;

    const draft = buildSkillDraftFromRun({
      runId,
      task,
      title,
      finalContent,
      steps: successfulSteps
    });

    if (this.skillRunner.getSkill(draft.name)) {
      return null;
    }

    const result = this.skillRunner.createSkill(
      draft.name,
      draft.description,
      draft.instructions,
      draft.metadata
    );

    if (!result?.success) return result;

    this.io?.to(`user:${userId}`).emit('skill:draft_created', {
      runId,
      name: draft.name,
      description: draft.description
    });

    return result;
  }
}

module.exports = {
  sanitizeSkillName,
  buildSkillDraftFromRun,
  LearningManager
};
