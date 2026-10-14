'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

const ENV_KEYS = [
  'OPENROUTER_API_KEY',
  'TYPESAFE_API_KEY',
  'OLLAMA_URL',
  'NEOAGENT_DISABLED_MODELS',
  'NEOAGENT_KNOWN_MODELS',
  'NEOAGENT_KNOWN_SYSTEM_ONE_MODELS',
];
const OPENROUTER_DECISIONS_URL = 'https://openrouter.ai/api/v1/models?output_modalities=decisions';
const TYPESAFE_MODELS_URL = 'https://api.typesafe.ai/v1/models';
const OLLAMA_TAGS_URL = 'http://localhost:11434/api/tags';
let ctx;
let savedEnv;
let requests;
let nextResponse;
let openRouterCatalog;
let ollamaTags;

const QUESTIONS = {
  should_act: { type: 'noul', instructions: 'Act now.' },
  team: { type: 'choice', instructions: 'Which team?', criteria: { billing: 'Money', tech: 'Bugs' } },
};
const ANSWERS = {
  should_act: { type: 'noul', noul: 0.91 },
  team: { type: 'choice', choice: 'tech', confidence: 0.8, probabilities: { billing: 0.1, tech: 0.9 } },
};

function catalogModel(id, prompt = '0.000000042') {
  return {
    id,
    name: id,
    architecture: { output_modalities: ['decisions'] },
    pricing: { prompt, completion: '0' },
  };
}

function json(payload) {
  return { response: { ok: true, status: 200 }, text: JSON.stringify(payload) };
}

// The SystemOne providers read the network helper at load time; stub it after
// the runtime reset. Catalog reads answer from the fixtures above, decisions
// from `nextResponse`.
function stubNetwork() {
  const httpPath = require.resolve('../../../server/services/network/http');
  require(httpPath);
  require.cache[httpPath].exports.fetchResponseText = async (url, options = {}) => {
    requests.push({ url, options, body: options.body ? JSON.parse(options.body) : null });
    if (url === OPENROUTER_DECISIONS_URL) return json({ data: openRouterCatalog });
    if (url === TYPESAFE_MODELS_URL) return json({ models: [{ name: 'jev-latest', description: 'General-purpose system one model.' }] });
    if (url === OLLAMA_TAGS_URL) return json({ models: ollamaTags });
    return nextResponse();
  };
}

function ok(payload) {
  return () => json(payload);
}

function decisionRequests() {
  return requests.filter((request) => /systemone$/.test(request.url));
}

async function setup({ selection = 'auto', key = 'sk-or-test' } = {}) {
  ctx = createTestRuntime();
  stubNetwork();
  if (key) process.env.OPENROUTER_API_KEY = key;
  else delete process.env.OPENROUTER_API_KEY;
  const user = await createTestUser(ctx.db, { username: `system_one_${Date.now()}` });
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const agentId = resolveAgentId(user.userId, null);
  ctx.db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, 'system_one_model', ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
  ).run(user.userId, agentId, JSON.stringify(selection));
  return { userId: user.userId, agentId, systemOne: require('../../../server/services/ai/system_one') };
}

