'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { before, after, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { createTestApp, loginAs } = require('../../helpers/app');
const { agent, request } = require('../../helpers/supertest');

const SCANNED_ENV = ['HOME', 'OPENCLAW_STATE_DIR', 'HERMES_HOME'];
const previousEnv = Object.fromEntries(SCANNED_ENV.map((key) => [key, process.env[key]]));
let ctx;
let app;
let admin;
let member;
let owner;
let openclawHome;

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}

// A small OpenClaw install in the test's home folder: one agent with a
// personality and memories, a key, a skill, a remote MCP server and a local
// one the importer leaves behind for the agent to finish.
function buildOpenClaw(home) {
  const root = path.join(home, '.openclaw');
  const ws = path.join(root, 'workspace');
  write(path.join(root, 'openclaw.json'), JSON.stringify({
    agents: { defaults: { workspace: ws, model: { primary: 'openai/gpt-5.5' } } },
    mcp: { servers: {
      linear: { url: 'https://mcp.linear.app/mcp' },
      fs: { command: 'npx', args: ['-y', 'server-filesystem'] },
    } },
  }));
  write(path.join(root, '.env'), 'OPENAI_API_KEY=sk-imported\n');
  write(path.join(ws, 'SOUL.md'), '# SOUL.md - Who You Are\n\nBe brief.\n');
  write(path.join(ws, 'MEMORY.md'), '# MEMORY.md\n\n## People\n- Anna lives in Hamburg.\n');
  write(path.join(ws, 'skills', 'meal-planner', 'SKILL.md'), '---\nname: meal-planner\ndescription: Plans dinners\n---\nUse the terminal tool.\n');
  return root;
}

before(async () => {
  ctx = createTestRuntime();
  const userHome = path.join(ctx.dir, 'user-home');
  openclawHome = buildOpenClaw(userHome);
  process.env.HOME = userHome;
  delete process.env.OPENCLAW_STATE_DIR;
  delete process.env.HERMES_HOME;
  app = createTestApp().app;
  owner = await createTestUser(ctx.db, { username: 'import_admin' });
  const user = await createTestUser(ctx.db, { username: 'import_member' });
  ctx.db.prepare('UPDATE users SET is_admin = ? WHERE id = ?').run(1, owner.userId);
  ctx.db.prepare('UPDATE users SET is_admin = ? WHERE id = ?').run(0, user.userId);
  admin = agent(app);
  member = agent(app);
  await loginAs(admin, owner);
  await loginAs(member, user);
});

after(() => {
  for (const [key, value] of Object.entries(previousEnv)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  teardownTestRuntime(ctx);
});

function envFile() {
  return fs.existsSync(ctx.envFile) ? fs.readFileSync(ctx.envFile, 'utf8') : '';
}

function skillCount() {
  return ctx.db.prepare("SELECT COUNT(*) AS count FROM skills WHERE user_id = ? AND name = 'meal-planner'").get(owner.userId)?.count;
}

test('only admins can see and run the import', async () => {
  await request(app).get('/api/admin/import/sources').expect(401);
  await member.get('/api/admin/import/sources').expect(403);
  await member.post('/api/admin/import').send({ sources: [openclawHome] }).expect(403);
});

test('the sources list shows what each install holds and which parts can be chosen', async () => {
  const res = await admin.get('/api/admin/import/sources').expect(200);
  assert.deepEqual(res.body.parts, ['keys', 'memories', 'skills', 'model', 'tasks', 'mcp', 'channels']);
  assert.equal(res.body.aiReady, false);
  assert.equal(res.body.sources.length, 1);
  const [source] = res.body.sources;
  assert.equal(source.id, openclawHome);
  assert.equal(source.label, 'OpenClaw');
  assert.equal(source.path, '~/.openclaw');
  const parts = Object.fromEntries(source.contents.map((entry) => [entry.part, entry]));
  assert.deepEqual(parts.keys.names, ['OpenAI']);
  assert.deepEqual(parts.skills.names, ['meal-planner']);
  assert.deepEqual(parts.mcp.names, ['linear']);
  assert.ok(parts.memories.count >= 1);
});

test('bad requests are refused before anything is written', async () => {
  await admin.post('/api/admin/import').send({}).expect(400);
  await admin.post('/api/admin/import').send({ sources: [] }).expect(400);
  await admin.post('/api/admin/import').send({ sources: [openclawHome], parts: ['passwords'] }).expect(400);
  await admin.post('/api/admin/import').send({ sources: [openclawHome], finish: 'yes' }).expect(400);
  const missing = await admin.post('/api/admin/import').send({ sources: ['/nowhere/.openclaw'] }).expect(404);
  assert.equal(missing.body.code, 'IMPORT_SOURCE_NOT_FOUND');
  assert.doesNotMatch(envFile(), /sk-imported/);
});

test('parts left out are not brought over, and the summary says what was', async () => {
  const res = await admin.post('/api/admin/import')
    .send({ sources: [openclawHome], parts: ['memories', 'mcp'], finish: true })
    .expect(200);
  assert.doesNotMatch(envFile(), /sk-imported/);
  assert.equal(skillCount(), 0);
  assert.ok(ctx.db.prepare("SELECT id FROM mcp_servers WHERE user_id = ? AND name = 'linear'").get(owner.userId));
  assert.ok(res.body.broughtOver.some((line) => /memor/.test(line)));
  assert.ok(res.body.broughtOver.some((line) => /MCP server/.test(line)));
  assert.equal(res.body.restartRequired, true);
  // No AI is connected yet, so the agent cannot be asked to finish.
  assert.equal(res.body.finishTask, null);
  assert.ok(fs.existsSync(res.body.reportFile));
});

test('a second run brings the rest and queues the finish task once an AI is there', async () => {
  const res = await admin.post('/api/admin/import')
    .send({ sources: [openclawHome], finish: true })
    .expect(200);
  assert.match(envFile(), /^OPENAI_API_KEY=sk-imported$/m);
  assert.equal(skillCount(), 1);
  assert.ok(res.body.alreadyThere > 0);
  assert.match(res.body.finishTask, /^Finish moving in from OpenClaw/);
  const task = ctx.db.prepare('SELECT name FROM scheduled_tasks WHERE user_id = ? AND name = ?').get(owner.userId, res.body.finishTask);
  assert.ok(task);
});

test('repeating the import changes nothing', async () => {
  const res = await admin.post('/api/admin/import').send({ sources: [openclawHome], finish: true }).expect(200);
  assert.deepEqual(res.body.broughtOver, []);
  assert.equal(res.body.finishTask, null);
  assert.equal(res.body.restartRequired, false);
});
