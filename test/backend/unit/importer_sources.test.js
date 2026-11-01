'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { afterEach, test } = require('node:test');
const Database = require('better-sqlite3');

const memoryText = require('../../../lib/importers/memory_text');
const schedules = require('../../../lib/importers/schedules');
const { findOpenClawHomes, scanOpenClaw } = require('../../../lib/importers/openclaw');
const { findHermesHomes, scanHermes } = require('../../../lib/importers/hermes');

let tmp;

afterEach(() => {
  if (tmp) fs.rmSync(tmp, { recursive: true, force: true });
  tmp = null;
});

function makeHome() {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-import-'));
  return tmp;
}

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}

const TEMPLATE_AGENTS = '# AGENTS.md\nThis folder is home. Treat it that way.\n';

function buildOpenClaw(home) {
  const root = path.join(home, '.openclaw');
  write(path.join(root, 'openclaw.json'), `{
    // hand-edited, JSON5
    agents: {
      defaults: { workspace: "${root}/workspace", model: { primary: "anthropic/claude-opus-4-6" }, systemAgent: { agentId: "jarvis" } },
      entries: {
        jarvis: { name: "Jarvis", workspace: "${root}/workspace", identity: { name: "Jarvis" } },
        coder: { workspace: "${root}/workspace-coder", identity: { name: "Cody" }, model: "openai/gpt-5.5" },
      },
    },
    models: { providers: { lmstudio: { baseUrl: "http://10.0.0.2:1234/v1", apiKey: "lm", api: "openai-completions" } } },
    mcp: { servers: {
      linear: { url: "https://mcp.linear.app/mcp", headers: { Authorization: "Bearer \${LINEAR_TOKEN}" } },
      fs: { command: "npx", args: ["-y", "server-filesystem"], env: { API_TOKEN: "secret" } },
    } },
    channels: {
      telegram: { botToken: { source: "env", id: "TG_TOKEN" }, allowFrom: ["123", "@someone", "-100200"] },
      slack: { botToken: "xoxb", appToken: "xapp", mode: "socket" },
    },
  }`);
  write(path.join(root, '.env'), [
    'export OPENAI_API_KEY="sk-openai"',
    "GEMINI_API_KEY='gem-key'",
    'BRAVE_API_KEY=brave # inline comment',
    'TG_TOKEN=123:telegram',
    'LINEAR_TOKEN=lin-token',
    'GROQ_API_KEY=groq',
  ].join('\n'));

  const ws = path.join(root, 'workspace');
  write(path.join(ws, 'AGENTS.md'), TEMPLATE_AGENTS);
  write(path.join(ws, 'SOUL.md'), '# SOUL.md - Who You Are\n\nBe brief.\n');
  write(path.join(ws, 'USER.md'), '# USER.md\n- **Name:** Neo\n- **Pronouns:**\n- **Timezone:** Europe/Berlin\n');
  write(path.join(ws, 'MEMORY.md'), '# MEMORY.md\n\n## People\n- Anna lives in Hamburg.\n\n## Projects\n- Home automation: '
    + 'Home Assistant on a Pi. '.repeat(12) + '\n');
  write(path.join(ws, 'memory', '2026-10-30.md'), '- booked a table\n');
  write(path.join(ws, 'skills', 'meal-planner', 'SKILL.md'), '---\nname: meal-planner\ndescription: >\n  Plans dinners\n  for the week.\n---\nBody\n');
  write(path.join(ws, 'skills', 'meal-planner', 'refs', 'pantry.md'), 'flour');
  write(path.join(root, 'skills', 'notes', 'SKILL.md'), 'No frontmatter at all.\n');
  write(path.join(root, 'workspace-coder', 'SOUL.md'), 'Keep diffs small.\n');

  fs.mkdirSync(path.join(root, 'state'), { recursive: true });
  const state = new Database(path.join(root, 'state', 'openclaw.sqlite'));
  state.exec(`CREATE TABLE workspace_generated_bootstrap_hashes (workspace_key TEXT, filename TEXT, sha256 TEXT);
    CREATE TABLE cron_jobs (store_key TEXT, job_id TEXT, job_json TEXT, sort_order INTEGER DEFAULT 0);
    CREATE TABLE secret_store_entries (name TEXT, value TEXT, deleted_at_ms INTEGER);
    CREATE TABLE channel_pairing_allow_entries (channel_key TEXT, entry TEXT, sort_order INTEGER DEFAULT 0);`);
  state.prepare('INSERT INTO workspace_generated_bootstrap_hashes VALUES (?, ?, ?)')
    .run('w', 'AGENTS.md', crypto.createHash('sha256').update(TEMPLATE_AGENTS).digest('hex'));
  state.prepare('INSERT INTO secret_store_entries VALUES (?, ?, NULL)').run('NVIDIA_API_KEY', 'nv-key');
  state.prepare('INSERT INTO channel_pairing_allow_entries VALUES (?, ?, 0)').run('telegram', '456');
  const jobs = [
    { name: 'Heartbeat', declarationKey: 'heartbeat:jarvis', schedule: { kind: 'every', everyMs: 1800000 }, payload: { kind: 'heartbeat' } },
    { name: 'Briefing', schedule: { kind: 'cron', expr: '0 7 * * 1-5', tz: 'Europe/Berlin' }, payload: { kind: 'agentTurn', message: 'Brief me' }, delivery: { channel: 'telegram' } },
    { name: 'Briefing', schedule: { kind: 'cron', expr: '0 7 * * 1-5', tz: 'Europe/Berlin' }, payload: { kind: 'agentTurn', message: 'Brief me' }, delivery: { channel: 'telegram', to: '123' } },
    { name: 'Sweep', schedule: { kind: 'every', everyMs: 90 * 60000 }, payload: { kind: 'agentTurn', message: 'Sweep' } },
    { name: 'Fine', schedule: { kind: 'cron', expr: '30 */15 * * * *' }, payload: { kind: 'agentTurn', message: 'Tick' } },
    { name: 'Backup', schedule: { kind: 'cron', expr: '0 2 * * *' }, payload: { kind: 'command', argv: ['sh', '-lc', 'tar c ~'] } },
    { name: 'Old', schedule: { kind: 'at', at: '2020-01-01T00:00:00Z' }, payload: { kind: 'agentTurn', message: 'Past' } },
    { name: 'Triage', agentId: 'coder', enabled: false, schedule: { kind: 'cron', expr: '0 9 * * 1' }, payload: { kind: 'agentTurn', message: 'Triage' } },
  ];
  jobs.forEach((job, index) => state.prepare('INSERT INTO cron_jobs VALUES (?, ?, ?, ?)').run('s', String(index), JSON.stringify(job), index));
  state.close();

  fs.mkdirSync(path.join(root, 'agents', 'jarvis', 'agent'), { recursive: true });
  const agentDb = new Database(path.join(root, 'agents', 'jarvis', 'agent', 'openclaw-agent.sqlite'));
  agentDb.exec('CREATE TABLE auth_profile_store (store_key TEXT, store_json TEXT)');
  agentDb.prepare('INSERT INTO auth_profile_store VALUES (?, ?)').run('primary', JSON.stringify({
    profiles: {
      'anthropic:default': { type: 'api_key', provider: 'anthropic', key: 'sk-ant' },
      'openai-codex:me': { type: 'oauth', provider: 'openai-codex', access: 'x' },
    },
  }));
  agentDb.close();
  return root;
}

