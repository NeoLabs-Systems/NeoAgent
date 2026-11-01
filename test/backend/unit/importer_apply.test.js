'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

// apply.js reads runtime paths when it is first required, so it is loaded
// fresh against each test runtime.
function loadImporter() {
  for (const key of Object.keys(require.cache)) {
    if (key.includes(`${path.sep}lib${path.sep}importers${path.sep}`)) delete require.cache[key];
  }
  return require('../../../lib/importers/apply');
}

function bundle(overrides = {}) {
  const skillDir = path.join(ctx.dir, 'source-skill');
  fs.mkdirSync(path.join(skillDir, 'scripts'), { recursive: true });
  fs.writeFileSync(path.join(skillDir, 'scripts', 'run.sh'), 'echo hi\n');
  return {
    source: 'openclaw',
    label: 'OpenClaw',
    path: '~/.openclaw',
    home: '/src/.openclaw',
    agents: [
      {
        key: 'jarvis',
        name: 'Jarvis',
        isDefault: true,
        instructions: 'Your name is Jarvis.\n\nBe brief.',
        memories: [{ text: 'Sister Anna lives in Hamburg.', category: 'contacts' }],
        userProfile: 'Name: Neo',
        dailyLogs: [{ date: '2026-10-30', content: '- booked a table' }],
        model: null,
      },
      { key: 'coder', name: 'Cody', isDefault: false, instructions: 'Keep diffs small.', memories: [], userProfile: null, dailyLogs: [], model: null },
    ],
    skills: [{ name: 'meal-planner', description: 'Plans dinners', body: 'Use the terminal tool.', dir: skillDir, files: [path.join('scripts', 'run.sh')] }],
    keys: { OPENAI_API_KEY: 'sk-test', OLLAMA_URL: 'http://10.0.0.3:11434' },
    ignoredKeys: ['GROQ_API_KEY'],
    sourceModel: 'openai/gpt-5.5',
    model: 'openai::gpt-5.5',
    mcp: [{ name: 'linear', url: 'https://mcp.linear.app/mcp', token: 'lin', headers: { 'X-Team': 'home' }, transport: 'streamable-http', enabled: true }],
    tasks: [
      { name: 'Briefing', agentKey: 'jarvis', prompt: 'Brief me', trigger: { mode: 'recurring', cronExpression: '0 7 * * 1-5' }, enabled: true, notify: { platform: 'telegram', to: '123' }, model: null, note: null },
      { name: 'Triage', agentKey: 'coder', prompt: 'Triage', trigger: { mode: 'recurring', cronExpression: '0 9 * * 1' }, enabled: false, notify: null, model: null, note: null },
    ],
    channels: [{ platform: 'telegram', config: { botToken: '1:tg' }, allow: ['123', '@name'] }],
    timezone: 'Europe/Berlin',
    skipped: [{ kind: 'MCP server', name: 'fs', reason: 'local program' }],
    ...overrides,
  };
}

async function runImport(userId, source) {
  const { ImportSession } = loadImporter();
  const { openNeoAgent } = require('../../../lib/importers/neoagent');
  const session = new ImportSession(openNeoAgent(), userId);
  await session.applyBundle(source, (label, run) => run());
  return session;
}

