const crypto = require('crypto');
const db = require('../../db/database');

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
    '1. Resolve the concrete goal and required inputs from the current request and available context.'
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
  const workflowSignature = crypto.createHash('sha256')
    .update(normalizedSteps.map((step) => step.tool_name).join('\n'))
    .digest('hex');
  const baseName = sanitizeSkillName(title || task);
  const description = `Reusable workflow learned from: ${String(title || task || 'completed run').slice(0, 140)}`;
  const metadata = {
    category: 'learned',
    enabled: false,
    draft: true,
    auto_created: true,
    source: 'auto-learned',
    created_from_run: runId,
    workflow_signature: workflowSignature,
    evidence_count: normalizedSteps.length,
    reflection: {
      status: 'successful',
      reusable: true,
      action: 'create_or_update_draft',
    },
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

  maybeCaptureDraft({ userId, agentId, runId, triggerSource, triggerType, task, title, finalContent, steps }) {
    if (!this.skillRunner) return null;
    if (!userId || !agentId || !runId || !task || !finalContent) return null;
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
    db.prepare(
      `INSERT INTO skill_workflow_observations (
        user_id, agent_id, workflow_signature, observation_count, latest_run_id
      ) VALUES (?, ?, ?, 1, ?)
      ON CONFLICT(user_id, agent_id, workflow_signature) DO UPDATE SET
        observation_count = observation_count + 1,
        latest_run_id = excluded.latest_run_id,
        last_observed_at = datetime('now')`
    ).run(
      userId,
      agentId,
      draft.metadata.workflow_signature,
      runId,
    );
    const observation = db.prepare(
      `SELECT observation_count FROM skill_workflow_observations
       WHERE user_id = ? AND agent_id = ? AND workflow_signature = ?`
    ).get(userId, agentId, draft.metadata.workflow_signature);
    if (Number(observation?.observation_count || 0) < 3) return null;

    const existing = Array.from(this.skillRunner.skills.values()).find(
      (skill) => skill.metadata?.workflow_signature === draft.metadata.workflow_signature,
    );
    if (existing) {
      if (existing.metadata?.enabled !== false || existing.metadata?.draft !== true) return null;
      return this.skillRunner.updateSkill(existing.name, {
        description: draft.description,
        instructions: draft.instructions,
        metadata: {
          ...existing.metadata,
          ...draft.metadata,
          evidence_count: Number(observation.observation_count),
          updated_from_run: runId,
        },
      });
    }

    const result = this.skillRunner.createSkill(
      draft.name,
      draft.description,
      draft.instructions,
      {
        ...draft.metadata,
        evidence_count: Number(observation.observation_count),
      }
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