beforeEach(() => {
  savedEnv = Object.fromEntries(ENV_KEYS.map((key) => [key, process.env[key]]));
  for (const key of ENV_KEYS) delete process.env[key];
  requests = [];
  openRouterCatalog = [
    catalogModel('upstage/solar-decide', '0.00000005'),
    catalogModel('typesafe/jev-1.13'),
  ];
  ollamaTags = [];
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

test('auto sends decisions to the calibrated model through the System One endpoint', async () => {
  const { userId, agentId, systemOne } = await setup();

  const answers = await systemOne.decide({ userId, agentId, phase: 'test', state: { text: 'hi' }, questions: QUESTIONS });

  assert.deepEqual(answers, ANSWERS);
  const [request] = decisionRequests();
  assert.equal(request.url, 'https://openrouter.ai/api/v1/systemone');
  assert.equal(request.options.method, 'POST');
  assert.equal(request.options.headers.Authorization, 'Bearer sk-or-test');
  assert.deepEqual(request.body, { model: 'typesafe/jev-1.13', state: { text: 'hi' }, questions: QUESTIONS });
});

test('a chosen SystemOne model answers while it is available, and auto stands in when it is not', async () => {
  const { userId, agentId, systemOne } = await setup({ selection: 'openrouter::upstage/solar-decide' });
  const request = { userId, agentId, phase: 'test', state: {}, questions: QUESTIONS };

  await systemOne.decide(request);
  assert.equal(decisionRequests().at(-1).body.model, 'upstage/solar-decide');

  ctx.db.prepare("UPDATE agent_settings SET value = ? WHERE key = 'system_one_model'")
    .run(JSON.stringify('openrouter::typesafe/jev-0.9'));
  await systemOne.decide(request);
  assert.equal(decisionRequests().at(-1).body.model, 'typesafe/jev-1.13');
});

test('auto moves on when the calibrated model is gone, and a rate limit benches nothing', async () => {
  const { userId, agentId, systemOne } = await setup();
  const request = { userId, agentId, phase: 'test', state: {}, questions: QUESTIONS };
  const { isModelCoolingDown } = require('../../../server/services/ai/model_failure_cache');

  nextResponse = () => ({ response: { ok: false, status: 429 }, text: '{"error":{"message":"Rate limit exceeded"}}' });
  assert.equal(await systemOne.decide(request), null);
  assert.equal(isModelCoolingDown(userId, agentId, 'openrouter::typesafe/jev-1.13'), false);
  // The chat models behind the same key stay usable.
  assert.equal(isModelCoolingDown(userId, agentId, 'openrouter::openai/gpt-5'), false);

  nextResponse = () => ({ response: { ok: false, status: 404 }, text: '{"error":{"message":"No such model"}}' });
  assert.equal(await systemOne.decide(request), null);
  assert.equal(isModelCoolingDown(userId, agentId, 'openrouter::typesafe/jev-1.13'), true);

  nextResponse = ok({ answers: ANSWERS });
  assert.deepEqual(await systemOne.decide(request), ANSWERS);
  assert.equal(decisionRequests().at(-1).body.model, 'upstage/solar-decide');
});

test('models the admin switches off are skipped, and with all of them off SystemOne is not ready', async () => {
  const { userId, agentId, systemOne } = await setup({ selection: 'openrouter::typesafe/jev-1.13' });
  const { setDisabledModelIds } = require('../../../server/services/ai/model_visibility');
  const request = { userId, agentId, phase: 'test', state: {}, questions: QUESTIONS };

  setDisabledModelIds(['openrouter::typesafe/jev-1.13']);
  const models = await systemOne.getSystemOneModels(userId, agentId);
  assert.equal(models.find((model) => model.modelId === 'typesafe/jev-1.13').available, false);
  await systemOne.decide(request);
  assert.equal(decisionRequests().at(-1).body.model, 'upstage/solar-decide');

  setDisabledModelIds(['openrouter::typesafe/jev-1.13', 'openrouter::upstage/solar-decide']);
  const before = decisionRequests().length;
  assert.equal(systemOne.isSystemOneEnabled(userId, agentId), true);
  assert.equal(await systemOne.isSystemOneReady(userId, agentId), false);
  assert.equal(await systemOne.decide(request), null);
  assert.equal(decisionRequests().length, before);
});

test('SystemOne stays silent when the agent has it off or no provider serves a model', async () => {
  let setupResult = await setup({ selection: 'off' });
  assert.equal(setupResult.systemOne.isSystemOneEnabled(setupResult.userId, setupResult.agentId), false);
  assert.equal(await setupResult.systemOne.isSystemOneReady(setupResult.userId, setupResult.agentId), false);
  assert.equal(await setupResult.systemOne.decide({ ...setupResult, phase: 'test', state: {}, questions: QUESTIONS }), null);
  teardownTestRuntime(ctx);

  setupResult = await setup({ key: '' });
  assert.equal(await setupResult.systemOne.isSystemOneReady(setupResult.userId, setupResult.agentId), false);
  assert.equal(decisionRequests().length, 0);
});

test('TypeSafe serves its SystemOne models directly with its own key', async () => {
  const { userId, agentId, systemOne } = await setup({ key: '' });
  process.env.TYPESAFE_API_KEY = 'ts-test';

  const models = await systemOne.getSystemOneModels(userId, agentId);
  assert.deepEqual(models.map((model) => model.id), ['typesafe::jev-latest']);

  nextResponse = ok({ model: 'jev-1.13.0', answers: ANSWERS, usage: { input_tokens: 10, output_tokens: 1 } });
  assert.deepEqual(await systemOne.decide({ userId, agentId, phase: 'test', state: 'hi', questions: QUESTIONS }), ANSWERS);
  const [request] = decisionRequests();
  assert.equal(request.url, 'https://api.typesafe.ai/v1/systemone');
  assert.equal(request.options.headers.Authorization, 'Bearer ts-test');
  assert.equal(request.body.model, 'jev-latest');

  // TypeSafe has no chat models.
  const { TypeSafeProvider } = require('../../../server/services/ai/providers/typesafe');
  assert.deepEqual(await new TypeSafeProvider({ apiKey: 'ts-test' }).listModels(), []);
});

test('Ollama decision models answer through /v1/systemone and stay out of the chat list', async () => {
  const { userId, agentId, systemOne } = await setup({ key: '' });
  ollamaTags = [
    { name: 'llama3.2:latest', capabilities: ['completion', 'tools'] },
    { name: 'nimble:latest', capabilities: ['decision'] },
  ];
  const { OllamaProvider } = require('../../../server/services/ai/providers/ollama');
  const provider = new OllamaProvider({});
  assert.deepEqual(await provider.listModels(), ['llama3.2:latest']);
  assert.deepEqual(await provider.listDecisionModels(), ['nimble:latest']);

  nextResponse = ok({ model: 'nimble', answers: ANSWERS, usage: { input_tokens: 174, output_tokens: 1 } });
  assert.deepEqual(await systemOne.decide({ userId, agentId, phase: 'test', state: {}, questions: QUESTIONS }), ANSWERS);
  const [request] = decisionRequests();
  assert.equal(request.url, 'http://localhost:11434/v1/systemone');
  assert.equal(request.body.model, 'nimble:latest');
});

test('malformed answers and provider failures fall back to the model path', async () => {
  const { userId, agentId, systemOne } = await setup();
  const request = { userId, agentId, phase: 'test', state: {}, questions: QUESTIONS };

  nextResponse = ok({ answers: { ...ANSWERS, should_act: { type: 'noul', noul: 1.4 } } });
  assert.equal(await systemOne.decide(request), null);

  nextResponse = ok({ answers: { should_act: ANSWERS.should_act } });
  assert.equal(await systemOne.decide(request), null);

  nextResponse = ok({ answers: { ...ANSWERS, team: { ...ANSWERS.team, choice: 'sales' } } });
  assert.equal(await systemOne.decide(request), null);

  nextResponse = () => { throw new Error('socket hang up'); };
  assert.equal(await systemOne.decide(request), null);
});

test('a cancelled run still stops a pending decision', async () => {
  const { userId, agentId, systemOne } = await setup();
  const controller = new AbortController();
  nextResponse = () => {
    controller.abort();
    const error = new Error('aborted');
    error.name = 'AbortError';
    throw error;
  };
  await assert.rejects(
    systemOne.decide({ userId, agentId, phase: 'test', state: {}, questions: QUESTIONS, signal: controller.signal }),
    /aborted/,
  );
});

test('decisions made inside a run are ledgered with their cost and answers', async () => {
  const { userId, agentId, systemOne } = await setup();
  ctx.db.prepare(
    `INSERT INTO agent_runs (id, user_id, agent_id, title, status, trigger_type, trigger_source)
     VALUES ('run-system-one', ?, ?, 'test', 'running', 'user', 'web')`,
  ).run(userId, agentId);

  await systemOne.decide({ userId, agentId, runId: 'run-system-one', phase: 'system_one_triage', state: {}, questions: QUESTIONS });

  const row = ctx.db.prepare('SELECT * FROM agent_model_usage WHERE run_id = ?').get('run-system-one');
  assert.equal(row.phase, 'system_one_triage');
  assert.equal(row.provider, 'openrouter');
  assert.equal(row.model, 'typesafe/jev-1.13-20260917');
  assert.equal(row.input_tokens, 400);
  assert.equal(row.estimated_cost_usd, 0.0000168);
  assert.deepEqual(JSON.parse(row.metadata_json).answers, {
    should_act: 0.91,
    team: { choice: 'tech', confidence: 0.8 },
  });
});

test('the SystemOne catalog lists decision models in the chat model shape', async () => {
  const { userId, agentId, systemOne } = await setup();

  const models = await systemOne.getSystemOneModels(userId, agentId);

  assert.deepEqual(models.map((model) => model.id), [
    'openrouter::upstage/solar-decide',
    'openrouter::typesafe/jev-1.13',
  ]);
  assert.equal(models[1].modelId, 'typesafe/jev-1.13');
  assert.equal(models[1].provider, 'openrouter');
  assert.equal(models[1].purpose, '');
  assert.equal(models[1].priceTier, 'cheap');
  assert.equal(models[1].available, true);
  assert.equal(models[1].isByok, false);
});

test('the OpenRouter chat catalog leaves SystemOne models out', async () => {
  ctx = createTestRuntime();
  const httpPath = require.resolve('../../../server/services/network/http');
  require(httpPath);
  const seen = [];
  require.cache[httpPath].exports.fetchResponseText = async (url) => {
    seen.push(url);
    const data = url.includes('output_modalities=decisions')
      ? [catalogModel('typesafe/jev-1.13')]
      : [
        { id: 'typesafe/jev-router', architecture: { output_modalities: ['text'] } },
        catalogModel('typesafe/jev-1.13'),
      ];
    return json({ data });
  };
  const { OpenRouterProvider } = require('../../../server/services/ai/providers/openrouter');
  const provider = new OpenRouterProvider({ apiKey: 'test-key' });

  assert.deepEqual((await provider.listModels()).map((model) => model.id), ['typesafe/jev-router']);
  assert.deepEqual((await provider.listDecisionModels()).map((model) => model.id), ['typesafe/jev-1.13']);
  assert.deepEqual(seen, [
    'https://openrouter.ai/api/v1/models',
    OPENROUTER_DECISIONS_URL,
  ]);
});

test('system_one_model defaults off and keeps only auto or a provider-scoped model', async () => {
  const { userId, agentId } = await setup({ selection: 'yes' });
  const {
    createDefaultAiSettings,
    getAiSettings,
    normalizeSystemOneModel,
  } = require('../../../server/services/ai/settings');
  assert.equal(createDefaultAiSettings().system_one_model, 'off');
  assert.equal(getAiSettings(userId, agentId).system_one_model, 'off');
  assert.equal(normalizeSystemOneModel('auto'), 'auto');
  assert.equal(normalizeSystemOneModel('openrouter::typesafe/jev-1.13'), 'openrouter::typesafe/jev-1.13');
  assert.equal(normalizeSystemOneModel('typesafe/jev-1.13'), 'off');
});

test('SystemOne models keep their own known list in the admin availability catalog', async () => {
  await setup();
  const { getDisabledModelIds, reconcileModelVisibility, setDisabledModelIds } = require('../../../server/services/ai/model_visibility');

  setDisabledModelIds(['openrouter::some/chat-model']);
  reconcileModelVisibility(['openrouter::some/chat-model', 'openrouter::other/chat-model'], 'llm');
  // The first SystemOne listing is the baseline: nothing is switched off.
  reconcileModelVisibility(['openrouter::typesafe/jev-1.13'], 'decisions');
  assert.deepEqual(getDisabledModelIds(), ['openrouter::some/chat-model']);

  // Later arrivals follow the curated list, as chat models do, and neither
  // catalog retires the other's models.
  reconcileModelVisibility(['openrouter::typesafe/jev-1.13', 'ollama::nimble:latest'], 'decisions');
  reconcileModelVisibility(['openrouter::some/chat-model', 'openrouter::other/chat-model'], 'llm');
  assert.deepEqual(getDisabledModelIds(), ['openrouter::some/chat-model', 'ollama::nimble:latest']);
});

test('Jev settings carry over: an agent switch or the server policy "on" becomes auto, "off" keeps everyone off', async () => {
  const { userId, agentId } = await setup({ selection: 'off' });
  const other = await createTestUser(ctx.db);
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const otherAgentId = resolveAgentId(other.userId, null);
  const { migrateJevSettingToSystemOne } = require('../../../lib/schema_migrations');
  const { getAiSettings } = require('../../../server/services/ai/settings');
  const envFile = path.join(ctx.dir, 'migrated.env');
  const reset = (policy) => {
    ctx.db.prepare("DELETE FROM agent_settings WHERE key IN ('system_one_model', 'jev_enabled')").run();
    const insert = ctx.db.prepare("INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, 'jev_enabled', ?)");
    insert.run(userId, agentId, 'true');
    insert.run(other.userId, otherAgentId, 'false');
    fs.writeFileSync(envFile, policy ? `NEOAGENT_JEV=${policy}\n` : '');
  };
  const selections = () => [userId, other.userId].map((id, index) => (
    getAiSettings(id, index === 0 ? agentId : otherAgentId).system_one_model
  ));

  reset(null);
  migrateJevSettingToSystemOne(ctx.db, envFile);
  assert.deepEqual(selections(), ['auto', 'off']);
  assert.equal(ctx.db.prepare("SELECT COUNT(*) AS n FROM agent_settings WHERE key = 'jev_enabled'").get().n, 0);

  reset('on');
  migrateJevSettingToSystemOne(ctx.db, envFile);
  assert.deepEqual(selections(), ['auto', 'auto']);
  assert.doesNotMatch(fs.readFileSync(envFile, 'utf8'), /NEOAGENT_JEV/);

  reset('off');
  migrateJevSettingToSystemOne(ctx.db, envFile);
  assert.deepEqual(selections(), ['off', 'off']);
  assert.doesNotMatch(fs.readFileSync(envFile, 'utf8'), /NEOAGENT_JEV/);
});

test('OpenRouter chat requests carry the session id routing models need', () => {
  const { OpenRouterProvider } = require('../../../server/services/ai/providers/openrouter');
  const provider = new OpenRouterProvider({ apiKey: 'test-key' });
  const messages = [{ role: 'user', content: 'hi' }];
  assert.equal(provider._buildParams('typesafe/jev-router', messages, [], { sessionId: 'conv-1' }).session_id, 'conv-1');
  assert.equal(provider._buildParams('typesafe/jev-router', messages, [], {}).session_id, undefined);
});

test('browser_act is offered only while SystemOne is on, and only on the cloud computer browser', async () => {
  const { userId, agentId } = await setup({ selection: 'off' });
  const { executeTool, getAvailableTools } = require('../../../server/services/ai/tools');
  const names = () => getAvailableTools(null, { userId, agentId }).map((tool) => tool.name);

  assert.equal(names().includes('browser_act'), false);
  const off = await executeTool('browser_act', { goal: 'Search the weather' }, { userId, agentId }, {});
  assert.match(off.error, /needs a SystemOne model/);

  ctx.db.prepare("UPDATE agent_settings SET value = '\"auto\"' WHERE key = 'system_one_model'").run();
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
