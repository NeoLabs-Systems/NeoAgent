'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createTestApp, loginAs } = require('../helpers/app');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { agent } = require('../helpers/supertest');
const { buildZip } = require('../helpers/zip');

const skillMd = (name) => `---\nname: ${name}\ndescription: ${name} skill\n---\n\nSteps.\n`;

test('a zipped skill folder uploads as a library that switches off and deletes as one', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db);
    const { SkillRunner } = require('../../server/services/ai/toolRunner');
    const skillRunner = new SkillRunner();
    await skillRunner.loadSkills();
    const { app } = createTestApp({ locals: { skillRunner } });
    const client = agent(app);
    await loginAs(client, user);

    const archive = buildZip({
      'skills/alpha/SKILL.md': skillMd('alpha'),
      'skills/beta/SKILL.md': skillMd('beta'),
    });
    const uploaded = await client.post('/api/skills/library?name=My%20Pack')
      .attach('archive', archive, 'skills.zip')
      .expect(201);
    assert.equal(uploaded.body.library, 'my-pack');
    assert.deepEqual(uploaded.body.installed.sort(), ['alpha', 'beta']);

    const listed = await client.get('/api/skills').expect(200);
    assert.deepEqual(
      listed.body.filter((skill) => skill.library === 'my-pack').map((skill) => skill.name).sort(),
      ['alpha', 'beta'],
    );

    await client.put('/api/skills/library/my-pack').send({ enabled: false }).expect(200);
    const off = await client.get('/api/skills').expect(200);
    assert.ok(off.body.filter((skill) => skill.library === 'my-pack').every((skill) => !skill.enabled));

    await client.delete('/api/skills/library/my-pack').expect(200);
    const after = await client.get('/api/skills').expect(200);
    assert.equal(after.body.some((skill) => skill.library === 'my-pack'), false);

    await client.post('/api/skills/library')
      .attach('archive', Buffer.from('not a zip'), 'broken.zip')
      .expect(400);
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('a built-in library is listed and installs over HTTP as one library', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db);
    const { SkillRunner } = require('../../server/services/ai/toolRunner');
    const skillRunner = new SkillRunner();
    await skillRunner.loadSkills();
    const { app } = createTestApp({ locals: { skillRunner } });
    const client = agent(app);
    await loginAs(client, user);

    const catalog = await client.get('/api/skills/builtin-libraries').expect(200);
    const via = catalog.body.find((library) => library.id === 'via');
    assert.ok(via);
    assert.equal(via.skills.length, 9);

    const installed = await client.post('/api/skills/builtin-libraries/via').expect(201);
    assert.equal(installed.body.library, 'via');
    const listed = await client.get('/api/skills').expect(200);
    assert.equal(listed.body.filter((skill) => skill.library === 'via').length, 9);

    await client.post('/api/skills/builtin-libraries/nope').expect(404);
  } finally {
    teardownTestRuntime(ctx);
  }
});
