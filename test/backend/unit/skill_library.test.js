'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { buildZip } = require('../../helpers/zip');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

const skillMd = (name, description) => `---\nname: ${name}\ndescription: ${description}\n---\n\n# ${name}\n\nDo the thing.\n`;

test('readZipEntries reads stored and deflated files and rejects non-zips', () => {
  const { readZipEntries } = require('../../../server/utils/zip_reader');
  for (const deflate of [true, false]) {
    const entries = readZipEntries(buildZip({ 'a/b.txt': 'hello', 'c.bin': Buffer.from([0, 1, 2]) }, { deflate }));
    assert.deepEqual(entries.map((entry) => entry.path), ['a/b.txt', 'c.bin']);
    assert.equal(entries[0].data.toString(), 'hello');
  }
  assert.throws(() => readZipEntries(Buffer.from('not a zip at all, sorry')), /not a zip/);

  // An entry that inflates past its declared size is refused, not expanded.
  const bomb = buildZip({ 'big.txt': 'x'.repeat(100000) });
  const sizeOffset = bomb.lastIndexOf(Buffer.from([0x50, 0x4b, 0x01, 0x02])) + 24;
  bomb.writeUInt32LE(10, sizeOffset);
  assert.throws(() => readZipEntries(bomb), (error) => error.status === 400);
});

test('a .claude/skills zip installs every folder as a skill of one library', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'library_user' });
  const other = await createTestUser(ctx.db, { username: 'library_other' });
  const { SkillRunner } = require('../../../server/services/ai/toolRunner');
  const { installSkillLibrary, setSkillLibraryEnabled, deleteSkillLibrary } = require('../../../server/services/skills/skill_library');
  const runner = new SkillRunner();
  await runner.loadSkills();
  runner.createSkill(user.userId, 'taken', 'Mine', 'Mine');

  const archive = buildZip({
    'via-main/.claude/skills/blog-post/SKILL.md': skillMd('blog-post', 'Write a blog post'),
    'via-main/.claude/skills/blog-post/references/style.md': 'Short sentences.',
    'via-main/.claude/skills/blog-post/examples/inner/SKILL.md': skillMd('inner', 'Not its own skill'),
    'via-main/.claude/skills/simulate/SKILL.md': skillMd('simulate', 'Run a simulation'),
    'via-main/kit/skills/simulate/SKILL.md': skillMd('simulate', 'Second copy'),
    'via-main/.claude/skills/taken/SKILL.md': skillMd('taken', 'Clashes'),
    'via-main/../escape/SKILL.md': skillMd('escape', 'Path escape'),
    'via-main/bad\u0000name/SKILL.md': skillMd('nul', 'Control character'),
    '/etc/abs/SKILL.md': skillMd('abs', 'Absolute path'),
    '__MACOSX/via-main/._SKILL.md': 'junk',
  });
  const result = installSkillLibrary(runner, user.userId, { buffer: archive, filename: 'via-main.zip' });
  assert.equal(result.library, 'via-main');
  assert.deepEqual(result.installed.sort(), ['blog-post', 'simulate']);
  assert.deepEqual(result.skipped.map((item) => item.name).sort(), ['simulate', 'taken']);
  assert.equal(runner.getSkill('simulate', user.userId).description, 'Run a simulation');

  const blog = runner.getSkill('blog-post', user.userId);
  assert.equal(blog.metadata.library, 'via-main');
  assert.equal(blog.description, 'Write a blog post');
  assert.match(blog.instructions, /NeoAgent Notes/);
  assert.equal(fs.readFileSync(path.join(blog.dir, 'references', 'style.md'), 'utf8'), 'Short sentences.');
  assert.ok(fs.existsSync(path.join(blog.dir, 'examples', 'inner', 'SKILL.md')));
  assert.equal(runner.getSkill('inner', user.userId), null);
  assert.equal(runner.getSkill('blog-post', other.userId), null);

  // Uploading the same library again replaces its skills instead of clashing,
  // and drops the ones the new zip no longer has.
  const again = installSkillLibrary(runner, user.userId, { buffer: archive, filename: 'via-main.zip' });
  assert.deepEqual(again.installed.sort(), ['blog-post', 'simulate']);
  const trimmed = installSkillLibrary(runner, user.userId, {
    buffer: buildZip({
      'skills/blog-post/SKILL.md': skillMd('blog-post', 'Write a blog post'),
      'skills/simulate/SKILL.md': skillMd('simulate', 'Run a simulation'),
      'skills/new-one/SKILL.md': skillMd('new-one', 'New'),
    }),
    filename: 'whatever.zip',
    name: 'via-main',
  });
  assert.deepEqual(trimmed.removed, []);
  const smaller = installSkillLibrary(runner, user.userId, {
    buffer: buildZip({
      'skills/blog-post/SKILL.md': skillMd('blog-post', 'Write a blog post'),
      'skills/new-one/SKILL.md': skillMd('new-one', 'New'),
    }),
    filename: 'via-main.zip',
  });
  assert.deepEqual(smaller.removed, ['simulate']);
  assert.equal(runner.getSkill('simulate', user.userId), null);

  setSkillLibraryEnabled(runner, user.userId, 'via-main', false);
  assert.equal(runner.getSkill('new-one', user.userId).metadata.enabled, false);

  deleteSkillLibrary(runner, user.userId, 'via-main');
  assert.equal(runner.getSkill('blog-post', user.userId), null);
  assert.ok(runner.getSkill('taken', user.userId));
});

test('a zip with one skill installs a plain skill and an empty one is refused', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'library_single' });
  const { SkillRunner } = require('../../../server/services/ai/toolRunner');
  const { installSkillLibrary } = require('../../../server/services/skills/skill_library');
  const runner = new SkillRunner();
  await runner.loadSkills();

  const single = installSkillLibrary(runner, user.userId, {
    buffer: buildZip({ 'SKILL.md': skillMd('Solo Skill', 'Alone') }),
    filename: 'solo.zip',
  });
  assert.equal(single.library, '');
  assert.deepEqual(single.installed, ['solo-skill']);
  assert.equal(runner.getSkill('solo-skill', user.userId).metadata.library, undefined);

  assert.throws(
    () => installSkillLibrary(runner, user.userId, { buffer: buildZip({ 'readme.md': 'hi' }), filename: 'x.zip' }),
    /No skills found/,
  );
});
