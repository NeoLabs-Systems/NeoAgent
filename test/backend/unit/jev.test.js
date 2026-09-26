'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

const ENV_KEYS = ['OPENROUTER_API_KEY', 'NEOAGENT_JEV'];
let ctx;
let savedEnv;
let requests;
let nextResponse;

const QUESTIONS = {
  should_act: { type: 'noul', instructions: 'Act now.' },
  team: { type: 'choice', instructions: 'Which team?', criteria: { billing: 'Money', tech: 'Bugs' } },
};
const ANSWERS = {
  should_act: { type: 'noul', noul: 0.91 },
  team: { type: 'choice', choice: 'tech', confidence: 0.8, probabilities: { billing: 0.1, tech: 0.9 } },
};

// jev.js creates its OpenRouter provider through the model registry, which
// reads the network helper at load time; stub it after the runtime reset.
function stubNetwork() {
  const httpPath = require.resolve('../../../server/services/network/http');
  require(httpPath);
  require.cache[httpPath].exports.fetchResponseText = async (url, options) => {
    requests.push({ url, options, body: JSON.parse(options.body) });
    return nextResponse();
  };
}

function ok(payload) {
  return () => ({ response: { ok: true, status: 200 }, text: JSON.stringify(payload) });
}

async function setup({ jevEnabled = true, key = 'sk-or-test' } = {}) {
  ctx = createTestRuntime();
  stubNetwork();
  process.env.OPENROUTER_API_KEY = key;
  const user = await createTestUser(ctx.db, { username: `jev_${Date.now()}` });
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const agentId = resolveAgentId(user.userId, null);
  ctx.db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, 'jev_enabled', ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
  ).run(user.userId, agentId, JSON.stringify(jevEnabled));
  return { userId: user.userId, agentId, jev: require('../../../server/services/ai/jev') };
}

beforeEach(() => {
  savedEnv = Object.fromEntries(ENV_KEYS.map((key) => [key, process.env[key]]));
  for (const key of ENV_KEYS) delete process.env[key];
  requests = [];
  nextResponse = ok({ model: 'typesafe/jev-1.13-20260917', answers: ANSWERS, usage: { input_tokens: 400, output_tokens: 20, cost: 0.0000168 } });
});

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
  for (const [key, value] of Object.entries(savedEnv)) {
    if (value == null) delete process.env[key];
    else process.env[key] = value;
  }
});

test('an agent with Jev on gets validated answers from the System One endpoint', async () => {
  const { userId, agentId, jev } = await setup();

  const answers = await jev.decide({ userId, agentId, phase: 'jev_test', state: { text: 'hi' }, questions: QUESTIONS });

  assert.deepEqual(answers, ANSWERS);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].url, 'https://openrouter.ai/api/v1/systemone');
  assert.equal(requests[0].options.method, 'POST');
  assert.equal(requests[0].options.headers.Authorization, 'Bearer sk-or-test');
  assert.deepEqual(requests[0].body, { model: 'typesafe/jev-1.13', state: { text: 'hi' }, questions: QUESTIONS });
});

test('Jev stays silent when the agent has it off, when the server turns it off, or without an OpenRouter key', async () => {
  let setupResult = await setup({ jevEnabled: false });
  assert.equal(setupResult.jev.isJevEnabled(setupResult.userId, setupResult.agentId), false);
  assert.equal(await setupResult.jev.decide({ ...setupResult, phase: 'jev_test', state: {}, questions: QUESTIONS }), null);
  teardownTestRuntime(ctx);

  setupResult = await setup({ jevEnabled: true });
  process.env.NEOAGENT_JEV = 'off';
  assert.equal(setupResult.jev.isJevEnabled(setupResult.userId, setupResult.agentId), false);
  delete process.env.NEOAGENT_JEV;
  process.env.OPENROUTER_API_KEY = '';
  assert.equal(setupResult.jev.isJevEnabled(setupResult.userId, setupResult.agentId), false);
  assert.equal(requests.length, 0);
});

test('the server policy "on" turns Jev on for agents that never switched it on', async () => {
  const { userId, agentId, jev } = await setup({ jevEnabled: false });
  process.env.NEOAGENT_JEV = 'on';
  assert.equal(jev.getJevPolicy(), 'on');
  assert.equal(jev.isJevEnabled(userId, agentId), true);
  process.env.NEOAGENT_JEV = 'sideways';
  assert.equal(jev.getJevPolicy(), 'agent');
});