test('imports a bundle into NeoAgent, and a second run changes nothing', async () => {
  ctx = createTestRuntime();
  fs.writeFileSync(ctx.envFile, 'OLLAMA_URL=http://localhost:11434\n');
  const { userId } = await createTestUser(ctx.db);
  const source = bundle();

  const first = await runImport(userId, source);
  const failed = first.entries.filter((entry) => entry.status === 'failed');
  assert.deepEqual(failed, []);

  const env = fs.readFileSync(ctx.envFile, 'utf8');
  assert.match(env, /OPENAI_API_KEY=sk-test/);
  assert.match(env, /OLLAMA_URL=http:\/\/10\.0\.0\.3:11434/, 'the install default is replaced');

  const agents = ctx.db.prepare('SELECT slug, instructions FROM agents WHERE user_id = ? ORDER BY slug').all(userId);
  assert.deepEqual(agents.map((agent) => agent.slug), ['cody', 'main']);
  assert.equal(agents.find((agent) => agent.slug === 'main').instructions, 'Your name is Jarvis.\n\nBe brief.');

  const skill = ctx.db.prepare('SELECT file_path FROM skills WHERE user_id = ? AND name = ?').get(userId, 'meal-planner');
  assert.ok(fs.readFileSync(skill.file_path, 'utf8').includes('## NeoAgent Notes'));
  assert.ok(fs.existsSync(path.join(path.dirname(skill.file_path), 'scripts', 'run.sh')));

  const mcp = ctx.db.prepare('SELECT command, config FROM mcp_servers WHERE user_id = ?').get(userId);
  assert.deepEqual(JSON.parse(mcp.config), { transport: 'streamable-http', auth: { type: 'bearer', token: 'lin' }, headers: { 'X-Team': 'home' } });

  const tasks = ctx.db.prepare('SELECT name, cron_expression, enabled, task_config FROM scheduled_tasks WHERE user_id = ? ORDER BY name').all(userId);
  assert.deepEqual(tasks.map((task) => [task.name, task.cron_expression, task.enabled]), [['Briefing', '0 7 * * 1-5', 1], ['Triage', '0 9 * * 1', 0]]);
  assert.deepEqual(JSON.parse(tasks[0].task_config), { prompt: 'Brief me', notifyPlatform: 'telegram', notifyTo: '123' });

  const connection = ctx.db.prepare('SELECT config, status FROM platform_connections WHERE user_id = ?').get(userId);
  assert.ok(connection.config.startsWith('enc:v1:'), 'tokens are stored encrypted');
  const { decryptValue } = require('../../../server/services/integrations/secrets');
  assert.deepEqual(JSON.parse(decryptValue(connection.config)), { botToken: '1:tg', autoConnect: true });
  assert.ok(first.entries.some((entry) => entry.name === 'Telegram @name' && entry.status === 'skipped'));

  const core = ctx.db.prepare("SELECT value FROM core_memory WHERE user_id = ? AND key = 'user_profile'").get(userId);
  assert.match(core.value, /Neo/);
  assert.ok(fs.existsSync(path.join(ctx.agentDataDir, 'users', String(userId), 'daily', '2026-10-30.md')));
  const timezone = ctx.db.prepare("SELECT value FROM user_settings WHERE user_id = ? AND key = 'timezone'").get(userId);
  assert.match(timezone.value, /Europe\/Berlin/);

  const second = await runImport(userId, source);
  assert.deepEqual(second.entries.filter((entry) => entry.status === 'imported'), [], 'nothing is imported twice');
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS count FROM agents WHERE user_id = ?').get(userId).count, 2);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS count FROM scheduled_tasks WHERE user_id = ?').get(userId).count, 2);
  const { hasLeftovers } = require('../../../lib/importers/finish');
  assert.equal(hasLeftovers(second), false, 'a repeat run does not queue the finish again');
});

test('a second source keeps the first personality and gets its own agent', async () => {
  ctx = createTestRuntime();
  const { userId } = await createTestUser(ctx.db);
  await runImport(userId, bundle());
  const hermes = bundle({
    source: 'hermes',
    label: 'Hermes Agent',
    home: '/src/.hermes',
    agents: [{ key: 'default', name: 'Hermes', isDefault: true, instructions: 'You are Max.', memories: [], userProfile: null, dailyLogs: [], model: null }],
    skills: [],
    mcp: [],
    tasks: [],
    channels: [],
    keys: { OPENAI_API_KEY: 'sk-other' },
  });
  const session = await runImport(userId, hermes);

  const main = ctx.db.prepare("SELECT instructions FROM agents WHERE user_id = ? AND slug = 'main'").get(userId);
  assert.equal(main.instructions, 'Your name is Jarvis.\n\nBe brief.');
  const added = ctx.db.prepare("SELECT instructions FROM agents WHERE user_id = ? AND slug = 'hermes'").get(userId);
  assert.equal(added.instructions, 'You are Max.');
  const key = session.entries.find((entry) => entry.name === 'OPENAI_API_KEY');
  assert.equal(key.status, 'exists', 'an existing key is kept');
  assert.match(fs.readFileSync(ctx.envFile, 'utf8'), /OPENAI_API_KEY=sk-test/);
});

test('the finish prompt lists what was left and hides secrets', async () => {
  ctx = createTestRuntime();
  const { userId } = await createTestUser(ctx.db);
  const source = bundle({
    skipped: [{ kind: 'MCP server', name: 'github', reason: 'local program', detail: { command: 'docker', env: { GITHUB_TOKEN: 'ghp_secret' } } }],
  });
  const session = await runImport(userId, source);
  const { buildFinishPrompt, hasLeftovers } = require('../../../lib/importers/finish');
  assert.equal(hasLeftovers(session), true);
  const prompt = buildFinishPrompt([source], session);
  assert.match(prompt, /MCP server "github"/);
  assert.match(prompt, /Do not use execute_command/);
  assert.doesNotMatch(prompt, /ghp_secret/);
});
