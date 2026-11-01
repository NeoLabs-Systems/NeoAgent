'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

async function setup() {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'skill_tools_user' });
  const { SkillRunner } = require('../../../server/services/ai/toolRunner');
  const { executeTool } = require('../../../server/services/ai/tools');
  const skillRunner = new SkillRunner();
  await skillRunner.loadSkills();
  skillRunner.createSkill(user.userId, 'book-haircut', 'Book a haircut', 'Open the salon finder.', {
    auto_created: true,
    source: 'learned',
    learning: { managed: true, observationCount: 3 },
  });
  const run = (name, args) => executeTool(name, args, { userId: user.userId }, { skillRunner });
  return { run, skillRunner, userId: user.userId };
}

test('list_skills loads a skill\'s instructions by name and never hands out host file paths', async () => {
  const { run } = await setup();

  const listed = await run('list_skills', {});
  const entry = listed.skills.find((skill) => skill.name === 'book-haircut');
  assert.ok(entry);
  assert.equal(entry.filePath, undefined);

  const loaded = await run('list_skills', { name: 'book-haircut' });
  assert.equal(loaded.instructions, 'Open the salon finder.');
  assert.match((await run('list_skills', { name: 'missing-skill' })).error, /No skill named/);
});

test('update_skill revises a learned skill and keeps the metadata it was not given', async () => {
  const { run, skillRunner, userId } = await setup();

  const updated = await run('update_skill', {
    name: 'book-haircut',
    instructions: 'Open the new salon finder.',
    metadata: { trigger: 'haircut booking' },
  });
  assert.equal(updated.success, true);

  const skill = skillRunner.getSkill('book-haircut', userId);
  assert.equal(skill.instructions, 'Open the new salon finder.');
  assert.equal(skill.metadata.trigger, 'haircut booking');
  assert.equal(skill.metadata.auto_created, true);
  assert.deepEqual(skill.metadata.learning, { managed: true, observationCount: 3 });
});