test('finds OpenClaw homes, profiles and pre-rename folders', () => {
  const home = makeHome();
  write(path.join(home, '.openclaw', 'openclaw.json'), '{}');
  write(path.join(home, '.openclaw-work', 'openclaw.json'), '{}');
  write(path.join(home, '.clawdbot', 'clawdbot.json'), '{}');
  write(path.join(home, '.openclaw-empty', 'notes.txt'), '');
  const found = findOpenClawHomes(home, {}).map((dir) => path.basename(dir));
  assert.deepEqual(found, ['.openclaw', '.openclaw-work', '.clawdbot']);
});

test('reads a configured OpenClaw install into a bundle', () => {
  const root = buildOpenClaw(makeHome());
  const bundle = scanOpenClaw(root);

  assert.deepEqual(bundle.agents.map((agent) => [agent.key, agent.name, agent.isDefault]), [
    ['jarvis', 'Jarvis', true],
    ['coder', 'Cody', false],
  ]);
  const jarvis = bundle.agents[0];
  assert.equal(jarvis.instructions, 'Your name is Jarvis.\n\nBe brief.');
  assert.equal(jarvis.userProfile, 'Name: Neo\nTimezone: Europe/Berlin');
  assert.deepEqual(jarvis.memories.map((item) => item.category), ['contacts', 'projects']);
  assert.equal(jarvis.dailyLogs[0].date, '2026-10-30');
  assert.equal(bundle.agents[1].model, 'openai::gpt-5.5');
  assert.ok(!bundle.skipped.some((item) => item.name.endsWith('AGENTS.md')), 'untouched template is not flagged');

  assert.deepEqual(bundle.keys, {
    ANTHROPIC_API_KEY: 'sk-ant',
    OPENAI_API_KEY: 'sk-openai',
    GOOGLE_AI_KEY: 'gem-key',
    NVIDIA_API_KEY: 'nv-key',
    BRAVE_SEARCH_API_KEY: 'brave',
    OPENAI_COMPATIBLE_BASE_URL: 'http://10.0.0.2:1234/v1',
    OPENAI_COMPATIBLE_API_KEY: 'lm',
  });
  assert.deepEqual(bundle.ignoredKeys, ['GROQ_API_KEY']);
  assert.equal(bundle.model, 'anthropic::claude-opus-4-6');
  assert.ok(bundle.skipped.some((item) => item.kind === 'Sign-in' && item.name === 'openai-codex'));

  assert.deepEqual(bundle.skills.map((skill) => skill.name).sort(), ['meal-planner', 'notes']);
  const meal = bundle.skills.find((skill) => skill.name === 'meal-planner');
  assert.equal(meal.description, 'Plans dinners for the week.');
  assert.deepEqual(meal.files, [path.join('refs', 'pantry.md')]);

  assert.deepEqual(bundle.mcp, [{
    name: 'linear', url: 'https://mcp.linear.app/mcp', token: 'lin-token', headers: {}, transport: 'streamable-http', enabled: true,
  }]);
  assert.ok(bundle.skipped.some((item) => item.kind === 'MCP server' && item.name === 'fs'));

  const tasks = Object.fromEntries(bundle.tasks.map((task) => [task.name, task]));
  assert.deepEqual(Object.keys(tasks).sort(), ['Briefing', 'Fine', 'Sweep', 'Triage']);
  assert.deepEqual(tasks.Briefing.notify, { platform: 'telegram', to: '123' }, 'duplicate keeps the chat target');
  assert.equal(tasks.Sweep.trigger.cronExpression, '0 */2 * * *');
  assert.ok(tasks.Sweep.note);
  assert.equal(tasks.Fine.trigger.cronExpression, '*/15 * * * *');
  assert.ok(tasks.Fine.note, 'a non-zero seconds field is reported');
  assert.equal(tasks.Triage.agentKey, 'coder');
  assert.equal(tasks.Triage.enabled, false);
  assert.ok(bundle.skipped.some((item) => item.name === 'Backup'));
  assert.ok(bundle.skipped.some((item) => item.name === 'Old'));
  assert.equal(bundle.timezone, 'Europe/Berlin');

  const telegram = bundle.channels.find((channel) => channel.platform === 'telegram');
  assert.deepEqual(telegram.config, { botToken: '123:telegram' });
  assert.deepEqual(telegram.allow, ['123', '@someone', '-100200', '456']);
  assert.ok(bundle.skipped.some((item) => item.name === 'Slack'));
});

