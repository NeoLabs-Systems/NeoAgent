'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { afterEach, test } = require('node:test');

const Database = require('better-sqlite3');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('skill ownership migration rebuilds the legacy table with sentinel ownership', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-skill-migration-'));
  const dbPath = path.join(dir, 'skills.db');
  const db = new Database(dbPath);
  try {
    db.exec(`
      CREATE TABLE skills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        file_path TEXT NOT NULL,
        metadata TEXT DEFAULT '{}',
        enabled INTEGER DEFAULT 1,
        auto_created INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      );
      INSERT INTO skills (name, description, file_path)
      VALUES ('legacy-skill', 'Legacy skill', '/tmp/legacy-skill.md');
    `);

    const { migrateSkillOwnership } = require('../../../lib/schema_migrations');
    migrateSkillOwnership(db);

    const columns = db.prepare("PRAGMA table_info(skills)").all();
    assert.equal(columns.some((column) => column.name === 'user_id'), true);

    const row = db.prepare('SELECT user_id, name FROM skills WHERE name = ?').get('legacy-skill');
    assert.equal(row.user_id, 0);

    db.prepare(
      `INSERT INTO skills (user_id, name, description, file_path)
       VALUES (?, ?, ?, ?)`
    ).run(1, 'legacy-skill', 'User one', '/tmp/user-one.md');
    db.prepare(
      `INSERT INTO skills (user_id, name, description, file_path)
       VALUES (?, ?, ?, ?)`
    ).run(2, 'legacy-skill', 'User two', '/tmp/user-two.md');

    const rows = db.prepare(
      'SELECT user_id, name FROM skills WHERE name = ? ORDER BY user_id ASC'
    ).all('legacy-skill');
    assert.deepEqual(rows.map((item) => item.user_id), [0, 1, 2]);
  } finally {
    db.close();
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('skill runner isolates user-owned skills and allows same names per user', async () => {
  ctx = createTestRuntime();
  const userA = await createTestUser(ctx.db, { username: 'skill_owner_a' });
  const userB = await createTestUser(ctx.db, { username: 'skill_owner_b' });
  const { SkillRunner } = require('../../../server/services/ai/toolRunner');
  const runner = new SkillRunner();
  await runner.loadSkills();

  const sharedA = runner.createSkill(
    userA.userId,
    'Shared Skill',
    'User A shared skill',
    'A instructions',
    { category: 'workflow' },
  );
  const sharedB = runner.createSkill(
    userB.userId,
    'Shared Skill',
    'User B shared skill',
    'B instructions',
    { category: 'workflow' },
  );
  const privateB = runner.createSkill(
    userB.userId,
    'Private B Skill',
    'Only user B should see this',
    'B private instructions',
    { category: 'workflow' },
  );

  assert.equal(sharedA.success, true);
  assert.equal(sharedB.success, true);
  assert.equal(privateB.success, true);

  await runner.loadSkills();

  const userASkill = runner.getSkill('shared-skill', userA.userId);
  const userBSkill = runner.getSkill('shared-skill', userB.userId);
  assert.ok(userASkill?.filePath.includes(`/users/${userA.userId}/shared-skill/`));
  assert.ok(userBSkill?.filePath.includes(`/users/${userB.userId}/shared-skill/`));
  assert.notEqual(userASkill.filePath, userBSkill.filePath);

  const userASkills = runner.getAll(userA.userId).map((skill) => skill.name);
  const userBSkills = runner.getAll(userB.userId).map((skill) => skill.name);
  assert.equal(userASkills.includes('private-b-skill'), false);
  assert.equal(userBSkills.includes('private-b-skill'), true);

  const userAPrompt = runner.getSkillsForPrompt({ userId: userA.userId });
  assert.match(userAPrompt, /shared-skill/);
  assert.doesNotMatch(userAPrompt, /private-b-skill/);

  const db = require('../../../server/db/database');
  const rows = db.prepare(
    'SELECT user_id, name FROM skills WHERE name = ? ORDER BY user_id ASC'
  ).all('shared-skill');
  assert.deepEqual(rows.map((item) => item.user_id), [userA.userId, userB.userId]);
});

test('global and foreign-user skills are not editable through the runner', async () => {
  ctx = createTestRuntime();
  const userA = await createTestUser(ctx.db, { username: 'skill_editor_a' });
  const userB = await createTestUser(ctx.db, { username: 'skill_editor_b' });
  const { SkillRunner } = require('../../../server/services/ai/toolRunner');
  const runner = new SkillRunner();

  const globalSkillDir = path.join(ctx.agentDataDir, 'skills');
  fs.mkdirSync(globalSkillDir, { recursive: true });
  fs.writeFileSync(
    path.join(globalSkillDir, 'global-doc.md'),
    [
      '---',
      'name: global-doc',
      'description: Global read only skill',
      'category: docs',
      '---',
      '',
      'Global instructions',
    ].join('\n'),
    'utf-8',
  );

  await runner.loadSkills();
  const owned = runner.createSkill(
    userA.userId,
    'User A Only',
    'Owned by user A',
    'Owned instructions',
    { category: 'workflow' },
  );
  assert.equal(owned.success, true);
  await runner.loadSkills();

  assert.ok(runner.getSkill('global-doc', userA.userId));
  assert.equal(runner.getSkill('user-a-only', userB.userId), null);

  const globalUpdate = runner.updateSkill(userA.userId, 'global-doc', {
    instructions: 'Nope',
  });
  const globalDelete = runner.deleteSkill(userA.userId, 'global-doc');
  assert.equal(globalUpdate.code, 'forbidden');
  assert.equal(globalDelete.code, 'forbidden');

  const foreignDelete = runner.deleteSkill(userB.userId, 'user-a-only');
  const foreignUpdate = runner.updateSkill(userB.userId, 'user-a-only', {
    instructions: 'Nope',
  });
  assert.match(foreignDelete.error, /not found/i);
  assert.match(foreignUpdate.error, /not found/i);

  const db = require('../../../server/db/database');
  const ownerRow = db.prepare(
    'SELECT user_id FROM skills WHERE name = ?'
  ).get('user-a-only');
  assert.equal(ownerRow.user_id, userA.userId);
});
