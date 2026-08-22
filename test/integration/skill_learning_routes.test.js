'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createTestApp, loginAs } = require('../helpers/app');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { agent } = require('../helpers/supertest');

test('learned skills are listed with descriptions and become user-owned when edited', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db);
    const { SkillRunner } = require('../../server/services/ai/toolRunner');
    const skillRunner = new SkillRunner();
    await skillRunner.loadSkills();
    skillRunner.createSkill(
      user.userId,
      'learned-report-export',
      'Export and verify a filtered report.',
      '1. Export the report.\n2. Verify the output file.',
      {
        source: 'learned',
        category: 'reporting',
        trigger: 'Use for filtered report exports.',
        enabled: true,
        draft: false,
        auto_created: true,
        learning: {
          managed: true,
          origin: 'agent-run',
          workflowKey: 'filtered-report-export',
        },
      },
    );

    const { app } = createTestApp({ locals: { skillRunner } });
    const client = agent(app);
    await loginAs(client, user);

    const listed = await client.get('/api/skills').expect(200);
    const skill = listed.body.find((item) => item.name === 'learned-report-export');
    assert.equal(skill.description, 'Export and verify a filtered report.');
    assert.equal(skill.source, 'learned');
    assert.equal(skill.draft, false);
    assert.equal(skill.enabled, true);

    const current = await client.get('/api/skills/learned-report-export').expect(200);
    const editedContent = current.body.content
      .replace(
        'description: Export and verify a filtered report.',
        'description: My edited report workflow.',
      )
      .replace(
        '1. Export the report.\n2. Verify the output file.',
        'Use the procedure I wrote myself.',
      );
    await client.put('/api/skills/learned-report-export')
      .send({ content: editedContent })
      .expect(200);

    const updated = skillRunner.getSkill('learned-report-export', user.userId);
    assert.equal(updated.description, 'My edited report workflow.');
    assert.equal(updated.instructions, 'Use the procedure I wrote myself.');
    assert.equal(updated.metadata.learning.managed, false);
    assert.ok(updated.metadata.learning.userEditedAt);
    const versions = ctx.db.prepare(
      `SELECT version FROM agent_skill_versions
       WHERE skill_id = (SELECT id FROM skills WHERE user_id = ? AND name = ?)
       ORDER BY version`,
    ).all(user.userId, 'learned-report-export');
    assert.deepEqual(versions.map((row) => row.version), [1, 2]);
  } finally {
    teardownTestRuntime(ctx);
  }
});