test('reads the pre-2026 OpenClaw layout', () => {
  const home = makeHome();
  const root = path.join(home, '.clawdbot');
  write(path.join(root, 'clawdbot.json'), JSON.stringify({
    agents: { list: [{ id: 'main' }] },
    channels: { telegram: { tokenFile: path.join(root, 'tg.txt') } },
  }));
  write(path.join(root, 'tg.txt'), '999:legacy\n');
  write(path.join(root, 'workspace-main', 'SOUL.md'), 'Old soul.\n');
  write(path.join(root, 'cron', 'jobs.json'), JSON.stringify({ jobs: [
    { name: 'Daily', schedule: { kind: 'cron', expr: '0 8 * * *' }, payload: { kind: 'systemEvent', text: 'Morning' } },
  ] }));
  write(path.join(root, 'agents', 'main', 'agent', 'auth-profiles.json'), JSON.stringify({
    profiles: { 'openrouter:x': { type: 'api_key', provider: 'openrouter', key: 'or-key' } },
  }));
  write(path.join(root, 'credentials', 'telegram-allowFrom.json'), JSON.stringify(['42']));

  const bundle = scanOpenClaw(root);
  assert.equal(bundle.agents[0].instructions, 'Old soul.');
  assert.equal(bundle.tasks[0].prompt, 'Morning');
  assert.equal(bundle.keys.OPENROUTER_API_KEY, 'or-key');
  assert.deepEqual(bundle.channels[0], { platform: 'telegram', config: { botToken: '999:legacy' }, allow: ['42'] });
});

