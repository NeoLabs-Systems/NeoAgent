'use strict';

const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

function proposal(name, workflowKey) {
  return {
    approved: true,
    skill: {
      name,
      description: 'Export a filtered report and verify the resulting file.',
      trigger: 'Use when a user needs a report exported for a selected filter.',
      category: 'reporting',
      workflowKey,
      requiredInputs: ['The report filter'],
      steps: [
        'Inspect the available report filters and apply the requested value.',
        'Export the report and retain the resulting file.',
      ],
      pitfalls: ['Reinspect the current report state before retrying an export.'],
      verification: ['Confirm that the exported file exists and matches the requested filter.'],
    },
  };
}

test('post-run learning creates, repeats, exposes, versions, and protects skills', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db);
    const agentId = randomUUID();
    ctx.db.prepare(
      `INSERT INTO agents (id, user_id, slug, display_name, is_default)
       VALUES (?, ?, 'main', 'Main', 1)`,
    ).run(agentId, user.userId);

    const insertRun = (runId, source = 'web', stepCount = 1) => {
      ctx.db.prepare(
        `INSERT INTO agent_runs (
          id, user_id, agent_id, title, status, trigger_type, trigger_source, model
        ) VALUES (?, ?, ?, 'Learning test', 'completed', 'user', ?, 'test')`,
      ).run(runId, user.userId, agentId, source);
      for (let index = 1; index <= stepCount; index += 1) {
        ctx.db.prepare(
          `INSERT INTO agent_steps (
            id, run_id, step_index, type, description, status, tool_name
          ) VALUES (?, ?, ?, 'tool', 'Performed substantial workflow work', 'completed', 'browser')`,
        ).run(randomUUID(), runId, index);
      }
    };

    const { SkillRunner } = require('../../../server/services/ai/toolRunner');
    const { serializeInstalledSkill } = require('../../../server/services/skills/runtime');
    const {
      markLearningUserEdited,
    } = require('../../../server/services/skills/learning_documents');
    const { SkillLearningService } = require('../../../server/services/skills/learning_service');
    const { migrateSkillLearning } = require('../../../lib/schema_migrations');
    const skillRunner = new SkillRunner();
    await skillRunner.loadSkills();
    assert.ok(ctx.db.prepare(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'skill_learning_candidates'",
    ).get());
    assert.equal(ctx.db.prepare(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'skill_workflow_observations'",
    ).get(), undefined);

    const firstRunId = randomUUID();
    insertRun(firstRunId);
    const responses = [
      {
        decision: 'create',
        workflowKey: 'filtered-report-export',
        title: 'Filtered report export',
        summary: 'A complete reusable report export procedure was demonstrated.',
        confidence: 0.94,
        reason: 'The request and successful execution establish a durable procedure.',
      },
      proposal('filtered-report-export', 'filtered-report-export'),
    ];
    const agentEngine = {
      async inferStructured() {
        return { parsed: responses.shift() };
      },
    };
    const service = new SkillLearningService({
      skillRunner,
      agentEngine,
      detailedRequestChars: 80,
      reviewActivityThreshold: 50,
    });
    const learned = await service.observeCompletedRun({
      userId: user.userId,
      agentId,
      runId: firstRunId,
      triggerType: 'user',
      triggerSource: 'web',
      task: 'Export it.',
      finalContent: 'The filtered report was exported and verified.',
      messages: [{
        role: 'user',
        content: 'First select the requested reporting period, preserve the applied filters, export the file, and verify that the downloaded report matches those filters.',
      }],
      iterations: 2,
    });

    assert.equal(learned.success, true);
    assert.equal(learned.action, 'created');
    const created = skillRunner.getSkill('filtered-report-export', user.userId);
    assert.equal(created.metadata.source, 'learned');
    assert.equal(created.metadata.learning.managed, true);
    assert.match(created.instructions, /## Verification/);
    assert.doesNotMatch(created.instructions, new RegExp(firstRunId));
    const listed = skillRunner.getAll(user.userId).find((skill) => skill.name === created.name);
    assert.deepEqual(serializeInstalledSkill(listed), {
      name: 'filtered-report-export',
      description: 'Export a filtered report and verify the resulting file.',
      enabled: true,
      draft: false,
      category: 'reporting',
      trigger: 'Use when a user needs a report exported for a selected filter.',
      source: 'learned',
      autoCreated: true,
      filePath: created.filePath,
      storeId: '',
      readOnly: false,
      ownerType: 'user',
    });
    const version = ctx.db.prepare(
      `SELECT id, version, status FROM agent_skill_versions
       WHERE skill_id = (SELECT id FROM skills WHERE user_id = ? AND name = ?)`,
    ).get(user.userId, created.name);
    assert.equal(version.version, 1);
    assert.equal(version.status, 'validated');
    const evaluation = ctx.db.prepare(
      'SELECT run_id, outcome FROM agent_skill_evaluations WHERE skill_version_id = ?',
    ).get(version.id);
    assert.equal(evaluation.run_id, firstRunId);
    assert.equal(evaluation.outcome, 'created');

    const editedMetadata = markLearningUserEdited(created.metadata, {
      ...created.metadata,
      trigger: 'Use this user-edited trigger.',
    });
    assert.equal(editedMetadata.learning.managed, false);
    assert.ok(editedMetadata.learning.userEditedAt);
    skillRunner.updateSkill(user.userId, created.name, {
      description: 'User-owned description.',
      instructions: 'Keep this exact user-authored procedure.',
      metadata: editedMetadata,
    });

    const updateRunId = randomUUID();
    insertRun(updateRunId);
    let updateCalls = 0;
    service.agentEngine = {
      async inferStructured() {
        updateCalls += 1;
        return {
          parsed: {
            decision: 'update',
            existingSkillName: created.name,
            workflowKey: 'filtered-report-export',
            confidence: 1,
          },
        };
      },
    };
    const protectedResult = await service.observeCompletedRun({
      userId: user.userId,
      agentId,
      runId: updateRunId,
      triggerType: 'user',
      task: 'Try to revise the existing report-export procedure using the new recovery information from this completed run.',
      finalContent: 'Done.',
    });
    assert.equal(protectedResult, null);
    assert.equal(updateCalls, 1);
    assert.equal(
      skillRunner.getSkill(created.name, user.userId).instructions,
      'Keep this exact user-authored procedure.',
    );

    const minimalRunId = randomUUID();
    insertRun(minimalRunId, 'web', 2);
    let minimalReviewCalls = 0;
    const minimalService = new SkillLearningService({
      skillRunner,
      agentEngine: {
        async inferStructured() {
          minimalReviewCalls += 1;
          return { parsed: { decision: 'create' } };
        },
      },
      detailedRequestChars: 80,
      reviewActivityThreshold: 1,
    });
    const minimalResult = await minimalService.observeCompletedRun({
      userId: user.userId,
      agentId,
      runId: minimalRunId,
      triggerType: 'user',
      triggerSource: 'web',
      task: 'Check one value.',
      finalContent: 'Checked.',
      iterations: 8,
    });
    assert.equal(minimalResult, null);
    assert.equal(minimalReviewCalls, 0);

    const repeatedResponses = [
      {
        decision: 'observe',
        workflowKey: 'archive-project-files',
        title: 'Archive project files',
        summary: 'Collect, archive, and verify a project file set.',
        confidence: 0.72,
      },
      {
        decision: 'observe',
        workflowKey: 'archive-project-files',
        title: 'Archive project files',
        summary: 'Collect, archive, and verify a project file set.',
        confidence: 0.89,
      },
      proposal('archive-project-files', 'archive-project-files'),
    ];
    const repeatedService = new SkillLearningService({
      skillRunner,
      agentEngine: {
        async inferStructured() {
          return { parsed: repeatedResponses.shift() };
        },
      },
      detailedRequestChars: 10000,
      reviewActivityThreshold: 1,
      repeatObservations: 2,
    });
    const repeatInputs = [];
    for (const origin of [
      { triggerType: 'user', triggerSource: 'cowork' },
      { triggerType: 'schedule', triggerSource: 'manual', taskId: 'task-1' },
    ]) {
      const runId = randomUUID();
      insertRun(runId, origin.triggerSource, 3);
      repeatInputs.push({
        userId: user.userId,
        agentId,
        runId,
        triggerType: origin.triggerType,
        triggerSource: origin.triggerSource,
        taskId: origin.taskId,
        task: 'Archive these files.',
        finalContent: 'The archive exists and its contents were checked.',
        iterations: 3,
      });
    }
    const observed = await repeatedService.observeCompletedRun(repeatInputs[0]);
    assert.equal(observed.observed, true);
    assert.equal(skillRunner.getSkill('archive-project-files', user.userId), null);
    const duplicate = repeatedService.repository.observeCandidate({
      userId: user.userId,
      workflowKey: 'archive-project-files',
      title: 'Archive project files',
      summary: 'The same run was delivered twice.',
      runId: repeatInputs[0].runId,
    });
    assert.equal(duplicate.observationCount, 1);
    const repeated = await repeatedService.observeCompletedRun(repeatInputs[1]);
    assert.equal(repeated.success, true);
    assert.equal(repeated.action, 'created');
    assert.ok(skillRunner.getSkill('archive-project-files', user.userId));
    const candidate = ctx.db.prepare(
      `SELECT observation_count, status, skill_name FROM skill_learning_candidates
       WHERE user_id = ? AND workflow_key = ?`,
    ).get(user.userId, 'archive-project-files');
    assert.equal(candidate.observation_count, 2);
    assert.equal(candidate.status, 'promoted');
    assert.equal(candidate.skill_name, 'archive-project-files');

    skillRunner.createSkill(
      user.userId,
      'legacy-demonstration',
      'Legacy demonstration.',
      'Legacy instructions.',
      { source: 'teach', workflow_signature: 'legacy-computer-flow' },
    );
    migrateSkillLearning(ctx.db);
    const migrated = JSON.parse(ctx.db.prepare(
      'SELECT metadata FROM skills WHERE user_id = ? AND name = ?',
    ).get(user.userId, 'legacy-demonstration').metadata);
    assert.equal(migrated.source, 'learned');
    assert.equal(migrated.category, 'computer');
    assert.equal(migrated.learning.origin, 'computer-demonstration');
    assert.equal(migrated.learning.workflowKey, 'legacy-computer-flow');
    assert.equal(migrated.learning.managed, true);

    await service.shutdown();
    await minimalService.shutdown();
    await repeatedService.shutdown();
  } finally {
    teardownTestRuntime(ctx);
  }
});