test('malformed answers and provider failures fall back to the model path', async () => {
  const { userId, agentId, jev } = await setup();
  const request = { userId, agentId, phase: 'jev_test', state: {}, questions: QUESTIONS };

  nextResponse = ok({ answers: { ...ANSWERS, should_act: { type: 'noul', noul: 1.4 } } });
  assert.equal(await jev.decide(request), null);

  nextResponse = ok({ answers: { should_act: ANSWERS.should_act } });
  assert.equal(await jev.decide(request), null);

  nextResponse = ok({ answers: { ...ANSWERS, team: { ...ANSWERS.team, choice: 'sales' } } });
  assert.equal(await jev.decide(request), null);

  nextResponse = () => ({ response: { ok: false, status: 429 }, text: '{"error":{"message":"Rate limit exceeded"}}' });
  assert.equal(await jev.decide(request), null);

  nextResponse = () => { throw new Error('socket hang up'); };
  assert.equal(await jev.decide(request), null);
});

test('a cancelled run still stops a pending decision', async () => {
  const { userId, agentId, jev } = await setup();
  const controller = new AbortController();
  nextResponse = () => {
    controller.abort();
    const error = new Error('aborted');
    error.name = 'AbortError';
    throw error;
  };
  await assert.rejects(
    jev.decide({ userId, agentId, phase: 'jev_test', state: {}, questions: QUESTIONS, signal: controller.signal }),
    /aborted/,
  );
});

test('decisions made inside a run are ledgered with their cost and answers', async () => {
  const { userId, agentId, jev } = await setup();
  ctx.db.prepare(
    `INSERT INTO agent_runs (id, user_id, agent_id, title, status, trigger_type, trigger_source)
     VALUES ('run-jev', ?, ?, 'test', 'running', 'user', 'web')`,
  ).run(userId, agentId);

  await jev.decide({ userId, agentId, runId: 'run-jev', phase: 'jev_triage', state: {}, questions: QUESTIONS });

  const row = ctx.db.prepare('SELECT * FROM agent_model_usage WHERE run_id = ?').get('run-jev');
  assert.equal(row.phase, 'jev_triage');
  assert.equal(row.provider, 'openrouter');
  assert.equal(row.model, 'typesafe/jev-1.13-20260917');
  assert.equal(row.input_tokens, 400);
  assert.equal(row.estimated_cost_usd, 0.0000168);
  assert.deepEqual(JSON.parse(row.metadata_json).answers, {
    should_act: 0.91,
    team: { choice: 'tech', confidence: 0.8 },
  });
});

test('jev_enabled defaults off and only a real true switches it on', async () => {
  const { userId, agentId } = await setup({ jevEnabled: 'yes' });
  const { createDefaultAiSettings, getAiSettings } = require('../../../server/services/ai/settings');
  assert.equal(createDefaultAiSettings().jev_enabled, false);
  assert.equal(getAiSettings(userId, agentId).jev_enabled, false);
});

test('admins set the server policy through the env file', async () => {
  await setup();
  const fs = require('node:fs');
  const { getJevSettings, setJevPolicy } = require('../../../server/services/admin/server_config');

  assert.deepEqual(getJevSettings(), { policy: 'agent', serverOpenRouterKey: true });
  assert.deepEqual(setJevPolicy('on'), { ok: true, policy: 'on' });
  assert.equal(process.env.NEOAGENT_JEV, 'on');
  assert.match(fs.readFileSync(process.env.NEOAGENT_ENV_FILE, 'utf8'), /^NEOAGENT_JEV=on$/m);

  setJevPolicy('agent');
  assert.equal(process.env.NEOAGENT_JEV, undefined);
  assert.throws(() => setJevPolicy('always'), /policy must be one of/);
});

test('OpenRouter chat requests carry the session id routing models need', () => {
  const { OpenRouterProvider } = require('../../../server/services/ai/providers/openrouter');
  const provider = new OpenRouterProvider({ apiKey: 'test-key' });
  const messages = [{ role: 'user', content: 'hi' }];
  assert.equal(provider._buildParams('typesafe/jev-router', messages, [], { sessionId: 'conv-1' }).session_id, 'conv-1');
  assert.equal(provider._buildParams('typesafe/jev-router', messages, [], {}).session_id, undefined);
});

test('browser_act is offered only while Jev is on, and only on the cloud computer browser', async () => {
  const { userId, agentId } = await setup({ jevEnabled: false });
  const { executeTool, getAvailableTools } = require('../../../server/services/ai/tools');
  const names = () => getAvailableTools(null, { userId, agentId }).map((tool) => tool.name);

  assert.equal(names().includes('browser_act'), false);
  const off = await executeTool('browser_act', { goal: 'Search the weather' }, { userId, agentId }, {});
  assert.match(off.error, /needs Jev/);

  process.env.NEOAGENT_JEV = 'on';
  assert.equal(names().includes('browser_act'), true);
  const runtimeManager = {
    getActiveBrowserBackend: () => 'local-computer',
    getBrowserProviderForUser: async () => ({}),
  };
  const local = await executeTool('browser_act', { goal: 'Search the weather' }, {
    userId,
    agentId,
    app: { locals: { runtimeManager } },
  }, {});
  assert.match(local.error, /cloud computer browser/);
  assert.equal((await executeTool('browser_act', {}, { userId, agentId }, {})).error, 'browser_act requires a "goal" argument');
});