test('a broken OpenClaw config still scans', () => {
  const home = makeHome();
  write(path.join(home, '.openclaw', 'openclaw.json'), '{ this is not json');
  write(path.join(home, '.openclaw', 'workspace', 'MEMORY.md'), '- Likes tea.\n');
  const bundle = scanOpenClaw(path.join(home, '.openclaw'));
  assert.equal(bundle.agents[0].memories[0].text, 'Likes tea.');
});

function buildHermes(home) {
  const root = path.join(home, '.hermes');
  write(path.join(root, 'config.yaml'), [
    'model:',
    '  default: anthropic/claude-sonnet-4.6',
    '  provider: openrouter',
    'timezone: Europe/Berlin',
    'custom_providers:',
    '  - name: box',
    '    base_url: http://10.0.0.3:11434/v1',
    'mcp_servers:',
    '  api:',
    '    url: https://mcp.example.com/mcp',
    '    headers:',
    '      Authorization: Bearer ${MCP_TOKEN}',
    '      X-Team: home',
    '  wiki:',
    '    url: https://mcp.example.com/sse',
    '  local:',
    '    command: npx',
  ].join('\n'));
  write(path.join(root, '.env'), [
    '# TELEGRAM_BOT_TOKEN=',
    'OPENROUTER_API_KEY=or-key',
    'GOOGLE_API_KEY=g-key',
    'MCP_TOKEN=mcp-secret',
    'TELEGRAM_BOT_TOKEN=111:tg',
    'TELEGRAM_ALLOWED_USERS=1, 2',
    'TELEGRAM_HOME_CHANNEL=3',
    'SLACK_BOT_TOKEN=xoxb',
  ].join('\n'));
  write(path.join(root, 'SOUL.md'), 'You are Max.\n');
  write(path.join(root, 'memories', 'MEMORY.md'), 'Runs Proxmox.\n§\nDeploy steps: build, then rsync.\n');
  write(path.join(root, 'memories', 'USER.md'), 'Name: Neo.\n§\nAllergic to peanuts.\n');
  write(path.join(root, 'skills', '.bundled_manifest'), 'arxiv:abc\n');
  write(path.join(root, 'skills', 'research', 'arxiv', 'SKILL.md'), '---\nname: arxiv\n---\nBundled\n');
  write(path.join(root, 'skills', 'personal', 'expenses', 'SKILL.md'), '---\nname: expenses\ndescription: Log spending\n---\nUse scripts/log.py\n');
  write(path.join(root, 'skills', 'personal', 'expenses', 'scripts', 'log.py'), 'print(1)\n');
  write(path.join(root, 'scripts', 'disk.sh'), 'df -h\n');
  write(path.join(root, 'cron', 'jobs.json'), JSON.stringify({ jobs: [
    { name: 'News', prompt: 'AI news', schedule: { kind: 'cron', expr: '0 8 * * *' }, deliver: 'telegram:3', enabled: true, skills: ['weather'] },
    { name: 'Watch', prompt: 'Check server', schedule: { kind: 'interval', minutes: 45 }, deliver: 'local', enabled: true, state: 'paused' },
    { name: 'Disk', prompt: '', script: 'disk.sh', no_agent: true, schedule: { kind: 'cron', expr: '0 * * * *' } },
    { name: 'Soon', prompt: 'Remind me', schedule: { kind: 'once', run_at: '2099-01-01T09:00:00+01:00' } },
  ] }));
  write(path.join(root, 'profiles', 'work', 'SOUL.md'), 'You are Atlas.\n');
  write(path.join(root, 'profiles', 'work', '.env'), 'OPENAI_API_KEY=work-openai\n');
  write(path.join(root, 'profiles', 'work', 'cron', 'jobs.json'), JSON.stringify({ jobs: [
    { name: 'Standup', prompt: 'Prep standup', schedule: { kind: 'cron', expr: '30 9 * * 1-5' } },
  ] }));
  return root;
}

test('reads a configured Hermes install into a bundle', () => {
  const home = makeHome();
  const root = buildHermes(home);
  assert.deepEqual(findHermesHomes(home, {}), [root]);
  const bundle = scanHermes(root);

  assert.deepEqual(bundle.agents.map((agent) => [agent.key, agent.instructions]), [
    ['default', 'You are Max.'],
    ['work', 'You are Atlas.'],
  ]);
  assert.deepEqual(bundle.agents[0].memories.map((item) => item.text), ['Runs Proxmox.', 'Deploy steps: build, then rsync.']);
  assert.equal(bundle.agents[0].memories[1].category, 'procedural');
  assert.equal(bundle.agents[0].userProfile, 'Name: Neo.\nAllergic to peanuts.');
  assert.deepEqual(bundle.skills.map((skill) => skill.name), ['expenses'], 'bundled skills stay behind');
  assert.deepEqual(bundle.keys, {
    OPENROUTER_API_KEY: 'or-key',
    GOOGLE_AI_KEY: 'g-key',
    OPENAI_API_KEY: 'work-openai',
    OLLAMA_URL: 'http://10.0.0.3:11434',
  });
  assert.equal(bundle.model, 'openrouter::anthropic/claude-sonnet-4.6');
  assert.equal(bundle.timezone, 'Europe/Berlin');
  assert.deepEqual(bundle.mcp.map((server) => [server.name, server.transport, server.token, server.headers]), [
    ['api', 'streamable-http', 'mcp-secret', { 'X-Team': 'home' }],
    ['wiki', 'sse', null, {}],
  ]);

  const tasks = Object.fromEntries(bundle.tasks.map((task) => [task.name, task]));
  assert.equal(tasks.News.prompt, 'Use the weather skill.\n\nAI news');
  assert.deepEqual(tasks.News.notify, { platform: 'telegram', to: '3' });
  assert.equal(tasks.Watch.enabled, false);
  assert.equal(tasks.Watch.trigger.cronExpression, '*/30 * * * *');
  assert.equal(tasks.Soon.trigger.mode, 'one_time');
  assert.equal(tasks.Standup.agentKey, 'work');
  const disk = bundle.skipped.find((item) => item.name === 'Disk');
  assert.equal(disk.detail.content, 'df -h\n');

  assert.deepEqual(bundle.channels[0], { platform: 'telegram', config: { botToken: '111:tg' }, allow: ['1', '2', '3'] });
  assert.ok(bundle.skipped.some((item) => item.name === 'Slack'));
});

test('the default Hermes persona and a broken config are left out quietly', () => {
  const home = makeHome();
  write(path.join(home, '.hermes', 'config.yaml'), 'model: [unclosed');
  write(path.join(home, '.hermes', 'SOUL.md'), 'You are Hermes Agent, built by Nous Research. Be direct.\n');
  const bundle = scanHermes(path.join(home, '.hermes'));
  assert.equal(bundle.agents[0].instructions, null);
  assert.equal(bundle.model, null);
});

test('memory entries are split to fit NeoAgent memories', () => {
  const long = `Home automation: ${'The Zigbee network needs to be stable before the move. '.repeat(6)}`;
  const facts = memoryText.toShortFacts(long);
  assert.ok(facts.length > 1);
  for (const fact of facts) {
    assert.ok(fact.length <= memoryText.MAX_FACT_CHARS, fact);
    assert.ok(fact.startsWith('Home automation: '));
  }
  assert.deepEqual(memoryText.toShortFacts('Short one.'), ['Short one.']);
});

test('intervals and cron expressions convert to five-field cron', () => {
  assert.deepEqual(schedules.intervalToCron(30 * 60000), { cron: '*/30 * * * *', exact: true });
  assert.deepEqual(schedules.intervalToCron(2 * 3600000), { cron: '0 */2 * * *', exact: true });
  assert.equal(schedules.intervalToCron(45 * 60000).exact, false);
  assert.deepEqual(schedules.toFiveFieldCron('0 */5 * * * *'), { cron: '*/5 * * * *', exact: true });
  assert.equal(schedules.toFiveFieldCron('not cron'), null);
});

test('a Hermes install on Nous Portal keeps Nous Portal as its provider', () => {
  const home = makeHome();
  write(path.join(home, '.hermes', 'config.yaml'), 'model:\n  default: deepseek/deepseek-v4.1-flash-1017\n  provider: nous-api\n');
  write(path.join(home, '.hermes', '.env'), 'NOUS_API_KEY=sk-nous-test\n');
  const bundle = scanHermes(path.join(home, '.hermes'));
  assert.deepEqual(bundle.keys, { NOUS_API_KEY: 'sk-nous-test' });
  assert.equal(bundle.model, 'nous::deepseek/deepseek-v4.1-flash-1017');
  assert.equal(bundle.sourceModel, 'deepseek/deepseek-v4.1-flash-1017 (Nous Portal)');
});

test('a Nous Portal sign-in without a key is reported', () => {
  const home = makeHome();
  write(path.join(home, '.hermes', 'config.yaml'), 'model:\n  default: hermes-5\n  provider: nous\n');
  const bundle = scanHermes(path.join(home, '.hermes'));
  assert.ok(bundle.skipped.some((item) => item.kind === 'Sign-in' && item.name === 'Nous Portal'));
});
